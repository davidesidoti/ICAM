public without sharing class SDG_ReST_RichiestaDiServizio implements Queueable, Database.AllowsCallouts {
    
    private Map<Id, Case> cases;
    private Boolean isFromMainenancePlan;

    //costruttore per le richieste di servizio
    public SDG_ReST_RichiestaDiServizio(Map<Id, Case> records, Boolean isFromMainenancePlan){
        this.cases = records;
        this.isFromMainenancePlan = isFromMainenancePlan;
    }

    public SDG_ReST_RichiestaDiServizio(Map<Id, Case> records){
        this.cases = records;
        this.isFromMainenancePlan = false;
    }

    //execute Queueable
    public void execute(QueueableContext context) {

        Map<Id, Case> caseToUpdate = new Map<Id, Case>();
        Map<Id, MaintenancePlan> maintenancePlanToUpdate = new Map<Id, MaintenancePlan>();
        List<SDG_ReST_CustomEmail> customEmailList = new List<SDG_ReST_CustomEmail>();
        List<SDG_ReST_CustomNotification> customNotificationList = new List<SDG_ReST_CustomNotification>();
        Set<String> recipientIds = new Set<String>{UserInfo.getUserId()};

        //carica la lista delle email attive per le notifiche email in to, cc e bcc
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();        

        //se sono stati inviati dei Case
        if(cases != null){

            //recupera tutti i CustomNotificationType e inseriscili in una mappa
            Map<String, CustomNotificationType> customNotificationMap = new Map<String, CustomNotificationType>();
            for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]){
                customNotificationMap.put(cntype.DeveloperName, cntype);
            }

            // per ogni Case esegui la chiamata a SageX3 e se la risposta ritornata è 200, associa ExternalId__c al Case
            for(Id cId : cases.keySet()){
                Case c = cases.get(cId);
                String caseName = isFromMainenancePlan ? 'Richiesta di servizio fittizia per il piano di manutenzione con Id ' + cId : c.CaseNumber;
                String req = SDG_ReST_RichiestaDiServizio_Request.serializeRequest(c, true);

                System.debug('JSON = ' + SDG_ReST_RichiestaDiServizio_Request.serializeRequest(c, false));
                System.debug('JSON PRETTY = ' + req);

                try{
                    //invia a SageX3 il JSON serializzato a partire dal Case
                    HttpResponse res = makeICAMRequest('richieste-servizio', req, SDG_ReST_Utils.IsSandbox());

                    System.debug('Response body = ' + res.getBody());
                    System.debug('STATUSCODE = ' + res.getStatusCode());

                    if(String.isNotBlank(res.getBody()) && res.getStatusCode() == 200){
                    
                        //risposta di SageX3 parsata in un SDG_ReST_SageResponse
                        SDG_ReST_SageResponse sageResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(res.getBody()));
                        
                        String sageRespPretty = System.JSON.serializePretty(sageResp, false);
                        System.debug('sageResp = ' + System.JSON.serialize(sageResp, false)); 
                        System.debug('sageRespPretty = ' + sageRespPretty);               

                        //ramo creazione
                        if(c.ExternalId__c == null){
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
                                                cId, '/richieste-servizio', caseName, req, sageRespPretty
                                            ));
                                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                                cId, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile creare la Richiesta di Servizio "' + caseName + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                            ));
                                            System.debug('Impossibile creare la Richiesta di servizio su SageX3. ERRORS: ' + sageResp.errors);
                                            isLocked = true;  
                                            break;
                                        }            
                                    }
                                }
                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore generico all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        cId, '/richieste-servizio', caseName, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        cId, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare la Richiesta di Servizio "' + caseName + '" su Sage X3, di seguito gli errori: ' + (sageResp.errors != null ? sageResp.errors.toString() : ('risposta vuota (' + res.getBody() +')'))
                                    ));
                                    System.debug('Impossibile creare la Richiesta di servizio su SageX3. ERRORS: ' + sageResp.errors);
                                }                      
                            }
                        
                            //se la chiamata è andata a buon fine, estrapola l'external id
                            else if(sageResp.messages != null){
                                for(String mex : sageResp.messages){
                                    if( !('error'.equals(SDG_ReST_Utils.extractExternalIdFromMessage(mex)))){
                                        extId = SDG_ReST_Utils.extractExternalIdFromMessage(mex);
                                        System.debug('EXTERNAL ID = ' + extId);
                                        if(isFromMainenancePlan){
                                            //maintenancePlanToUpdate.put(cId, new MaintenancePlan(Id = cId, CaseExternalId__c = extId));   
                                        }
                                        else{
                                            caseToUpdate.put(cId, new Case(Id = cId, ExternalId__c = extId));   
                                        }  
                                        System.debug('Richiesta di servizio creata su SageX3.');
                                        break;
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
                                            cId, '/richieste-servizio', caseName, req, sageRespPretty
                                        ));
                                        customNotificationList.add(new SDG_ReST_CustomNotification(
                                            cId, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare la Richiesta di Servizio "' + caseName + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                        ));
                                        System.debug('Impossibile aggiornare la Richiesta di servizio su SageX3. ERRORS: ' + sageResp.errors);
                                        isLocked = true;  
                                        break;
                                    }            
                                }
                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        cId, '/richieste-servizio', caseName, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        cId, 'Record_non_aggiornato_su_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare la Richiesta di Servizio "' + caseName + '" su Sage X3, di seguito gli errori: ' + sageResp.errors
                                    )); 
                                    System.debug('Impossibile aggiornare la Richiesta di servizio su SageX3. ERRORS: ' + sageResp.errors);
                                }
                            }
                            //se la chiamata è andata a buon fine
                            else{
                                System.debug('Richiesta di servizio aggiornata su SageX3.');
                            }
                        
                        }
                    }
                    else{
                        customEmailList.add(new SDG_ReST_CustomEmail(
                            cId, '/richieste-servizio', caseName, req, 'Sage X3 non raggiungibile'
                        ));
                        customNotificationList.add(new SDG_ReST_CustomNotification(
                            cId, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare la Richiesta di Servizio "' + caseName + '" su Sage X3 poiché non risulta raggiungibile, riprovare in un secondo momento. Se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                        ));
                    } 
                } catch (System.CalloutException ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        cId, '/richieste-servizio', caseName, req, 'Macchina Down'
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        cId, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare la Richiesta di Servizio "' + caseName + '" su Sage X3 poiché la macchina che si occupa di inviare il dato non è al momento attiva. Riprovare in un secondo momento e, se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                    ));
                } catch (Exception ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        cId, '/richieste-servizio', caseName, req, ex.getStackTraceString()
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        cId, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare la Richiesta di Servizio "' + caseName + '" su Sage X3 per un errore non gestito.'
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

            //update dei Case con gli ExternalId di SageX3
            if(caseToUpdate.size() > 0){
                SDG_ReST_Utils.updateNoTrigger(caseToUpdate.values(), 'SDG_ReST_RichiestaDiServizio_Handler');
            }

            //update dei MaintenancePlan con gli ExternalId di SageX3
            if(maintenancePlanToUpdate.size() > 0){
                SDG_ReST_Utils.updateNoTrigger(maintenancePlanToUpdate.values(), 'SDG_ReST_PianoDiManutenzione_Handler');
            }
        }
    }
    
    public static HttpResponse makeICAMRequest(String path, String body, Boolean env) {
        return SDG_ReST_Utils.makeRequest('POST', path, body, env);
    }
    
}