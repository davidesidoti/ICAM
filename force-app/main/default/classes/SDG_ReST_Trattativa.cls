public without sharing class SDG_ReST_Trattativa implements Queueable, Database.AllowsCallouts {

    private List<Opportunity> opportunities;

    public SDG_ReST_Trattativa(List<Opportunity> records){
        this.opportunities = records;
    }

    //execute Queueable
    public void execute(QueueableContext context) {

        Map<Id, Opportunity> opportunityToUpdate = new Map<Id, Opportunity>();
        Id recTypeService = SDG_ReST_Utils.getRecordType('Service', 'Opportunity');
        List<SDG_ReST_CustomEmail> customEmailList = new List<SDG_ReST_CustomEmail>();
        List<SDG_ReST_CustomNotification> customNotificationList = new List<SDG_ReST_CustomNotification>();
        Set<String> recipientIds = new Set<String>{UserInfo.getUserId()};

        //carica la lista delle email attive per le notifiche email in to, cc e bcc
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();  

        //se sono stati inviati delle Opportunity
        if(opportunities != null){

            //recupera tutti i CustomNotificationType e inseriscili in una mappa
            Map<String, CustomNotificationType> customNotificationMap = new Map<String, CustomNotificationType>();
            for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]){
                customNotificationMap.put(cntype.DeveloperName, cntype);
            }

            //recupera tutti i MapOpportunity da inviare al serializeRequest
            List<MapOpportunity__c> mapOppList = [SELECT Id, Name, Stage__c, SageX3__c FROM MapOpportunity__c];

            
                // per ogni Opportunity esegui la chiamata a SageX3 e se la risposta ritornata è 200, associa l'externalId__c all'Opportunity
                for(Opportunity opp : opportunities){

                    if(SDG_ReST_Utils.getSageStatusTrattativa(opp.StageName, mapOppList) != null){

                        String req = SDG_ReST_Trattativa_Request.serializeRequest(opp, mapOppList, true);
                        System.debug('JSON = ' + SDG_ReST_Trattativa_Request.serializeRequest(opp, mapOppList, false));
                        System.debug('JSON PRETTY = ' + req);
                        try {
                            //invia a SageX3 il JSON serializzato a partire dall'Opportunity
                            HttpResponse res = makeICAMRequest('trattative', req, SDG_ReST_Utils.IsSandbox());

                            System.debug('Response body = ' + res.getBody());
                            System.debug('STATUSCODE = ' + res.getStatusCode());

                            if(String.isNotBlank(res.getBody()) && res.getStatusCode() == 200){
                                 //risposta di SageX3 parsata in un SDG_ReST_SageResponse
                                SDG_ReST_SageResponse sageResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(res.getBody()));
                                
                                String sageRespPretty = System.JSON.serializePretty(sageResp, false);
                                System.debug('sageResp = ' + System.JSON.serialize(sageResp, false));
                                System.debug('sageRespPretty = ' + sageRespPretty);

                                //ramo creazione
                                if(res.getStatusCode() == 200 && opp.ExternalId__c == null) {
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
                                                        opp.Id, '/trattative', opp.Name, req, sageRespPretty
                                                    ));
                                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                                        opp.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile creare la Trattativa "' + opp.Name + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                                    ));
                                                    System.debug('Impossibile creare la Trattativa su SageX3. ERRORS: ' + sageResp.errors);
                                                    isLocked = true;  
                                                    break;
                                                }            
                                            }
                                        }

                                        //se tra gli errori non compare Scheda in corso di modifica
                                        if(isLocked == false){
                                            //notifica l'errore generico all'utente
                                            customEmailList.add(new SDG_ReST_CustomEmail(
                                                opp.Id, '/trattative', opp.Name, req, sageRespPretty
                                            ));
                                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                                opp.Id, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare la Trattativa "' + opp.Name + '" su Sage X3, di seguito gli errori: ' + (sageResp.errors != null ? sageResp.errors.toString() : ('risposta vuota (' + res.getBody() +')'))
                                            ));
                                            System.debug('Impossibile creare la Trattativa su SageX3. ERRORS: ' + sageResp.errors);
                                        }
                                    }
                                    
                                    //se la chiamata è andata a buon fine, estrapola l'external id
                                    else if(sageResp.messages != null){
                                        for(String mex : sageResp.messages){
                                            if( !('error'.equals(SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(mex, 5))) && opp.ExternalId__c == null){
                                                extId = SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(mex, 5);
                                                System.debug('EXTERNAL ID = ' + extId);
                                                Opportunity newOpp = new Opportunity(Id = opp.Id, ExternalId__c = extId);   
                                                if(opp.RecordTypeId == recTypeService && opp.StageName == 'New'){
                                                    newOpp.StageName = 'Inviata a Sage X3';
                                                }                        
                                                opportunityToUpdate.put(opp.Id, newOpp);   
                                                System.debug('Trattativa creata su SageX3.');
                                                break;
                                            }
                                        }
                                    }
                                }               

                                //ramo aggiornamento
                                else if(res.getStatusCode() == 200 && opp.ExternalId__c != null) {
                                    //se la chiamata è andata in errore
                                    if(sageResp.error && sageResp.errors != null){
                                        Boolean isLocked = false;
                                        for(String err : sageResp.errors){
                                            //se tra gli errori compare Scheda in corso di modifica
                                            if('Scheda in corso di modifica'.containsIgnoreCase(err)){
                                                //notifica l'errore all'utente
                                                customEmailList.add(new SDG_ReST_CustomEmail(
                                                    opp.Id, '/trattative', opp.Name, req, sageRespPretty
                                                ));
                                                customNotificationList.add(new SDG_ReST_CustomNotification(
                                                    opp.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare la Trattativa "' + opp.Name + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                                ));
                                                
                                                System.debug('Impossibile aggiornare la Trattativa su SageX3. ERRORS: ' + sageResp.errors);
                                                isLocked = true;  
                                                break;
                                            }            
                                        }

                                        //se tra gli errori non compare Scheda in corso di modifica
                                        if(isLocked == false){
                                            //notifica l'errore all'utente
                                            customEmailList.add(new SDG_ReST_CustomEmail(
                                                opp.Id, '/trattative', opp.Name, req, sageRespPretty
                                            ));
                                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                                opp.Id, 'Record_non_aggiornato_su_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare la Trattativa "' + opp.Name + '" su Sage X3, di seguito gli errori: ' + sageResp.errors
                                            ));
                                            System.debug('Impossibile aggiornare la Trattativa su SageX3. ERRORS: ' + sageResp.errors);
                                        }
                                    }
                                    //se la chiamata è andata a buon fine
                                    else{
                                        System.debug('Trattativa aggiornata su SageX3.');
                                    }
                                
                                }
                            }
                            else{
                                customEmailList.add(new SDG_ReST_CustomEmail(
                                    opp.Id, '/trattative', opp.Name, req, 'Sage X3 non raggiungibile'
                                ));
                                customNotificationList.add(new SDG_ReST_CustomNotification(
                                    opp.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare la Trattativa "' + opp.Name + '" su Sage X3 poiché non risulta raggiungibile, riprovare in un secondo momento. Se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                                ));
                            } 
                        } catch (System.CalloutException ex) {
                            customEmailList.add(new SDG_ReST_CustomEmail(
                                opp.Id, '/trattative', opp.Name, req, 'Macchina Down'
                            ));
                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                opp.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare la Trattativa "' + opp.Name + '" su Sage X3 poiché la macchina che si occupa di inviare il dato non è al momento attiva. Riprovare in un secondo momento e, se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                            ));
                        } catch (Exception ex) {
                            customEmailList.add(new SDG_ReST_CustomEmail(
                                opp.Id, '/trattative', opp.Name, req, ex.getStackTraceString()
                            ));
                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                opp.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare la Trattativa "' + opp.Name + '" su Sage X3 per un errore non gestito.'
                            ));
                        }                                   
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
            
            //update degli Opportunity con gli ExternalId di SageX3
            if(opportunityToUpdate.size() > 0){
                SDG_ReST_Utils.updateNoTrigger(opportunityToUpdate.values(), 'SDG_ReST_Trattativa_Handler');
            }
        }

    }
    
    public static HttpResponse makeICAMRequest(String path, String body, Boolean env) {
        return SDG_ReST_Utils.makeRequest('POST', path, body, env);
    }
    
}