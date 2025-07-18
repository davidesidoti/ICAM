@isTest 
public class SDG_ReST_RunSyncComponentTest {

   @isTest public static void testStartSync200(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SDG_ReST_RunSyncComponentMock(200));
        Integer risposta = SDG_ReST_RunSyncComponent.startSync();
        Test.stopTest();
        System.assertEquals(200,risposta);
    }
    @isTest public static void testStartSync503(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SDG_ReST_RunSyncComponentMock(503));
        Integer risposta = SDG_ReST_RunSyncComponent.startSync();
        Test.stopTest();
        System.assertEquals(503,risposta);
    }
    @isTest public static void testStartSync409(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SDG_ReST_RunSyncComponentMock(409));
        Integer risposta = SDG_ReST_RunSyncComponent.startSync();
        Test.stopTest();
        System.assertEquals(409,risposta);
    }
    @isTest public static void testStartSyncOther(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SDG_ReST_RunSyncComponentMock(500));
        Integer risposta = SDG_ReST_RunSyncComponent.startSync();
        Test.stopTest();
        System.assertEquals(500,risposta);
    }
}

//sdg rest request make icam request