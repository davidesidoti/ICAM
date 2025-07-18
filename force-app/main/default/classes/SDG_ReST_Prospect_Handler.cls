public without sharing class SDG_ReST_Prospect_Handler extends TR_BaseTriggerHandler {

    private List<Account> newTagList;
    private List<Account> oldTagList;
    private Map<ID, Account> newTagMap;
    private Map<ID, Account> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
    private Id recTypeProspect = SDG_ReST_Utils.getRecordType('Prospect', 'Account');
    private Id recTypeCustomer = SDG_ReST_Utils.getRecordType('Customer', 'Account');
    
    public SDG_ReST_Prospect_Handler() {
        oldTagList = (List<Account>)Trigger.old;
        newTagList = (List<Account>)Trigger.new;
        newTagMap = (Map<ID, Account>)Trigger.newMap;
        oldTagMap = (Map<ID, Account>)Trigger.oldMap;
    } 

    public override void beforeInsert(){
        checkPartitaIva();
    }

    public override void beforeUpdate(){
        checkPartitaIva();
    }

    private void checkPartitaIva(){
        //se l'utenza può effettuare modifiche a Sage X3 tramite API  
        if(((!avoidUserName) || SDG_ReST_Utils.IsSandbox()) && UserInfo.getName() != 'B2BMA Integration'){

            Set<String> accIvaToCheck = new Set<String>();

            //per ogni account nel Trigger
            for(Account acc : newTagList){
                //se ha la partita IVA popolata ed è un Prospect o un Customer, aggiungilo al check
                if( acc.IntraCommunityVAT__c != null && (recTypeProspect == acc.RecordTypeId || recTypeCustomer == acc.RecordTypeId)){    
                    accIvaToCheck.add(acc.IntraCommunityVAT__c);                   
                }
            } 

            //se esiste almeno un account da controllare
            if(!accIvaToCheck.isEmpty()){

                Set<Id> accIds = newTagMap?.keySet();
                //controllo che esistano prospect o clienti con la stessa partita IVA degli account da controllare
                List<Account> accSamePIVA = [
                    SELECT Id, Name, IntraCommunityVAT__c, RecordTypeId, RecordType.DeveloperName, Customer__c, ParentId, Prospect__c, RecordTypeDeveloperName__c FROM Account 
                    WHERE (RecordType.DeveloperName = 'Customer' OR RecordType.DeveloperName = 'Prospect')  
                    AND IntraCommunityVAT__c IN :accIvaToCheck AND IsActive__c = true AND Id NOT IN :accIds
                ];  
                //se esiste almeno un prospect o un cliente con la stessa partita IVA degli account da controllare
                if(!accSamePIVA.isEmpty()){
                    //Mappa Partita Iva, Terzo
                    Map<String, Account> accMapToCheck = new Map<String, Account>();
                    //popola la mappa
                    for(Account acc : accSamePIVA){
                        accMapToCheck.put(acc.IntraCommunityVAT__c, acc);
                    }
                    //cicla sugli account da controllare per il check finale
                    for(Account acc : newTagList){
                        //se esiste un terzo attivo con la stessa partita iva senza prospect ne clienti
                        if(accMapToCheck.get(acc.IntraCommunityVAT__c) != null){
                            if(Trigger.isInsert){
                                acc.addError(
                                    'Impossibile creare il ' + acc.RecordTypeDeveloperName__c + ' "' + acc.Name + '", esiste già il ' + accMapToCheck.get(acc.IntraCommunityVAT__c).RecordTypeDeveloperName__c + ' "' + 
                                    accMapToCheck.get(acc.IntraCommunityVAT__c).Name + '" con la Partita IVA "' + acc.IntraCommunityVAT__c + '". ' + 
                                    'Invece di creare un nuovo ' + acc.RecordTypeDeveloperName__c + ', scegliere il ' + accMapToCheck.get(acc.IntraCommunityVAT__c).RecordTypeDeveloperName__c + ' esistente durante la conversione del Lead.'
                                );
                            }
                            else{
                                acc.addError(
                                    'Impossibile aggiornare il ' + acc.RecordTypeDeveloperName__c + ' "' + acc.Name + '", esiste già il ' + accMapToCheck.get(acc.IntraCommunityVAT__c).RecordTypeDeveloperName__c + ' "' + 
                                    accMapToCheck.get(acc.IntraCommunityVAT__c).Name + '" con la Partita IVA "' + acc.IntraCommunityVAT__c + '".'
                                );
                            }  
                        }
                    }
                }             
            }
        }
    }
    
    public override void afterUpdate(){
        List<Account> accToRequest = new List<Account>();
        for(Account acc : newTagMap.values()){
            if( !avoidUserName && UserInfo.getName() != 'B2BMA Integration' && acc.ExternalId__c != null && 
            (recTypeProspect == acc.RecordTypeId || recTypeCustomer == acc.RecordTypeId)){
                accToRequest.add(acc);
            }
        }
            
        if(accToRequest.size() > 0){
            ID jobID = System.enqueueJob(new SDG_ReST_Prospect(accToRequest));
        }
    } 
}