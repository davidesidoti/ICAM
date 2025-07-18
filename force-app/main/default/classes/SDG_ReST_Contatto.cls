public without sharing class SDG_ReST_Contatto implements Queueable, Database.AllowsCallouts {

    private List<Contact> contacts;
    Opportunity opp;
    Boolean isChainable;

    //costruttore per chained queueable
    public SDG_ReST_Contatto(List<Contact> records, Opportunity opp, Boolean isChainable){
        this.contacts = records;
        this.opp = opp;
        this.isChainable = isChainable;
    }

    //execute Queueable
    public void execute(QueueableContext context) {

        Map<Id, Contact> contactToUpdate = new Map<Id, Contact>();
        Id recTypeService = SDG_ReST_Utils.getRecordType('Service', 'Opportunity');
        List<SDG_ReST_CustomEmail> customEmailList = new List<SDG_ReST_CustomEmail>();
        List<SDG_ReST_CustomNotification> customNotificationList = new List<SDG_ReST_CustomNotification>();
        Set<String> recipientIds = new Set<String>{UserInfo.getUserId()};

        //carica la lista delle email attive per le notifiche email in to, cc e bcc
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();

        //se sono stati inviati dei Contact
        if(contacts != null){

            //recupera tutti i CustomNotificationType e inseriscili in una mappa
            Map<String, CustomNotificationType> customNotificationMap = new Map<String, CustomNotificationType>();
            for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]){
                customNotificationMap.put(cntype.DeveloperName, cntype);
            }
            
            // per ogni Contatto esegui la chiamata a SageX3 e se la risposta ritornata è 200, associa l'externalId__c al Contact
            for(Contact cnt : contacts){

                String req = SDG_ReST_Contatto_Request.serializeRequest(cnt, true);

                System.debug('JSON = ' + SDG_ReST_Contatto_Request.serializeRequest(cnt, false));
                System.debug('JSON PRETTY = ' + req);

                try {
                    //invia a SageX3 il JSON serializzato a partire dal Contact
                    HttpResponse res = makeICAMRequest('contatti', req, SDG_ReST_Utils.IsSandbox());

                    System.debug('Response body = ' + res.getBody());
                    System.debug('STATUSCODE = ' + res.getStatusCode());

                    if(String.isNotBlank(res.getBody()) && res.getStatusCode() == 200){
                        //risposta di SageX3 parsata in un SDG_ReST_SageResponse
                        SDG_ReST_SageResponse sageResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(res.getBody()));
                        
                        String sageRespPretty = System.JSON.serializePretty(sageResp, false);
                        System.debug('sageResp = ' + System.JSON.serialize(sageResp, false));
                        System.debug('sageRespPretty = ' + sageRespPretty);

                        //ramo creazione
                        if(cnt.ExternalId__c == null) {
                            String extId = '';
                            Boolean isLocked = false;
                            //se la chiamata è andata in errore
                            if(sageResp.created == false && (sageResp.errors != null || (sageResp.errors == null && sageResp.messages == null))){
                                if(sageResp.errors != null){
                                    for(String err : sageResp.errors){
                                        //se tra gli errori compare Scheda in corso di modifica
                                        if('Scheda in corso di modifica'.containsIgnoreCase(err)){
                                            //notifica l'errore all'utente
                                            customEmailList.add(new SDG_ReST_CustomEmail(
                                                cnt.Id, '/contatti', cnt.Name, req, sageRespPretty
                                            ));
                                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                                cnt.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile creare il Referente "' + cnt.Name + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                            ));
                                            System.debug('Impossibile creare il Referente su SageX3. ERRORS: ' + sageResp.errors);
                                            isLocked = true;  
                                            break;
                                        }            
                                    }
                                }

                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore generico all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        cnt.Id, '/contatti', cnt.Name, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        cnt.Id, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare il Referente "' + cnt.Name + '" su Sage X3, di seguito gli errori: ' + (sageResp.errors != null ? sageResp.errors.toString() : ('risposta vuota (' + res.getBody() +')'))
                                    ));   
                                    System.debug('Impossibile creare il Referente su SageX3. ERRORS: ' + sageResp.errors);
                                }
                            }
                            
                            //se la chiamata è andata a buon fine, estrapola l'external id
                            else if(sageResp.messages != null){
                                for(String mex : sageResp.messages){
                                    if( !('error'.equals(SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(mex, 15))) && cnt.ExternalId__c == null){
                                        extId = SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(mex, 15);
                                        System.debug('EXTERNAL ID = ' + extId);
                                        contactToUpdate.put(cnt.Id, new Contact(Id = cnt.Id, ExternalId__c = cnt.Account_ExternalId__c + '_' + extId));   
                                        System.debug('Referente creato su SageX3.');

                                        break;
                                    }
                                }
                            }
                            //[{"error":false,"created":true,"errors":null,"messages":["|Aggiornamento di 000819"]}]
                        }                
                        
                        //ramo aggiornamento
                        else {
                            //se la chiamata è andata in errore
                            if(sageResp.error && sageResp.errors != null){
                                Boolean isLocked = false;
                                for(String err : sageResp.errors){
                                    //se tra gli errori compare Scheda in corso di modifica
                                    if('Scheda in corso di modifica'.containsIgnoreCase(err)){
                                        //notifica l'errore all'utente
                                        customEmailList.add(new SDG_ReST_CustomEmail(
                                            cnt.Id, '/contatti', cnt.Name, req, sageRespPretty
                                        ));
                                        customNotificationList.add(new SDG_ReST_CustomNotification(
                                            cnt.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare il Referente "' + cnt.Name + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                        ));
                                        System.debug('Impossibile aggiornare il Referente su SageX3. ERRORS: ' + sageResp.errors);
                                        isLocked = true;  
                                        break;
                                    }            
                                }

                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        cnt.Id, '/contatti', cnt.Name, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        cnt.Id, 'Record_non_aggiornato_su_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare il Referente "' + cnt.Name + '" su Sage X3, di seguito gli errori: ' + sageResp.errors
                                    ));
                                    System.debug('Impossibile aggiornare il Referente su SageX3. ERRORS: ' + sageResp.errors);
                                }
                            }
                            //se la chiamata è andata a buon fine
                            else{
                                System.debug('Referente aggiornato su SageX3.');
                            }
                        
                        }
                    }
                    else{
                        customEmailList.add(new SDG_ReST_CustomEmail(
                            cnt.Id, '/contatti', cnt.Name, req, 'Sage X3 non raggiungibile'
                        ));
                        customNotificationList.add(new SDG_ReST_CustomNotification(
                            cnt.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare il Referente "' + cnt.Name + '" su Sage X3 poiché non risulta raggiungibile, riprovare in un secondo momento. Se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                        ));
                    }
                } catch (System.CalloutException ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        cnt.Id, '/contatti', cnt.Name, req, 'Macchina Down'
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        cnt.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare il Referente "' + cnt.Name + '" su Sage X3 poiché la macchina che si occupa di inviare il dato non è al momento attiva. Riprovare in un secondo momento e, se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                    ));
                } catch (Exception ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        cnt.Id, '/contatti', cnt.Name, req, ex.getStackTraceString()
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        opp.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare il Referente "' + cnt.Name + '" su Sage X3 per un errore non gestito.'
                    ));
                }      
         
            }
           
            //invia eventuale email all'utente
            if(customEmailList.size() > 0){
                String bodyEmail = '';
                for(SDG_ReST_CustomEmail ce : customEmailList){
                    bodyEmail += (
                        (String.isNotBlank(bodyEmail) ? '<hr>' : '') +
                        '<ul>' + 
                            '<li><b style="color:#e5142c;">Link a Salesforce:</b> <a href="' + ce.urlSalesforce + '">Link</a></li>' +
                            '<li><b style="color:#e5142c;">Relative Path:</b> ' + ce.urlPath + '</li>' +
                            '<li><b style="color:#e5142c;">Nome Record:</b> ' + ce.objectName + '</li>' +
                            '<li><b style="color:#e5142c;">Body Chiamata:</b><br><pre>' + ce.request + '</pre></li>' +
                            '<li><b style="color:#e5142c;">Body Risposta:</b><br><pre>' + ce.response + '</pre></li>' +
                        '</ul>'
                    );
                } 
                System.debug('bodyEmail' + bodyEmail); 
                SDG_ReST_Utils.sendNotificationEmail(
                    '[ICAM] Errore sync Salesforce -> Sage X3', bodyEmail, addressList.get('toaddress'), 
                    addressList.get('ccaddress'), addressList.get('bccaddress')
                );
            }

            //update dei Contact con gli ExternalId di SageX3
            if(contactToUpdate.size() > 0){
                SDG_ReST_Utils.updateNoTrigger(contactToUpdate.values(), 'SDG_ReST_Contatto_Handler');
            }

            //ramo chained queueable
            if(isChainable){
                //se esiste un account associato all'opportunity, recuperane i dati e se non ha un external id o appartiene a una Trattativa Service, invialo a Sage
                if(String.isNotBlank(opp?.AccountId) && (opp.Account_ExternalId__c == null || opp.RecordTypeId == recTypeService)){
                    Account acc = [
                        SELECT Id, Category__c, Name, Description, Abbreviation__c, PayTerm__c, Currency__c, FiscalCode__c, IntraCommunityVAT__c, AccountCode__c,
                        StatisticFamily1__c, StatisticFamily2__c, StatisticFamily3__c, StatisticFamily4__c, StatisticFamily5__c, AutorizationPending__c, CommissionCategory__c, RecordTypeDeveloperName__c,
                        RecordTypeId, ExternalId__c, Language__c, Country__c, Activity__c, Origin__c, ParentId, Rep1_ExternalId__c, VACBPartner__c, BusinessName2__c,
                        BilledAddress_ExternalId__c, PayerAddress_ExternalId__c, BilledCustomer_ExternalId__c, PayerCustomer_ExternalId__c FROM Account WHERE Id =: opp.AccountId
                    ];
                    system.debug('ACCOUNT = ' + acc);

                    //se l'account non ha terzo e ha la partita IVA popolata
                    if(acc.ParentId == null && String.isNotBlank(acc.IntraCommunityVAT__c)){
                        try {
                            //controllo che esista un terzo attivo con la stessa partita IVA
                            Account accSamePIVA = [
                                SELECT Id, Category__c, Name, Description, Abbreviation__c, PayTerm__c, Currency__c, FiscalCode__c, IntraCommunityVAT__c, RecordTypeId, RecordType.DeveloperName, Customer__c, BusinessName2__c,
                                StatisticFamily1__c, StatisticFamily2__c, StatisticFamily3__c, StatisticFamily4__c, StatisticFamily5__c, AutorizationPending__c, CommissionCategory__c, ExternalId__c, Language__c, Country__c, 
                                Activity__c, Origin__c, ParentId, Prospect__c, (SELECT Id, ExternalId__c, IntraCommunityVAT__c, Name FROM ChildAccounts WHERE RecordType.DeveloperName = 'Prospect' OR RecordType.DeveloperName = 'Customer') 
                                FROM Account WHERE RecordType.DeveloperName = 'BPartner' AND isActive__c = true AND IntraCommunityVAT__c =: acc.IntraCommunityVAT__c LIMIT 1            
                            ];        
                            
                            //se esiste un terzo attivo con la stessa partita iva senza prospect ne clienti
                            if(accSamePIVA != null && accSamePIVA?.ChildAccounts?.size() == 0 && accSamePIVA?.Prospect__c == false && accSamePIVA?.Prospect__c == false){
                                System.debug('ChildAccounts: ' + accSamePIVA.ChildAccounts.size());
                                //associo il terzo all'account dell'opportunity e mi creo l'external id, sarà poi inserito manualmente su Sage X3 per un limite dell'API
                                acc.ParentId = accSamePIVA?.Id;
                                acc.ExternalId__c = accSamePIVA?.ExternalId__c?.replaceFirst('BPR', 'PPT');
                                List<Account> accs = new List<Account>{acc};
                                SDG_ReST_Utils.updateNoTrigger(accs, 'SDG_ReST_Prospect_Handler');
                                SDG_ReST_Utils.sendNotificationEmail(
                                    '[ICAM] Necessaria operazione manuale sync Salesforce -> Sage X3', 
                                    '<ul>' + 
                                        '<li><b style="color:#e5142c;">Nome Record:</b> ' + acc.Name + '</li>' +
                                        '<li><b style="color:#e5142c;">Link a Salesforce:</b> <a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + acc.Id + '">Link</a></li>' +                                        
                                        '<li><b style="color:#e5142c;">Problematica:</b> ' + 'Il Prospect è stato associato all\'interno di Salesforce al Terzo <a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + accSamePIVA.Id + '">' + accSamePIVA.Name + '</a> esistente. A causa di un limite tecnico, non è possibile inviarlo tramite integrazione a SageX3, perciò è necessario crearlo manualmente in SageX3, associato al Terzo identificato.' + '</li>' +
                                    '</ul>'
                                    , addressList.get('toaddress'), 
                                    addressList.get('ccaddress'), addressList.get('bccaddress')
                                );
                                customNotificationList.add(new SDG_ReST_CustomNotification(
                                    acc.Id, 'Errore_Sage_X3', 'Necessaria operazione manuale', 'Il Prospect è stato associato all\'interno di Salesforce al Terzo ' + accSamePIVA.Name + ' esistente. A causa di un limite tecnico, non è possibile inviarlo tramite integrazione a SageX3, perciò è necessario crearlo manualmente in SageX3, associato al Terzo identificato.'
                                ));
                            }
                        }
                        //se non esiste un terzo attivo con la stessa partita IVA, invio l'account a SageX3 
                        catch (System.QueryException e) {
                            System.debug('ERRORE: ' + e);
                            List<Account> accs = new List<Account>{acc};
                            if(!Test.isRunningTest()) System.enqueueJob(new SDG_ReST_Prospect(accs, opp, true));
                        }
                    }
                    //se non esiste un terzo attivo con la stessa partita IVA, invio l'account a SageX3 
                    else{
                        List<Account> accs = new List<Account>{acc};
                        if(!Test.isRunningTest()) System.enqueueJob(new SDG_ReST_Prospect(accs, opp, true));
                    }
                } 
            }

            //invia eventuali notifiche all'utente
            if(customNotificationList.size() > 0){
                for(SDG_ReST_CustomNotification cn : customNotificationList){
                    SDG_ReST_Utils.notifyUsers(
                        customNotificationMap, recipientIds, cn.targetId, cn.devName, cn.title, cn.body
                    );
                }
            } 
        }
    }
    
    public static HttpResponse makeICAMRequest(String path, String body, Boolean env) {
        return SDG_ReST_Utils.makeRequest('POST', path, body, env);
    }
    
}