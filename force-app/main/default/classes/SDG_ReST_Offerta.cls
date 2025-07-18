public without sharing class SDG_ReST_Offerta implements Queueable, Database.AllowsCallouts {

    private List<QuoteCustom__c> offers;
    private Opportunity opp;
    private Boolean isChainable;

    public SDG_ReST_Offerta(List<QuoteCustom__c> offers, Opportunity opp, Boolean isChainable){
        this.offers = offers;
        this.opp = opp;
        this.isChainable = isChainable;
    }

    public void execute(QueueableContext context) {
        Map<Id, QuoteCustom__c> offerToUpdate = new Map<Id, QuoteCustom__c>();
        List<SDG_ReST_CustomEmail> customEmailList = new List<SDG_ReST_CustomEmail>();
        List<SDG_ReST_CustomNotification> customNotificationList = new List<SDG_ReST_CustomNotification>();
        Set<String> recipientIds = new Set<String>{ UserInfo.getUserId() };
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();

        // Load all available CustomNotificationType
        Map<String, CustomNotificationType> customNotificationMap = new Map<String, CustomNotificationType>();
        for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]) {
            customNotificationMap.put(cntype.DeveloperName, cntype);
        }

        for(QuoteCustom__c off : offers) {
            String req = SDG_ReST_Offerta_Request.serializeRequest(off, true);
            System.debug('REQUEST OFFER = ' + req);
            try {
                HttpResponse res = makeICAMRequest('GenCliOrd', req, SDG_ReST_Utils.IsSandbox());
                System.debug('Response body = ' + res.getBody());
                System.debug('STATUSCODE = ' + res.getStatusCode());

                if(res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                    SDG_ReST_SageResponse sageResp = SDG_ReST_SageResponse.parse(SDG_ReST_Utils.getBodySanitized(res.getBody()));
                    String pretty = JSON.serializePretty(sageResp, false);

                    // creation branch
                    if(off.ExternalId__c == null) {
                        if(sageResp.messages != null) {
                            for(String msg : sageResp.messages) {
                                String ext = SDG_ReST_Utils.extractExternalIdOnDemandFromMessage(msg, 15);
                                if(String.isNotBlank(ext)) {
                                    offerToUpdate.put(off.Id, new QuoteCustom__c(
                                        Id = off.Id,
                                        ExternalId__c = ext
                                    ));
                                    break;
                                }
                            }
                        }
                    }
                }
                else {
                    customEmailList.add(new SDG_ReST_CustomEmail(
                        off.Id, '/quotecustom__c', off.Name, req, res.getBody()
                    ));
                    customNotificationList.add(new SDG_ReST_CustomNotification(
                        off.Id, 'Errore_Offerta_Sage_X3', null,
                        'ERRORE: non è stato possibile inviare l\'Offerta "' + off.Name + '" su Sage X3.'
                    ));
                }
            } catch(Exception ex) {
                customEmailList.add(new SDG_ReST_CustomEmail(
                    off.Id, '/quotecustom__c', off.Name, req, ex.getMessage()
                ));
                customNotificationList.add(new SDG_ReST_CustomNotification(
                    off.Id, 'Errore_Offerta_Sage_X3', null,
                    'ERRORE: eccezione inviando l\'Offerta to Sage X3: ' + ex.getMessage()
                ));
            }
        }

        // Send any accumulated emails
        if(!customEmailList.isEmpty()) {
            String bodyEmail = '';
            for(SDG_ReST_CustomEmail ce : customEmailList) {
                bodyEmail += (String.isNotBlank(bodyEmail) ? '<hr>' : '') +
                    '<ul>' +
                        '<li><b style="color:#e5142c;">Link a Salesforce:</b> <a href="' + ce.urlSalesforce + '">Link</a></li>' +
                        '<li><b style="color:#e5142c;">Relative Path:</b> ' + ce.urlPath + '</li>' +
                        '<li><b style="color:#e5142c;">Nome Record:</b> ' + ce.objectName + '</li>' +
                        '<li><b style="color:#e5142c;">Body Chiamata:</b><pre>' + ce.request + '</pre></li>' +
                        '<li><b style="color:#e5142c;">Body Risposta:</b><pre>' + ce.response + '</pre></li>' +
                    '</ul>';
            }
            SDG_ReST_Utils.sendNotificationEmail(
                '[ICAM] Errore sync Offerta -> Sage X3',
                bodyEmail,
                addressList.get('toaddress'), addressList.get('ccaddress'), addressList.get('bccaddress')
            );
        }

        // Update external IDs on QuoteCustom__c
        if(!offerToUpdate.isEmpty()) {
            SDG_ReST_Utils.updateNoTrigger(offerToUpdate.values(), 'SDG_ReST_Offerta_Handler');
        }

        // Send in-app notifications
        if(!customNotificationList.isEmpty()) {
            for(SDG_ReST_CustomNotification cn : customNotificationList) {
                SDG_ReST_Utils.notifyUsers(
                    customNotificationMap, recipientIds,
                    cn.targetId, cn.devName, cn.title, cn.body
                );
            }
        }
    }

    public static HttpResponse makeICAMRequest(String path, String body, Boolean env) {
        return SDG_ReST_Utils.makeRequest('POST', path, body, env);
    }
}
