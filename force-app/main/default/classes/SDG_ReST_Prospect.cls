public without sharing class SDG_ReST_Prospect implements Queueable, Database.AllowsCallouts {

    private List<Account> accounts;
    Opportunity opp;
    Boolean isChainable;

    //costruttore per chained queueable
    public SDG_ReST_Prospect(List<Account> records, Opportunity opp, Boolean isChainable){
        this.accounts = records;
        this.opp = opp;
        this.isChainable = isChainable;
    }

    //costruttore per esecuzione solitaria
    public SDG_ReST_Prospect(List<Account> records){
        this.accounts = records;
        this.isChainable = false;
    }

    //execute Queueable
    public void execute(QueueableContext context) {

        Map<Id, Account> accountToUpdate = new Map<Id, Account>();
        List<Account> terziToCreate = new List<Account>();
        Map<Id, Schema.Location> locToUpdate = new Map<Id, Schema.Location>();
        Map<Id, Contact> contactToUpdate = new Map<Id, Contact>();
        Id recTypeProspect = SDG_ReST_Utils.getRecordType('Prospect', 'Account');
        Id recTypeCustomer = SDG_ReST_Utils.getRecordType('Customer', 'Account');
        Id recTypeTerzo = SDG_ReST_Utils.getRecordType('BPartner', 'Account');
        List<SDG_ReST_CustomEmail> customEmailList = new List<SDG_ReST_CustomEmail>();
        List<SDG_ReST_CustomNotification> customNotificationList = new List<SDG_ReST_CustomNotification>();
        Set<String> recipientIds = new Set<String>{UserInfo.getUserId()};

        //carica la lista delle email attive per le notifiche email in to, cc e bcc
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();

        //se sono stati inviati degli Account
        if(accounts != null){

            //recupera tutti i CustomNotificationType e inseriscili in una mappa
            Map<String, CustomNotificationType> customNotificationMap = new Map<String, CustomNotificationType>();
            for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]){
                customNotificationMap.put(cntype.DeveloperName, cntype);
            }
            
            //crea un set di Id degli Account coinvolti
            Set<Id> accIds = new Set<Id>();
            for(Account a : accounts){
                accIds.add(a.Id);
            }

            //recupera tutte le location collegate agli account ordinate per ExternalId__c
            List<Schema.Location> locAcc = [
                SELECT Id, Name, CreatedDate, LocationType, Description, IsMobile, IsInventoryLocation, ExternalId__c, Progressive_Sage__c,
                Account__c, OtherNum__c, Address1__c, Address2__c, Address3__c, MobilePhone__c, City__c, StreetConcatenated__c, 
                Country__c, Email__c, Email2__c, Email3__c, Email4__c, Email5__c, Fax__c, DefaultAddress__c, GreenNum__c, State__c, 
                FacilityWeb__c, Phone__c, ZipPostalCode__c, Region__c FROM Location WHERE Account__c IN :accIds ORDER BY ExternalId__c NULLS LAST
            ];

            //recupera tutti i contact collegati agli account ordinati per ExternalId__c
            List<Contact> cntAcc = [
                SELECT Id, MaritalStatus__c, LastName, FirstName, Name, MailingCountry, Phone, Fax, MobilePhone, Email, Language__c, Birthdate, 
                Category__c, MailingStreet, MailingPostalCode, MailingCity, MailingState, ExternalId__c, Account_ExternalId__c, Account.ExternalId__c,
                Title, Role__c, Mission__c, Service__c, NoMailing__c, Region__c, Country__c, Location_ExternalId__c, EmailAziendale__c 
                FROM Contact WHERE AccountId IN :accIds ORDER BY ExternalId__c NULLS LAST
            ];

            // per ogni Cliente esegui la chiamata a SageX3 e se la risposta ritornata è 200, associa l'externalId__c all'Account
            for(Account acc : accounts){

                //salva solo le location associate all'account interno al loop
                List<Schema.Location> locationsAccount = new List<Schema.Location>();
                for(Schema.Location loc : locAcc){
                    if(acc.Id == loc.Account__c){
                        locationsAccount.add(loc);
                    }
                }

                //salva solo i contact associati all'account interno al loop
                List<Contact> contactsAccount = new List<Contact>();
                for(Contact cnt : cntAcc){
                    if(acc.Id == cnt.AccountId){
                        contactsAccount.add(cnt);
                    }
                }

                String req = null;
                HttpResponse res = null;
                
                //se è un Cliente
                if(recTypeCustomer == acc.RecordTypeId){
                    req = SDG_ReST_Cliente_Request.serializeRequest(acc, locationsAccount, contactsAccount, true);
                    System.debug('JSON = ' + SDG_ReST_Cliente_Request.serializeRequest(acc, locationsAccount, contactsAccount, false));
                    System.debug('JSON PRETTY = ' + req);

                    //invia a SageX3 il JSON serializzato a partire dall'Account
                    //res = makeICAMRequest('clienti', req, SDG_ReST_Utils.IsSandbox());
                }

                //se è un Prospect
                else if(recTypeProspect == acc.RecordTypeId){
                    req = SDG_ReST_Prospect_Request.serializeRequest(acc, locationsAccount, contactsAccount, true);
                    System.debug('JSON = ' + SDG_ReST_Prospect_Request.serializeRequest(acc, locationsAccount, contactsAccount, false));
                    System.debug('JSON PRETTY = ' + req);
                    
                    //invia a SageX3 il JSON serializzato a partire dall'Account
                    //res = makeICAMRequest('prospect', req, SDG_ReST_Utils.IsSandbox());                 
                }

                try{
                    res = (recTypeCustomer == acc.RecordTypeId ? makeICAMRequest('clienti', req, SDG_ReST_Utils.IsSandbox()) : makeICAMRequest('prospect', req, SDG_ReST_Utils.IsSandbox())); 

                    System.debug('Response body = ' + res.getBody());
                    System.debug('STATUSCODE = ' + res.getStatusCode());

                    if(String.isNotBlank(res.getBody()) && res.getStatusCode() == 200){
                        //risposta di SageX3 parsata in un SDG_ReST_SageResponse
                        SDG_ReST_SageResponse sageResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(res.getBody()));
                                            
                        String sageRespPretty = System.JSON.serializePretty(sageResp, false);
                        System.debug('sageResp = ' + System.JSON.serialize(sageResp, false));
                        System.debug('sageRespPretty = ' + sageRespPretty);

                        //ramo creazione
                        if(acc.ExternalId__c == null) {
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
                                                acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, sageRespPretty
                                            ));
                                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                                acc.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile creare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                            ));
                                            System.debug('Impossibile creare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' su SageX3. ERRORS: ' + sageResp.errors);
                                            isLocked = true;  
                                            break;
                                        }            
                                    }
                                }

                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore generico all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        acc.Id, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3, di seguito gli errori: ' + (sageResp.errors != null ? sageResp.errors.toString() : ('risposta vuota (' + res.getBody() +')'))
                                    ));
                                    System.debug('Impossibile creare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' su SageX3. ERRORS: ' + sageResp.errors);
                                }
                            }
                            
                            //se la chiamata è andata a buon fine, estrapola l'external id
                            else if(sageResp.messages != null){
                                for(String mex : sageResp.messages){
                                    if(!('error'.equals(SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(mex, 6))) && acc.ExternalId__c == null){
                                        extId = SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(mex, 6);
                                        System.debug('EXTERNAL ID = ' + extId);
                                        //se è un prospect, associa l'externalId__c all'Account, crea un terzo fittizio che verrà popolato alla prossima sync e aggiorna gli external id delle Location e Contact collegati all'Account
                                        //NOTA: se è un cliente, salta questo passaggio, solo in modifica si potrà aggiornare gli external id delle Location e Contact associate al cliente
                                        if(recTypeProspect == acc.RecordTypeId){
                                            terziToCreate.add(new Account(RecordTypeId = recTypeTerzo, Name = extId + ' - ' + acc.Name, ExternalId__c = 'BPR_' + extId));
                                            Account newAcc = new Account(Id = acc.Id, ExternalId__c = 'PPT_' + extId, Parent = new Account(ExternalId__c = 'BPR_' + extId));
                                            accountToUpdate.put(acc.Id, newAcc); 
                                            System.debug((acc.RecordTypeDeveloperName__c != null ? acc.RecordTypeDeveloperName__c : 'Account ') + ' creato su SageX3.');
                                            for(Schema.Location loc : locationsAccount){
                                                if(String.isEmpty(loc.ExternalId__c)){
                                                    locToUpdate.put(loc.Id, new Schema.Location(Id = loc.Id,  ExternalId__c = accountToUpdate.get(acc.Id).ExternalId__c + '_' + loc.Progressive_Sage__c));   
                                                }
                                            }  
                                            for(Contact cnt : contactsAccount){
                                                if(cnt.ExternalId__c != null && cnt.ExternalId__c.contains('null_') && acc.Id == cnt.AccountId){
                                                    contactToUpdate.put(cnt.Id, new Contact(Id = cnt.Id, ExternalId__c = cnt.ExternalId__c.replaceFirst('null', accountToUpdate.get(acc.Id).ExternalId__c)));                    
                                                }
                                            }
                                            break;
                                        }                                                            
                                    }
                                }
                            }
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
                                            acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, sageRespPretty
                                        ));
                                        customNotificationList.add(new SDG_ReST_CustomNotification(
                                            acc.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                        ));
                                        System.debug('Impossibile aggiornare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' su SageX3. ERRORS: ' + sageResp.errors);
                                        isLocked = true;  
                                        break;
                                    }            
                                }

                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        acc.Id, 'Record_non_aggiornato_su_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3, di seguito gli errori: ' + sageResp.errors
                                    ));
                                    System.debug('Impossibile aggiornare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' su SageX3. ERRORS: ' + sageResp.errors);
                                }
                            }
                            //se la chiamata è andata a buon fine
                            else{
                                System.debug((acc.RecordTypeDeveloperName__c != null ? acc.RecordTypeDeveloperName__c : 'Account') + ' aggiornato su SageX3.');
                                //aggiorna gli external id delle Location collegate all'Account
                                for(Schema.Location loc : locationsAccount){
                                    if(String.isEmpty(loc.ExternalId__c)){
                                        Schema.Location newLoc = new Schema.Location(Id = loc.Id, ExternalId__c = acc.ExternalId__c + '_' + loc.Progressive_Sage__c);                   
                                        locToUpdate.put(loc.Id, newLoc);   
                                    }
                                }
                                //aggiorna gli external id dei Contact collegati all'Account
                                for(Contact cnt : contactsAccount){
                                    if(cnt.ExternalId__c != null && cnt.ExternalId__c.contains('null_') && acc.Id == cnt.AccountId){
                                        contactToUpdate.put(cnt.Id, new Contact(Id = cnt.Id, ExternalId__c = cnt.ExternalId__c.replaceFirst('null', acc.ExternalId__c)));                    
                                    }
                                }
                            }
                        }
                    }
                    else{
                        customEmailList.add(new SDG_ReST_CustomEmail(
                            acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, 'Sage X3 non raggiungibile'
                        ));
                        customNotificationList.add(new SDG_ReST_CustomNotification(
                            acc.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3 poiché non risulta raggiungibile, riprovare in un secondo momento. Se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                        ));
                    }

                } catch (System.CalloutException ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, 'Macchina Down'
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        acc.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3 poiché la macchina che si occupa di inviare il dato non è al momento attiva. Riprovare in un secondo momento e, se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                    ));
                } catch (Exception ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        acc.Id, (recTypeCustomer == acc.RecordTypeId ? '/clienti' : '/prospect'), acc.Name, req, ex.getStackTraceString()
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        acc.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare ' + (acc.RecordTypeDeveloperName__c != null ? 'il ' + acc.RecordTypeDeveloperName__c : 'l\'Account') + ' "' + acc.Name + '" su Sage X3 per un errore non gestito.'
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
            //invia eventuali notifiche all'utente
            if(customNotificationList.size() > 0){
                for(SDG_ReST_CustomNotification cn : customNotificationList){
                    SDG_ReST_Utils.notifyUsers(
                        customNotificationMap, recipientIds, cn.targetId, cn.devName, cn.title, cn.body
                    );
                }
            } 
            
            //insert degli Account Terzi di appoggio
            if(terziToCreate.size() > 0){
                System.debug('Terzi di appoggio: ' + terziToCreate);
                insert terziToCreate;
            }
            //update degli Account con gli ExternalId di SageX3
            if(accountToUpdate.size() > 0){
                SDG_ReST_Utils.updateNoTrigger(accountToUpdate.values(), 'SDG_ReST_Prospect_Handler');
            }
            //update delle Location con gli ExternalId di SageX3
            if(locToUpdate.size() > 0){
                System.debug('Locations to update: ' + locToUpdate);
                SDG_ReST_Utils.updateNoTrigger(locToUpdate.values(), 'SDG_ReST_Location_Handler');
            }
            //update dei Contact con gli ExternalId di SageX3
            if(contactToUpdate.size() > 0){
                System.debug('Contacts to update: ' + contactToUpdate);
                SDG_ReST_Utils.updateNoTrigger(contactToUpdate.values(), 'SDG_ReST_Contatto_Handler');
                Formula.recalculateFormulas(contactToUpdate.values());
                System.debug('Formule dei contatti ricalcolate.');
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new SDG_ReST_Contatto(contactToUpdate.values()));
                }
            }

            //ramo chained queueable
            if(isChainable){
                //se l'opportunity non ha un external id, ricalcolane i dati e inviala a sage
                if(String.isEmpty(opp?.ExternalId__c)) {  
                    List<Opportunity> opps = new List<Opportunity>{opp};
                    Formula.recalculateFormulas(opps);
                    system.debug('TRATTATIVA RECALCULATE FORMULA = ' + opps);
                    if(!Test.isRunningTest() && String.isNotBlank(opps[0].Account_ExternalId__c)) System.enqueueJob(new SDG_ReST_Trattativa(opps));
                }
            }
        }
    }
    
    public static HttpResponse makeICAMRequest(String path, String body, Boolean env) {
        return SDG_ReST_Utils.makeRequest('POST', path, body, env);
    }
    
}