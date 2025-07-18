@RestResource(urlMapping='/SyncLog/v1/*')
global without sharing class SDG_ReST_SyncLog {

    @HttpPost
    global static void createLog() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json;charset=UTF-8');

        //BEARER Token assente o non corretto
        if ((!RestContext.request.headers.containsKey('X-API-Token')) || (!RestContext.request.headers.get('X-API-Token').equals(SDG_ReST_Utils.BEARER_TOKEN))) { 
            SDG_ReST_SyncLogResponse risposta = new SDG_ReST_SyncLogResponse();
            risposta.status = 'ERROR';
            risposta.statusMessage = 'UnAuthorized';
            res.responseBody = Blob.valueOf(risposta.toString());
            res.statusCode = 401;
        //BEARER Token corretto
        } else {
             try {
                SDG_ReST_SyncLog_Request.insertSyncLog(req.requestbody.tostring());
                Integer logDeleted = SDG_ReST_SyncLog_Request.deleteOldSyncLog(SDG_ReST_Utils.SYNCLOG_DAYS);
                res.statusCode = 200;
                SDG_ReST_SyncLogResponse risposta = new SDG_ReST_SyncLogResponse();
                risposta.status = 'OK';
                risposta.statusMessage = 'Log inseriti' + (logDeleted > 0 ? (' ed eliminati i log più vecchi di ' + SDG_ReST_Utils.SYNCLOG_DAYS + ' giorni (' + logDeleted + ').') : '.');
                res.responseBody = Blob.valueOf(risposta.toString());
                
            } catch (Exception e) {
                System.debug(e.getMessage());
                SDG_ReST_SyncLogResponse risposta = new SDG_ReST_SyncLogResponse();
                
                risposta.status = 'ERROR';
                risposta.statusMessage = 'ERROR: ' + e.getMessage();
                res.responseBody = Blob.valueOf(risposta.toString());
                res.statusCode = 500;
            } 

        }
    }
}