@isTest
public without sharing class SDG_ReST_SyncLog_Test {

	@testSetup static void setupData() {
        insert new sdg_rest_settings__c(BASEURL__c = 'https://icamtest/', BEARER_TOKEN__c = 'test');
    }

    @isTest static void testUnhautorizedCreateLog(){
        
        String jsonTest =		
		'{'+
		'    "env": "Developer_local",'+
		'    "job": "Clienti",'+
		'    "tasks": ['+
		'        {'+
		'            "obj": "Terzi",'+
		'            "insert": 3,'+
		'            "reject": 1'+
		'        },'+
		'        {'+
		'            "obj": "Clienti",'+
		'            "insert": 3,'+
		'            "reject": 0'+
		'        },'+
		'        {'+
		'            "obj": "Contatti",'+
		'            "insert": 7,'+
		'            "reject": 0'+
		'        },'+
		'        {'+
		'            "obj": "Location",'+
		'            "insert": 2,'+
		'            "reject": 0'+
		'        }'+
		'    ]'+
		'}';
        RestResponse res = new RestResponse();
        RestContext.request = SDG_ReST_SyncLog_Test.buildRequest('', jsonTest);
        RestContext.response = res;
        
        Test.startTest();
        SDG_ReST_SyncLog.createLog();
        Test.stopTest();

        SDG_ReST_SyncLogResponse result = SDG_ReST_SyncLogResponse.parse(res.responseBody.toString());
        System.assertEquals('ERROR', result.status);
        System.assertEquals('UnAuthorized', result.statusMessage);
        System.assertEquals(401, res.statusCode);
    } 

    @isTest static void testCreateLog(){
        
        String jsonTest =		
		'{'+
		'    "env": "Developer_local",'+
		'    "job": "Clienti",'+
		'    "tasks": ['+
		'        {'+
		'            "obj": "Terzi",'+
		'            "insert": 3,'+
		'            "reject": 1'+
		'        },'+
		'        {'+
		'            "obj": "Clienti",'+
		'            "insert": 3,'+
		'            "reject": 0'+
		'        },'+
		'        {'+
		'            "obj": "Contatti",'+
		'            "insert": 7,'+
		'            "reject": 0'+
		'        },'+
		'        {'+
		'            "obj": "Location",'+
		'            "insert": 2,'+
		'            "reject": 0'+
		'        }'+
		'    ]'+
		'}';
        RestResponse res = new RestResponse();
        RestContext.request = SDG_ReST_SyncLog_Test.buildRequest(SDG_ReST_Utils.BEARER_TOKEN, jsonTest);
        RestContext.response = res;
        
        Test.startTest();
        SDG_ReST_SyncLog.createLog();
        Test.stopTest();

        SDG_ReST_SyncLogResponse result = SDG_ReST_SyncLogResponse.parse(res.responseBody.toString());
        System.assertEquals('OK', result.status);
        System.assertEquals('Log inseriti.', result.statusMessage);
        System.assertNotEquals(401, res.statusCode);
    }

	@isTest static void testCreateLogWithDelete(){

		SyncLog__c log = new SyncLog__c(Name = 'test', ObjectName__c = 'Preventivo', Inserted__c = 3, Rejected__c = 4);
		insert log;
		Test.setCreatedDate(log.id, Datetime.now().addDays(-30));
        
        String jsonTest =		
		'{'+
		'    "env": "Developer_local",'+
		'    "job": "Clienti",'+
		'    "tasks": ['+
		'        {'+
		'            "obj": "Terzi",'+
		'            "insert": 3,'+
		'            "reject": 1'+
		'        },'+
		'        {'+
		'            "obj": "Clienti",'+
		'            "insert": 3,'+
		'            "reject": 0'+
		'        },'+
		'        {'+
		'            "obj": "Contatti",'+
		'            "insert": 7,'+
		'            "reject": 0'+
		'        },'+
		'        {'+
		'            "obj": "Location",'+
		'            "insert": 2,'+
		'            "reject": 0'+
		'        }'+
		'    ]'+
		'}';
        RestResponse res = new RestResponse();
        RestContext.request = SDG_ReST_SyncLog_Test.buildRequest(SDG_ReST_Utils.BEARER_TOKEN, jsonTest);
        RestContext.response = res;
        
        Test.startTest();
        SDG_ReST_SyncLog.createLog();
        Test.stopTest();

        SDG_ReST_SyncLogResponse result = SDG_ReST_SyncLogResponse.parse(res.responseBody.toString());
        System.assertEquals('OK', result.status);
        System.assertEquals('Log inseriti ed eliminati i log più vecchi di ' + SDG_ReST_Utils.SYNCLOG_DAYS + ' giorni (1).', result.statusMessage);
        System.assertNotEquals(401, res.statusCode);
    }

    @isTest static void testCreateLogUnhandled(){
        
        String jsonTest ='';
        RestResponse res = new RestResponse();
        RestContext.request = SDG_ReST_SyncLog_Test.buildRequest(SDG_ReST_Utils.BEARER_TOKEN, jsonTest);
        RestContext.response = res;
        
        Test.startTest();
        SDG_ReST_SyncLog.createLog();
        Test.stopTest();

        SDG_ReST_SyncLogResponse result = SDG_ReST_SyncLogResponse.parse(res.responseBody.toString());
        System.assertEquals('ERROR', result.status);
        System.assertEquals(true, result.statusMessage.startsWithIgnoreCase('ERROR:'));
        System.assertEquals(500, res.statusCode);
    } 

    private static RestRequest buildRequest(String apiToken, String jsonTest){
        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SyncLog/v1/createLog';
        req.httpMethod = 'GET';
        req.addHeader('X-API-Token', apiToken);
        req.requestBody = Blob.valueOf(jsonTest);
        return req;
    }
}