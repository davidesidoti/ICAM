@isTest 
global without sharing class SDG_ReST_Request_HttpCalloutMock implements HttpCalloutMock {

    public String path;
    public Integer status;

    global SDG_ReST_Request_HttpCalloutMock(String path, Integer status){
        this.path = path;
        this.status = status;
    }

    global HTTPResponse respond(HTTPRequest request) {
        
        // Create a fake response
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        response.setStatusCode(status);
        switch on path {
            when 'intervento' {
                response.setBody('[{"error":false,"created":true,"errors":null,"messages":["|Creazione di ICAM12202ACT00000147"],"warnings":null}]');
            }
            when 'uscita_diversa' {
                response.setBody('[{"error":false,"created":true,"errors":null,"messages":["|Creazione di UDI22ICAM100054"],"warnings":null}]');
            }
            when 'contatto' {
                response.setBody('[{"error":false,"created":true,"errors":null,"messages":["|Creazione di 000000000005938"],"warnings":null}]');
            }
            when 'prospect' {
                response.setBody('[{"error":false,"created":true,"errors":null,"messages":["|Creazione di 004969"],"warnings":null}]');
            }
            when 'cliente' {
                response.setBody('[{"error":false,"created":true,"errors":null,"messages":["|Creazione di 004969"],"warnings":null}]');
            }
            when 'trattativa' {
                response.setBody('[{"error":false,"created":true,"errors":null,"messages":["Progetto 16860 creato","|Creazione di 16860\\\\A04"],"warnings":null}]');
            }
            when 'richieste_servizio' {
                response.setBody('[{"error":false,"created":true,"errors":[],"messages":["Questo cliente non ha sottoscritto alcun contratto.","|Creazione di ICAM12202SRE00000050"],"warnings":null}]');
            }
            when 'unhandled'{
                response.setBody('[{"error":true,"created":false,"errors":["test1","test2","test3"],"messages":null,"warnings":null}]');
            }
            when 'locked'{
                response.setBody('[{"error":true,"created":false,"errors":["test1","test2 Scheda in corso di modifica test2","test3","test4"],"messages":null,"warnings":null}]');
            }
            when else {
                response.setBody('[{"error":false,"created":true,"errors":[],"messages":null,"warnings":null}]');
            }
        }
         
        return response; 
    }

}