public without sharing class SDG_ReST_Intervento implements Queueable, Database.AllowsCallouts {

    private Map<Id, WorkOrder> workOrders;
    Boolean isChainable;

    public SDG_ReST_Intervento(Map<Id, WorkOrder> records, Boolean isChainable){
        this.workOrders = records;
        this.isChainable = isChainable;
    }

    //execute Queueable
    public void execute(QueueableContext context) {

        Map<Id, Case> caseToUpdate = new Map<Id, Case>();
        Map<Id, WorkOrder> workOrderToUpdate = new Map<Id, WorkOrder>();
        Map<Id, ProductConsumed> productConsumedToUpdate = new Map<Id, ProductConsumed>();
        List<SDG_ReST_CustomEmail> customEmailList = new List<SDG_ReST_CustomEmail>();
        List<SDG_ReST_CustomNotification> customNotificationList = new List<SDG_ReST_CustomNotification>();
        Set<String> recipientIds = new Set<String>{UserInfo.getUserId()};

        //carica la lista delle email attive per le notifiche email in to, cc e bcc
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();

        //se sono stati inviati dei Work Order
        if(workOrders != null){

            //recupera tutti i CustomNotificationType e inseriscili in una mappa
            Map<String, CustomNotificationType> customNotificationMap = new Map<String, CustomNotificationType>();
            for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]){
                customNotificationMap.put(cntype.DeveloperName, cntype);
            }

            //recupera tutti i prodotti consumati collegati ai WorkOrder che non sono stati mandati a Sage X3
            List<ProductConsumed> productsConsumed = new List<ProductConsumed>(
                [SELECT Id, WorkOrderId, ExternalId__c, QuantityConsumed, IsSentToSageX3__c, Product2.ExternalId__c, ProductItem.ExternalId__c, Product2.QuantityUnitOfMeasure, 
                ProductItem.Lot__c, ProductItem.Status__c, ProductItem.Location.ExternalId__c, Product2.TypeOfArticle__c, Product2.StockExit__c FROM ProductConsumed 
                WHERE WorkOrderId IN :workOrders.keySet() AND ProductItem.ExternalId__c != null ORDER BY ExternalId__c NULLS LAST]
            );

            // per ogni intervento esegui la chiamata a SageX3 e se la risposta ritornata è 200, associa l'externalId__c al Work Order
            for(WorkOrder wo : workOrders.values()){

                String extId = '';

                //salva solo i prodotti consumati associati al WorkOrder interno al loop
                List<ProductConsumed> workOrderProductsConsumedList = new List<ProductConsumed>();
                Boolean hasAlmostOneProductToSendToSage = false;
                for(ProductConsumed prd : productsConsumed){
                    if(wo.Id == prd.WorkOrderId){
                        workOrderProductsConsumedList.add(prd);
                        if(prd.IsSentToSageX3__c == false){
                            hasAlmostOneProductToSendToSage = true;
                        }
                    }
                }
                String req = SDG_ReST_Intervento_Request.serializeRequest(wo, workOrderProductsConsumedList, true);
                System.debug('WORK ORDER - JSON = ' + SDG_ReST_Intervento_Request.serializeRequest(wo, workOrderProductsConsumedList, false));
                System.debug('WORK ORDER - JSON PRETTY = ' + req);

                try{
                    //invia a SageX3 il JSON serializzato a partire dal Work Order
                    HttpResponse workOrderResponse = makeICAMRequest('intervento', req, SDG_ReST_Utils.IsSandbox());

                    System.debug('WORK ORDER - Response body = ' + workOrderResponse.getBody());
                    System.debug('WORK ORDER - STATUSCODE = ' + workOrderResponse.getStatusCode());

                    if(String.isNotBlank(workOrderResponse.getBody()) && workOrderResponse.getStatusCode() == 200){
                        //risposta di SageX3 parsata in un SDG_ReST_SageResponse
                        SDG_ReST_SageResponse sageResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(workOrderResponse.getBody()));
                        
                        String sageRespPretty = System.JSON.serializePretty(sageResp, false);
                        System.debug('WORK ORDER - RISPOSTA DI SAGE X3 = ' + System.JSON.serializePretty(sageResp, false));
                        System.debug('WORK ORDER - RISPOSTA DI SAGE X3 PRETTY = ' + sageRespPretty);

                        //ramo creazione
                        if(wo.ExternalId__c == null) {
                            Boolean isLocked = false;
                            //se la chiamata è andata in errore
                            if(sageResp.created == false && (sageResp.errors != null || (sageResp.errors == null && sageResp.messages == null))){
                                if(sageResp.errors != null){
                                    for(String err : sageResp.errors){
                                        //se tra gli errori compare Scheda in corso di modifica
                                        if('Scheda in corso di modifica'.containsIgnoreCase(err)){
                                            //notifica l'errore all'utente
                                            customEmailList.add(new SDG_ReST_CustomEmail(
                                                wo.Id, '/intervento', wo.WorkOrderNumber, req, sageRespPretty
                                            ));
                                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                                wo.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile creare l\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                            ));
                                            isLocked = true;
                                            System.debug('Impossibile creare l\'Intervento su SageX3. ERRORS: ' + sageResp.errors);  
                                            break;
                                        }            
                                    }
                                }
                                

                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){

                                    //tentativo di recuperare l'external id dal db di Sage X3 effettuando una GET ed estrapolando il NUM dall'intervento, e riconciliare il record
                                    if(wo.Case_ExternalId__c != null && sageResp.error == false && sageResp.errors == null && sageResp.warnings == null && sageResp.messages == null){
                                        
                                        System.debug('Chiamata vuota dell\'intervento, tentativo di recuperare l\'external id e agganciarlo al work order per riconciliare.');
                                        HttpResponse workOrderExternalIdQueryResponse = makeICAMRequest('interventoGet', JSON.serialize(wo), SDG_ReST_Utils.IsSandbox());
                
                                        if(workOrderExternalIdQueryResponse.getBody() != null){
                                            try {
                                                String extIdResponse = SDG_ReST_Utils.extractExternalIdFromGetIntervento(workOrderExternalIdQueryResponse.getBody());
                                                System.debug('extIdResponse: ' + extIdResponse);
                                                if(String.isNotBlank(extIdResponse)){
                                                    workOrderToUpdate.put(wo.Id, new WorkOrder(Id = wo.Id, ExternalId__c = extIdResponse));
                                                    System.debug('External Id Work Order agganciato.');
                                                    System.debug('Intervento creato su SageX3.');
                                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                                        wo.Id, '/intervento', wo.WorkOrderNumber, 'External Id Work Order recuperato tramite GET e agganciato: ' + extIdResponse, sageRespPretty
                                                    ));
                                                }
                                                
                                            }                                  
                                            catch (Exception exc) {
                                                System.debug('Errore durante il tentativo di riconciliazione: ' + exc);
                                                //notifica l'errore generico all'utente
                                                customEmailList.add(new SDG_ReST_CustomEmail(
                                                    wo.Id, '/intervento', wo.WorkOrderNumber, req + '</pre></li><li><b style="color:#e5142c;">Errore durante il tentativo di riconciliazione:</b><br><pre>' + exc + '<br>' + workOrderExternalIdQueryResponse.getBody(), sageRespPretty
                                                ));
                                                customNotificationList.add(new SDG_ReST_CustomNotification(
                                                    wo.Id, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare l\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3, di seguito gli errori: ' + (sageResp.errors != null ? sageResp.errors.toString() : ('risposta vuota (' + workOrderResponse.getBody() +')'))
                                                ));
                                                System.debug('Impossibile creare l\'Intervento su SageX3. ERRORS: ' + sageResp.errors);  
                                            }
                                        }
                                    }

                                    else{
                                        //notifica l'errore generico all'utente
                                        customEmailList.add(new SDG_ReST_CustomEmail(
                                            wo.Id, '/intervento', wo.WorkOrderNumber, req, sageRespPretty
                                        ));
                                        customNotificationList.add(new SDG_ReST_CustomNotification(
                                            wo.Id, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare l\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3, di seguito gli errori: ' + (sageResp.errors != null ? sageResp.errors.toString() : ('risposta vuota (' + workOrderResponse.getBody() +')'))
                                        ));
                                        System.debug('Impossibile creare l\'Intervento su SageX3. ERRORS: ' + sageResp.errors);  
                                    }                         
                                }
                                
                            }
                            
                            //se la chiamata è andata a buon fine, estrapola l'external id
                            else if(sageResp.messages != null){
                                for(String mex : sageResp.messages){
                                    if( !('error'.equals(SDG_ReST_Utils.extractExternalIdFromMessage(mex))) && wo.ExternalId__c == null){
                                        extId = SDG_ReST_Utils.extractExternalIdFromMessage(mex);
                                        System.debug('EXTERNAL ID = ' + extId);
                                        workOrderToUpdate.put(wo.Id, new WorkOrder(Id = wo.Id, ExternalId__c = extId));   
                                        System.debug('Intervento creato su SageX3.');
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
                                            wo.Id, '/intervento', wo.WorkOrderNumber, req, sageRespPretty
                                        ));
                                        customNotificationList.add(new SDG_ReST_CustomNotification(
                                            wo.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare l\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                        ));
                                        System.debug('Impossibile aggiornare l\'Intervento su SageX3. ERRORS: ' + sageResp.errors);
                                        isLocked = true;  
                                        break;
                                    }                          
                                }
                                
                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore generico all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        wo.Id, '/intervento', wo.WorkOrderNumber, req, sageRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        wo.Id, 'Record_non_aggiornato_su_Sage_X3', null, 'ERRORE: non è stato possibile aggiornare l\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3, di seguito gli errori: ' + sageResp.errors
                                    ));
                                    System.debug('Impossibile aggiornare l\'Intervento su SageX3. ERRORS: ' + sageResp.errors);
                                }
                            }
                            //se la chiamata è andata a buon fine
                            else{
                                extId = wo.ExternalID__c;
                                System.debug('Intervento aggiornato su SageX3.');
                            }
                        
                        }
                    }
                    else{
                        customEmailList.add(new SDG_ReST_CustomEmail(
                            wo.Id, '/intervento', wo.WorkOrderNumber, req, 'Sage X3 non raggiungibile'
                        ));
                        customNotificationList.add(new SDG_ReST_CustomNotification(
                            wo.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare l\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché non risulta raggiungibile, riprovare in un secondo momento. Se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                        ));
                    }
                } catch (System.CalloutException ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        wo.Id, '/intervento', wo.WorkOrderNumber, req, 'Macchina Down'
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        wo.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare l\'intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché la macchina che si occupa di inviare il dato non è al momento attiva. Riprovare in un secondo momento e, se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                    ));
                } catch (Exception ex) {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        wo.Id, '/intervento', wo.WorkOrderNumber, req, ex.getStackTraceString()
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        wo.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare l\'intervento "' + wo.WorkOrderNumber + '" su Sage X3 per un errore non gestito.'
                    ));
                } 
     

                //////////////////////////////////////////////////////////////  
                //se sono stati inviati dei ProductConsumed
                if(extId != null && workOrderProductsConsumedList.size() > 0 && hasAlmostOneProductToSendToSage){
                    String reqPrdCns = SDG_ReST_Uscita_Diversa.serializeRequest(extId, workOrderProductsConsumedList, true);
                    System.debug('PRODUCT CONSUMED - JSON = ' + SDG_ReST_Uscita_Diversa.serializeRequest(extId, workOrderProductsConsumedList, false));
                    System.debug('PRODUCT CONSUMED - JSON PRETTY = ' + reqPrdCns);

                    try {
                        
                        //invia a SageX3 il JSON serializzato a partire dal Work Order
                        HttpResponse productConsumedResponse = makeICAMRequest('uscite-diverse', reqPrdCns, SDG_ReST_Utils.IsSandbox());

                        System.debug('PRODUCT CONSUMED - Response body = ' + productConsumedResponse.getBody());
                        System.debug('PRODUCT CONSUMED - STATUSCODE = ' + productConsumedResponse.getStatusCode());

                        if(String.isNotBlank(productConsumedResponse.getBody()) && productConsumedResponse.getStatusCode() == 200){
                            //risposta di SageX3 parsata in un SDG_ReST_SageResponse
                            SDG_ReST_SageResponse sagePrdCmdResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(productConsumedResponse.getBody()));

                            String sagePrdCmdRespPretty = System.JSON.serializePretty(sagePrdCmdResp, false);
                            System.debug('PRODUCT CONSUMED - RISPOSTA DI SAGE X3 = ' + System.JSON.serialize(sagePrdCmdResp, false));
                            System.debug('PRODUCT CONSUMED - RISPOSTA DI SAGE X3 PRETTY = ' + sagePrdCmdRespPretty);

                            //ramo creazione

                            Boolean isLocked = false;
                            //se la chiamata è andata in errore
                            if(sagePrdCmdResp.error){
                                for(String err : sagePrdCmdResp.errors){
                                    //se tra gli errori compare Scheda in corso di modifica
                                    if('Scheda in corso di modifica'.containsIgnoreCase(err)){
                                        //notifica l'errore all'utente
                                        customEmailList.add(new SDG_ReST_CustomEmail(
                                            wo.Id, '/uscite-diverse', wo.WorkOrderNumber, reqPrdCns, sagePrdCmdRespPretty
                                        ));
                                        customNotificationList.add(new SDG_ReST_CustomNotification(
                                            wo.Id, 'Scheda_in_corso_di_modifica_Sage_X3', null, 'ERRORE: non è stato possibile creare l\'Uscita Diversa legata all\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché la scheda è in corso di modifica sull\'altro gestionale.'
                                        ));
                                        System.debug('Impossibile creare l\'Uscita Diversa su SageX3. ERRORS: ' + sagePrdCmdResp.errors);
                                        isLocked = true; 
                                        break;
                                    }
                                }
                                //se tra gli errori non compare Scheda in corso di modifica
                                if(isLocked == false){
                                    //notifica l'errore generico all'utente
                                    customEmailList.add(new SDG_ReST_CustomEmail(
                                        wo.Id, '/uscite-diverse', wo.WorkOrderNumber, reqPrdCns, sagePrdCmdRespPretty
                                    ));
                                    customNotificationList.add(new SDG_ReST_CustomNotification(
                                        wo.Id, 'Record_non_inserito_su_Sage_X3', null, 'ERRORE: non è stato possibile creare l\'Uscita Diversa legata all\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3, di seguito gli errori: ' + sagePrdCmdResp.errors
                                    ));
                                    System.debug('Impossibile creare l\'Uscita Diversa su SageX3. ERRORS: ' + sagePrdCmdResp.errors);
                                }
                            }
                            //se la chiamata è andata a buon fine, aggiorna la checkbox e l'externalId sui record
                            else {
                                for(ProductConsumed prd : workOrderProductsConsumedList){
                                    productConsumedToUpdate.put(prd.Id, new ProductConsumed(Id = prd.Id, IsSentToSageX3__c = true, ExternalId__c = prd.ExternalId__c));                               
                                }
                                System.debug('Uscita Diversa creata su SageX3.');                   
                            }                            
                        }
                        else{
                            customEmailList.add(new SDG_ReST_CustomEmail(
                                wo.Id, '/uscite-diverse', wo.WorkOrderNumber, reqPrdCns, 'Sage X3 non raggiungibile'
                            ));
                            customNotificationList.add(new SDG_ReST_CustomNotification(
                                wo.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare l\'Uscita Diversa legata all\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché non risulta raggiungibile, riprovare in un secondo momento. Se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                            ));
                        }
                    } catch (System.CalloutException ex) {
                        customEmailList.add(new SDG_ReST_CustomEmail(
                            wo.Id, '/uscite-diverse', wo.WorkOrderNumber, reqPrdCns, 'Macchina Down'
                        ));
                        customNotificationList.add(new SDG_ReST_CustomNotification(
                            wo.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare l\'Uscita Diversa legata all\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 poiché la macchina che si occupa di inviare il dato non è al momento attiva. Riprovare in un secondo momento e, se il problema dovesse ripresentarsi, evitare di aggiornare altri record e contattare l\'amministratore di sistema o Ciro Marciano, grazie.'
                        ));
                    } catch (Exception ex) {
                        customEmailList.add(new SDG_ReST_CustomEmail(
                            wo.Id, '/uscite-diverse', wo.WorkOrderNumber, reqPrdCns, ex.getStackTraceString()
                        ));
                        customNotificationList.add(new SDG_ReST_CustomNotification(
                            wo.Id, 'Errore_Sage_X3', null, 'ERRORE: non è stato possibile inviare l\'Uscita Diversa legata all\'Intervento "' + wo.WorkOrderNumber + '" su Sage X3 per un errore non gestito.'
                        ));
                    } 
                }
                //////////////////////////////////////////////////////////////  

                //ramo chained queueable
                if(isChainable){
                    if(wo.CaseId != null && !wo.Case_Status__c.equals('5')){
                        caseToUpdate.put(wo.CaseId, (new Case(Id = wo.CaseId, Status = '5')));
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

            //update dei ProductConsumed con gli ExternalId di SageX3
            if(productConsumedToUpdate.size() > 0){
                update productConsumedToUpdate.values();
            }

            //update dei Work Order con gli ExternalId di SageX3
            if(workOrderToUpdate.size() > 0){
                SDG_ReST_Utils.updateNoTrigger(workOrderToUpdate.values(), 'SDG_ReST_Intervento_Handler');
            }

            //ramo chained queueable
            if(isChainable && caseToUpdate.size() > 0){
                update caseToUpdate.values();
            }
        }

    }
    
    public static HttpResponse makeICAMRequest(String path, String body, Boolean env) {
        return SDG_ReST_Utils.makeRequest('POST', path, body, env);
    }
    
}