@isTest
global without sharing class SDG_ReST_RunSyncComponentMock implements HttpCalloutMock{
    public Integer errorCode;

    public SDG_ReST_RunSyncComponentMock(Integer errorCode) {
        this.errorCode = errorCode;
    }

    global HttpResponse respond(HttpRequest request){
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        switch on errorCode {
            when 201 {// Sync Avviata
                response.setBody('OK');
            }
            when 200 { // Esiste già una sync avviata
                response.setBody('ERR');
            }
            when 400 { // Bad request
                response.setBody('ERR');
            }  
            when else { // Altro
                response.setBody('ERR');
            }
        }
        response.setStatusCode(errorCode);
        return response;
    }
}