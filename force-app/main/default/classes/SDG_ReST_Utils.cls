global class SDG_ReST_Utils {

    public static String ICAM_BASEURL = sdg_rest_settings__c.getInstance().BASEURL__c;
    public static String BEARER_TOKEN = sdg_rest_settings__c.getInstance().BEARER_TOKEN__c;
    public static Integer SYNCLOG_DAYS = 5;

    //verifica se l'ambiente è una Sandbox o no
    global static Boolean IsSandbox(){
        return [SELECT IsSandbox FROM Organization LIMIT 1].isSandbox;
    }

    //cattura codici Sage del tipo ICAM12202ACT00000147 o ICAM12202SRE00000147
    public static String extractExternalIdFromGetIntervento(String mex) {
        String regex = '(.*"NUM": {0,1}")(ICAM[0-9]{5}[A-Z]{3}[0-9]{8})(".*)';        
        Pattern p = Pattern.compile(regex);
        Matcher pm = p.matcher(mex);
        return pm.matches() ? pm.group(2) : '';
    }

    //cattura codici Sage del tipo ICAM12202ACT00000147 o ICAM12202SRE00000147
    public static String extractExternalIdFromMessage(String mex) {
        String regex = '(.*)(ICAM[0-9]{5}[A-Z]{3}[0-9]{8})(.*)';        
        Pattern p = Pattern.compile(regex);
        Matcher pm = p.matcher(mex);
        return pm.matches() ? pm.group(2) : 'error';
    }

    //cattura codici Sage del tipo 16858 o 000000000000642 o 004960
    public static String extractExternalIdOnDemandFromMessage(String mex, Integer length) {
        String regex = '(.*)([0-9]{' + length + '})(.*)';        
        Pattern p = Pattern.compile(regex);
        Matcher pm = p.matcher(mex);
        return pm.matches() ? pm.group(2) : 'error'; 
    }

    //metodo per eseguire gli update senza far scattare i relativi trigger, il che farebbe generare un loop infinito
    public static void updateNoTrigger(List<SObject> recordToUpdate, String HandlerApexClass){
        TR_BaseTriggerHandler.bypass(HandlerApexClass);
        update recordToUpdate;
        System.debug('è Bypassato?---->'+TR_BaseTriggerHandler.isBypassed(HandlerApexClass));
        TR_BaseTriggerHandler.clearBypass(HandlerApexClass);
    }

    //chiamata al proxy che a sua volta ribalta la chiamata a SageX3
    global static HttpResponse makeRequest(String method, String path, String body, Boolean env) {
        Http http = new Http();
        HttpRequest postRequest = new HttpRequest();
        postRequest.setEndpoint(ICAM_BASEURL + path + ((env == true) ? '?env=test' : '')); 
        //VALIDAZIONE SE != GET O POST, METTERE GET
        postRequest.setMethod((method.equals('GET') || method.equals('POST')) ? method : 'GET');
        postRequest.setHeader('Authorization', 'Bearer ' + BEARER_TOKEN);
        postRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
        postRequest.setHeader('Salesforce-User-Name', UserInfo.getName());
        postRequest.setHeader('Salesforce-User-Email', UserInfo.getUserEmail());
        if(body != null){
            postRequest.setBody(body);
        } 
        postRequest.setTimeout(120000);
        System.debug('Creazione chiamata a SageX3 = ' + postRequest);
        System.debug('Body chiamata a SageX3 = ' + postRequest.getBody());

        return http.send(postRequest);
    }

    //formatta la data in una stringa nel form desiderato
	public static String dateFormat(Date dt, String form){
        return ( dt != null ? (DateTime.newInstance(dt?.year(), dt?.month(), dt?.day())).format(form) : null);       
    }

    //ritorna il recordType dell'sObject specificato tramite il developerName desiderato
    public static Id getRecordType(String developerName, String s_object){
        return Schema.getGlobalDescribe().get(s_object).getDescribe().getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }

    //recupera il codice togliento la prima parte (BPC_ o PPT_ o BPR_)
	public static String getExtId(String str, String index){
        return (str != null && str.contains(index)) ? str.substringAfterLast(index) : (str != null ? str : null);
    }

    //ripulisce le [] iniziali di una risposta Sage X3
	public static String getBodySanitized(String body){
        return String.isNotBlank(body) && body.startsWith('[') && body.endsWith(']') ? body.substring(1, body.length() - 1) : body;
    }

    //recupera l'API dello stato di Sage tramite l'oggetto di mapping
    public static String getSageStatusTrattativa(String status, List<MapOpportunity__c> mapOppList){
        Map<String, String> statusMap = new Map<String,String>();
        for(MapOpportunity__c mo : mapOppList){
            statusMap.put(mo.Stage__c, mo.SageX3__c);
        }
        return statusMap.containsKey(status)? statusMap.get(status) : null;
    }

    //formatta un boolean in 2 / 1
    public static String boolToString(Boolean flag){
        return ((flag != null) && flag) ? '2' : '1';
    }

    //recupera il campo isToAvoid__c dall'utente che sta chiamandao il metodo
    public static Boolean checkIsToAvoid(Id userId){
        return (userId != null) ? [SELECT Id, isToAvoid__c FROM User WHERE Id = :userId LIMIT 1]?.isToAvoid__c : false;
    }

    //costruisce e invia una notifica all'utente che l'ha fatta scattare
    public static void notifyUsers(Map<String, CustomNotificationType> customNotificationMap, Set<String> recipientsIds, String targetId, String devName, String title, String body) {

        if(customNotificationMap == null){
            customNotificationMap = new Map<String, CustomNotificationType>();
            for(CustomNotificationType cntype : [SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType]){
                customNotificationMap.put(cntype.DeveloperName, cntype);
            }
        }
        //Recupera il notificationType specificato
        CustomNotificationType notificationType = customNotificationMap.get(devName);
        
        if(notificationType != null){
            //Crea una notifica custom
            Messaging.CustomNotification notification = new Messaging.CustomNotification();

            //Imposta il contenuto della notifica
            notification.setTitle(title != null ? title : notificationType.MasterLabel);
            notification.setBody(body);

            //Imposta type e target della notifica
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(targetId);
            
            try {
                //Invia la notifica
                notification.send(recipientsIds);
                System.debug('Notifica Custom inviata!');
            } catch (Exception ex) {
                System.debug('Eccezione Notifica Custom: ' + ex);
                String bodyEmail = (
                    '<ul>' + 
                        '<li><b style="color:#e5142c;">Link a Salesforce:</b> <a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + targetId + '">Link</a></li>' +
                        '<li><b style="color:#e5142c;">Nome Notifica:</b> ' + (title != null ? title : notificationType.MasterLabel) + '</li>' +
                        '<li><b style="color:#e5142c;">Tipologia Notifica:</b> ' + notificationType.Id + '</li>' +
                        '<li><b style="color:#e5142c;">Body Notifica:</b> ' + body + '</li>' +
                        '<li><b style="color:#e5142c;">Eccezione:</b><br><pre>' + ex + '</pre></li>' +
                    '</ul>'
                );

                sendNotificationEmail(
                    '[ICAM] Errore notifica Salesforce', bodyEmail, getAddessesList().get('toaddress'), getAddessesList().get('ccaddress'), getAddessesList().get('bccaddress')
                );

                System.debug('Email errore Notifica Custom inviata!');
            }
        }
    }

    //costruisce e invia una mail agli indirizzi specificati tramite l'email dell'utente che l'ha fatta scattare
    public static void sendNotificationEmail(String subject, String body, List<String> addresses, List<String> ccaddresses, List<String> bccaddresses) {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.ccaddresses = ccaddresses;
        message.bccaddresses = bccaddresses;
        message.toAddresses = addresses;
        //message.optOutPolicy = 'FILTER';
        message.subject = subject; 
        message.setHtmlBody(body);
        if(!addresses.isEmpty()){
            Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
            if(!Test.isRunningTest()) Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        }        
    }

    //carica la lista delle email attive per le notifiche email in to, cc e bcc
    public static Map<String, List<String>> getAddessesList(){
             
        Map<String, List<String>> addressList = new Map<String, List<String>>{
            'toaddress' => new List<String>(), 
            'ccaddress' => new List<String>(), 
            'bccaddress' => new List<String>()
        };

        for(EmailCustom__c addr : EmailCustom__c.getAll().values()){
            if(addressList.containsKey(addr.Type__c) && addr.Active__c){
                addressList.get(addr.Type__c).add(addr.Email__c);
            }
        }
        return addressList;
    }
    
}