public without sharing class SDG_ReST_Location_Handler extends TR_BaseTriggerHandler {
    
    private List<Schema.Location> newTagList;
    private List<Schema.Location> oldTagList;
    private Map<ID, Schema.Location> newTagMap;
    private Map<ID, Schema.Location> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
    
    public SDG_ReST_Location_Handler() {
        oldTagList = (List<Schema.Location>)Trigger.old;
        newTagList = (List<Schema.Location>)Trigger.new;
        newTagMap = (Map<ID, Schema.Location>)Trigger.newMap;
        oldTagMap = (Map<ID, Schema.Location>)Trigger.oldMap;
    }

    public override void beforeInsert(){
        checkAddressCodeAndDefaultAddressUnique();
    }
    
    public override void afterInsert(){
        sendToAccountHandler();
    }

    public override void beforeUpdate(){
        checkAddressCodeAndDefaultAddressUnique();
    }
    
    public override void afterUpdate(){
        sendToAccountHandler();
    }

    public void checkAddressCodeAndDefaultAddressUnique(){

        //se l'utenza può effettuare modifiche a Sage X3 tramite API  
        if(!avoidUserName){

            System.debug('newTagList: ' + newTagList);

            //Mappa <AccountId, Set<Progressive Sage>
            Map<Id, Set<String>> accIds = new Map<Id, Set<String>>();
            Set<Id> accDefAddrIds = new Set<Id>();

            //recupero tutti gli Account collegati alle nuove Location e mi assicuro che non ci sia più di un "Indirizzo di default" per cliente e più di una Location collegata allo stesso Account con lo stesso Codice Indirizzo
            for(Schema.Location loc : newTagList){

                //per ogni nuova Location, se nel trigger sono presenti sono due o più Location "Indirizzo di default" collegate allo stesso Account, manda un custom validation exception
                if(loc.DefaultAddress__c){
                    if(accDefAddrIds.contains(loc.Account__c)){
                        loc.addError('Errore, non è possibile ' + (Trigger.isUpdate ? 'aggiornare' : 'creare') +  ' contemporaneamente più di un indirizzo come "Indirizzo di default" per lo stesso ' + loc.Account_RecordType__c + ' "' + loc.Account_Name__c + '".');
                    } 
                    else {
                        accDefAddrIds.add(loc.Account__c);
                    } 
                } 

                //per ogni nuova Location, se nel trigger sono presenti sono due o più Location collegate allo stesso Account con lo stesso Codice Indirizzo, manda un custom validation exception
                if(accIds.containsKey(loc.Account__c) && (accIds.get(loc.Account__c)).contains(loc.Progressive_Sage__c)){
                    loc.addError('Il Codice Indirizzo "' + loc.Progressive_Sage__c + '" è già presente per il ' + loc.Account_RecordType__c + ' "' + loc.Account_Name__c + '".');
                }
                else if(accIds.containsKey(loc.Account__c)){
                    (accIds.get(loc.Account__c)).add(loc.Progressive_Sage__c);
                }
                else{
                    accIds.put(loc.Account__c, new Set<String>{loc.Progressive_Sage__c});
                }        
            }

            //se c'è almeno un Account collegato alle nuove Location
            if(!accIds.isEmpty()){

                System.debug('accIds: ' + accIds);

                //recupero tutte le Location esistenti collegate agli Account, per verificare l'unicità del campo Progressive Sage
                List<Schema.Location> existingLocationList = new List<Schema.Location>();

                //se è before update, rimuovi dalla lista le Location in aggiornamento del trigger
                if(Trigger.isUpdate){
                    existingLocationList = [SELECT Id, Account__c, Progressive_Sage__c FROM Location WHERE Account__c IN :accIds.keySet() AND Id NOT IN :newTagMap.keySet()];
                }
                //se è before insert
                else{
                    existingLocationList = [SELECT Id, Account__c, Progressive_Sage__c FROM Location WHERE Account__c IN :accIds.keySet()];
                }

                //se c'è almeno una Location esistente collegata agli Account
                if(!existingLocationList.isEmpty()){

                    System.debug('existingLocationList: ' + existingLocationList);

                    //organizzo le Location esistenti in una mappa <AccountId, Set<Progressive Sage> per poter eseguire il check
                    Map<Id, Set<String>> existingLocationMap = new Map<Id, Set<String>>();
                    for(Schema.Location loc : existingLocationList){
                        if(existingLocationMap.containsKey(loc.Account__c)){
                            (existingLocationMap.get(loc.Account__c)).add(loc.Progressive_Sage__c);
                        }
                        else{
                            existingLocationMap.put(loc.Account__c, new Set<String>{loc.Progressive_Sage__c});
                        } 
                    }

                    //se la mappa non è vuota
                    if(!existingLocationMap.isEmpty()){

                        System.debug('existingLocationMap: ' + existingLocationMap);

                        //ciclo sul trigger delle Location
                        for(Schema.Location loc : newTagList){

                            System.debug('esistono altre location? -> ' + existingLocationMap.containsKey(loc.Account__c));
                            System.debug('loc.DefaultAddress__c = ' + loc.DefaultAddress__c);
                            System.debug('esiste già una Location collegata allo stesso Account con lo stesso Codice Indirizzo? -> ' + 
                            ((existingLocationMap.containsKey(loc.Account__c) && (existingLocationMap.get(loc.Account__c)).contains(loc.Progressive_Sage__c))));

                            //per ogni nuova Location, se esiste già una Location collegata allo stesso Account con lo stesso Codice Indirizzo, manda un custom validation exception
                            if(existingLocationMap.containsKey(loc.Account__c) && (existingLocationMap.get(loc.Account__c)).contains(loc.Progressive_Sage__c)){
                                loc.addError('Il Codice Indirizzo "' + loc.Progressive_Sage__c + '" è già presente per il ' + loc.Account_RecordType__c + ' "' + loc.Account_Name__c + '".');
                            }
                            //altrimenti per ogni nuova Location, se non esistono altre location collegate all'Account e ha DefaultAddress a false, passalo a true
                            else if(!existingLocationMap.containsKey(loc.Account__c) && loc.DefaultAddress__c == false && accIds.get(loc.Account__c)?.size() == 1 && Trigger.isInsert){
                                loc.DefaultAddress__c = true;
                            }
                        }
                    }       
                }
                
                else if(Trigger.isInsert){
                    //ciclo sul trigger delle Location
                    for(Schema.Location loc : newTagList){
                        if(loc.DefaultAddress__c == false && accIds.get(loc.Account__c)?.size() == 1){
                            loc.DefaultAddress__c = true;
                        }
                    }
                }
            }
        }
    }
    
    private void sendToAccountHandler(){
        //se l'utenza può effettuare modifiche a Sage X3 tramite API  
        if(!avoidUserName){

            //Set contenente gli Id degli Account associati alle location nel trigger
            Set<Id> accIdSet = new Set<Id>();
            //Set contenente gli Id degli Account associati alle location "Indirizzo di Default" nel trigger
            Set<Id> accLocDefAddrSet = new Set<Id>();
            List<Schema.Location> locExtIdChanged = new List<Schema.Location>();
            
            //per ogni location, recupera l'Id dell'Account associato, se non è presente nel Set
            for(Schema.Location loc : newTagList){
                accIdSet.add(loc.Account__c);
                if(loc.DefaultAddress__c && (Trigger.isInsert || oldTagMap.get(loc.Id).DefaultAddress__c == false)){
                    accLocDefAddrSet.add(loc.Account__c);     
                } 
                if(loc.ExternalId__c != null && loc.Progressive_Sage__c != SDG_ReST_Utils.getExtId(loc.ExternalId__c, '_')){
                    locExtIdChanged.add(new Schema.Location(Id = loc.Id, ExternalId__c = loc.ExternalId__c.replace(SDG_ReST_Utils.getExtId(loc.ExternalId__c, '_'), loc.Progressive_Sage__c)));
                }
            }
            if(!(locExtIdChanged.isEmpty())){
                SDG_ReST_Utils.updateNoTrigger(locExtIdChanged, 'SDG_ReST_Location_Handler');
            }

            //per ogni Indirizzo, se il campo "indirizzo di default" viene aggiornato da false a true o viene inserito a true
            //recupera tutti gli altri indirizzi con "indirizzo di default" a true associati agli Account presenti nlle location del trigger
            //per ogni Indirizzo aggiorna il campo "indirizzo di default" a false
            if(!(accLocDefAddrSet.isEmpty())){
                List<Schema.Location> defAddrLocActive = [SELECT Id, DefaultAddress__c FROM Location WHERE DefaultAddress__c = true AND Account__c IN: accLocDefAddrSet AND Id NOT IN :newTagMap.keySet()];
                if(!(defAddrLocActive.isEmpty())){
                    for(Schema.Location locDef : defAddrLocActive){
                        locDef.DefaultAddress__c = false;
                    }
                    SDG_ReST_Utils.updateNoTrigger(defAddrLocActive, 'SDG_ReST_Location_Handler');  
                }
            }

            //se esiste almeno un Account associato alle Location nel trigger, recupera i campi necessari e lancia un update fittizio per innescare 
            //il trigger SDG_ReST_Prospect_Trigger e la conseguente classe SDG_ReST_Prospect_Handler per l'aggiornamento a Sage X3
            if(!(accIdSet.isEmpty())){
                List<Account> accList = [
                    SELECT Id, Category__c, Name, Description, Abbreviation__c, PayTerm__c, Currency__c, FiscalCode__c, IntraCommunityVAT__c, AccountCode__c,
                    StatisticFamily1__c, StatisticFamily2__c, StatisticFamily3__c, StatisticFamily4__c, StatisticFamily5__c, AutorizationPending__c, CommissionCategory__c, 
                    RecordTypeDeveloperName__c, RecordTypeId, ExternalId__c, Language__c, Country__c, Activity__c, Origin__c, ParentId, 
                    Rep1_ExternalId__c, BilledAddress_ExternalId__c, PayerAddress_ExternalId__c, BilledCustomer_ExternalId__c, VACBPartner__c,
                    PayerCustomer_ExternalId__c FROM Account WHERE ExternalId__c != null AND Id IN :accIdSet
                ];
                if(!(accList.isEmpty())){
                    update accList;
                }
            } 
        }
    }

}