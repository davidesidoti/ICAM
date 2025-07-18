@isTest
public without sharing class SDG_ReST_OnDemandSync_Test {

    @testSetup static void setupData() {
        insert new sdg_rest_settings__c(BASEURL__c = 'https://icam_sideagroup.com/webhook/', BEARER_TOKEN__c = 'test');
        insert new MapOpportunity__c(Stage__c = 'New', SageX3__c = 'BIS');
        insert new MapOpportunity__c(Stage__c = 'Closed Lost', SageX3__c = 'FPE');
        insert new List<EmailCustom__c>{
            new EmailCustom__c(Name = 'TEST1', Email__c = 'test1@example.com', Type__c = 'toaddress', Active__c = true),
            new EmailCustom__c(Name = 'TEST2', Email__c = 'test2@example.com', Type__c = 'ccaddress', Active__c = true),
            new EmailCustom__c(Name = 'TEST3', Email__c = 'test3@example.com', Type__c = 'bccaddress', Active__c = true)
        };
    }

    static Opportunity getOpp(Id oppId){
        return [
                SELECT Id, Name, AccountId, ContactId__c, ProjectProbability__c, Probability, Account_ExternalId__c, Contact_ExternalId__c, Type,
                Amount, Average__c, isTotalized__c, CreatedDate, ExpectedCloseDate__c, Description, Currency__c, OfferType__c, RecordTypeId, Origin__c,
                ExternalId__c, CIG__c, CUP__c, Facility__c, PublicOrder__c, StageName, PendingReason__c, LossReason__c, CancellationReason__c,
                RUPName__c, Category__c, Agent_ExternalId__c, Owner_ExternalId__c, Location_ExternalId__c, RecordType.DeveloperName, LastStageChangeDate, StartDate__c 
                FROM Opportunity WHERE Id =: oppId
            ];
    }

    @isTest public static void testInsertMultipleAddress() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            List<Schema.Location> loc = new List<Schema.Location>{TestDataFactory.getLocation(acc.Id, 1, false), TestDataFactory.getLocation(acc.Id, 1, false)};

            Test.startTest(); 
            try{
                insert loc;
            } 
            catch(Exception e){
                System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
                System.Assert(e.getMessage().contains('Il Codice Indirizzo'));
                System.Assert(e.getMessage().contains('è già presente per il'));
            }  
            Test.stopTest();
        } 
    }

    @isTest public static void testInsertMultipleAddressWithDefaultAddress() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            List<Schema.Location> locList = new List<Schema.Location>();
            Schema.Location loc1 = TestDataFactory.getLocation(acc.Id, 1, false);
            loc1.DefaultAddress__c = true;
            locList.add(loc1);
            Schema.Location loc2 = TestDataFactory.getLocation(acc.Id, 2, false);
            loc2.DefaultAddress__c = true;
            locList.add(loc2);

            Test.startTest(); 
            try{
                insert locList;
            } 
            catch(Exception e){
                System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
                System.Assert(e.getMessage().contains('più di un indirizzo come "Indirizzo di default" per lo stesso'));
                System.Assert(e.getMessage().contains('Errore, non è possibile'));
            }  
            Test.stopTest();
        } 
    }

    @isTest public static void testChangeAddressDefaultAddress() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Schema.Location loc1 = TestDataFactory.getLocation(acc.Id, 1, false);
            loc1.DefaultAddress__c = true;
            insert loc1;
            Schema.Location loc2 = TestDataFactory.getLocation(acc.Id, 2, false);
            loc2.DefaultAddress__c = true;

            Test.startTest(); 
            insert loc2; 
            Test.stopTest();

            List<Schema.Location> locAfter = [SELECT Id, DefaultAddress__c FROM Location WHERE DefaultAddress__c = true AND CreatedDate = TODAY];
            if(!locAfter.isEmpty()){
                System.assertEquals(1, locAfter.size());
            }   
        } 
    }

    @isTest public static void testInsertLocationADefaultAddressFalse() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);

            
            Test.startTest(); 
            insert loc;
            Test.stopTest();

            List<Schema.Location> locAfter = [SELECT Id, ExternalId__c, DefaultAddress__c FROM Location WHERE CreatedDate = TODAY];
            if(!locAfter.isEmpty()){
                for(Schema.Location lc : locAfter){
                    System.assertEquals(true, lc.DefaultAddress__c);
                }   
            }
        } 
    }

    @isTest public static void testInsertLocationDefaultAddressFalseExistingDefaulAddressTrue() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Account acc2 = TestDataFactory.getAccount('prospect');
            insert acc2;
            Schema.Location loc1 = TestDataFactory.getLocation(acc.Id, 1, false);
            loc1.DefaultAddress__c = true;
            insert loc1;
            Schema.Location loc2 = TestDataFactory.getLocation(acc.Id, 2, false);
            loc2.DefaultAddress__c = true;
            Schema.Location loc3 = TestDataFactory.getLocation(acc2.Id, 2, false);
            loc3.DefaultAddress__c = false;

            Test.startTest(); 
            insert new List<Schema.Location> {loc2, loc3}; 
            Test.stopTest();

            List<Schema.Location> locAfter = [SELECT Id, DefaultAddress__c FROM Location WHERE DefaultAddress__c = true AND CreatedDate = TODAY];
            if(!locAfter.isEmpty()){
                System.assertEquals(2, locAfter.size());
            }  
        } 
    }


    @isTest public static void testInsertExistingAddressCode() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Schema.Location lc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert lc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            
            Test.startTest(); 
            try{
                insert loc;
            } 
            catch(Exception e){
                System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
                System.Assert(e.getMessage().contains('Il Codice Indirizzo'));
                System.Assert(e.getMessage().contains('è già presente per il'));
            }  
            Test.stopTest();
        } 
    }

    
    @isTest public static void testInsertExistingVATNumberProspect(){
        
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account terzo = TestDataFactory.getAccount('terzo');
            terzo.ExternalId__c = 'BPR_004234';
            insert terzo;
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ParentId = terzo.Id;
            acc.Prospect__c = true;
            insert acc;
            Account acc2 = TestDataFactory.getAccount('prospect');
            acc2.Prospect__c = true;
            Test.startTest();   
            try{
                insert acc2;
            } 
            catch(Exception e){
                System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
                System.Assert(e.getMessage().contains('Impossibile creare il '));
                System.Assert(e.getMessage().contains('", esiste già il '));
                System.Assert(e.getMessage().contains(' esistente durante la conversione del Lead.'));
            }  
            Test.stopTest();
        } 
    }


    @isTest public static void testUpdateMultipleAddress() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            List<Schema.Location> loc = new List<Schema.Location>{
                TestDataFactory.getLocation(acc.Id, 1, false), 
                TestDataFactory.getLocation(acc.Id, 2, false),
                TestDataFactory.getLocation(acc.Id, 3, false)
            };
            insert loc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('prospect', 200));

            Test.startTest(); 
            try{
                loc[1].Progressive_Sage__c = 'SL1';
                loc[2].Progressive_Sage__c = 'SL1';
                update loc;
            } 
            catch(Exception e){
                System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
                System.Assert(e.getMessage().contains('Il Codice Indirizzo'));
                System.Assert(e.getMessage().contains('è già presente per il'));
            }  
            Test.stopTest();
        } 
    }

    @isTest public static void testInsertOnDemandRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            insert opp; 
            opp = getOpp(opp.Id);

            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Contatto(new List<Contact>{cnt}, opp, true));
            System.enqueueJob(new SDG_ReST_Prospect(new List<Account>{acc}, opp, true));           
            System.enqueueJob(new SDG_ReST_Trattativa(new List<Opportunity>{opp}));
            Test.stopTest();
     
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                }
            }          
        } 
    }
 
    @isTest public static void testInsertOnDemandRequestNoContact() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, null, false);
            insert opp; 
            opp = getOpp(opp.Id);

            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            List<Opportunity> opps = new List<Opportunity>{opp};
            Formula.recalculateFormulas(opps);
            System.enqueueJob(new SDG_ReST_Trattativa(opps));
            Test.stopTest();

            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                }
            }           
        } 
    }

    @isTest public static void testInsertOnDemandWithExternalIdRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            opp.ExternalId__c = '34234';
            insert opp; 
            opp = getOpp(opp.Id);

            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id);   
            Test.stopTest();        
            
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                }
            }
        } 
    }

    @isTest public static void testInsertOnDemandWithExternalIdRequestReplaceContactExternalId() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'null_000000000034234';
            insert cnt;

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            update acc;   
            Test.stopTest();        
            
            Contact cntAfter = [SELECT Id, ExternalId__c FROM Contact LIMIT 1];
            System.assertNotEquals('null_000000000034234', cntAfter.ExternalId__c);
        } 
    }

    @isTest public static void testInsertOnDemandOnlyProspectWithExternalIdRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            insert opp; 
            opp = getOpp(opp.Id);

            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            List<Opportunity> opps = new List<Opportunity>{opp};
            Formula.recalculateFormulas(opps);
            System.enqueueJob(new SDG_ReST_Trattativa(opps));  
            Test.stopTest();       

            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                }
            }   
        } 
    }

    @isTest public static void testInsertOnDemandOnlyProspectWithExternalIdNoContactRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, null, false);
            insert opp; 
            opp = getOpp(opp.Id);
            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id);   
            Test.stopTest();   
               
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c); 
                }   
            }           
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                }
            }
        } 
    }

    @isTest public static void testInsertOnDemandProspectContactWithExternalIdRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            insert opp; 
            opp = getOpp(opp.Id);

            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            Test.stopTest();     
            
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                }
            }
        } 
    }

    @isTest public static void testInsertOnDemandWithExistingProspectRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account terzo = TestDataFactory.getAccount('terzo');
            terzo.ExternalId__c = 'BPR_004234';
            insert terzo;
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, null, false);
            insert opp; 
            opp = getOpp(opp.Id);
            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            List<Opportunity> opps = new List<Opportunity>{opp};
            Formula.recalculateFormulas(opps);
            System.enqueueJob(new SDG_ReST_Trattativa(opps));    
            Test.stopTest();
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                }
            }
            
        } 
    }
    
    @isTest public static void testInsertOnDemandWithExistingProspectLinkedRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account terzo = TestDataFactory.getAccount('terzo');
            terzo.ExternalId__c = 'BPR_004234';
            insert terzo;
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ParentId = terzo.Id;
            insert acc;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, null, false);
            insert opp; 
            opp = getOpp(opp.Id);
            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            List<Opportunity> opps = new List<Opportunity>{opp};
            Formula.recalculateFormulas(opps);
            System.enqueueJob(new SDG_ReST_Trattativa(opps));    
            Test.stopTest();
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Account_ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                }
            }
            
        } 
    }

    @isTest public static void testInsertOnDemandWithExistingProspectAndContact() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account terzo = TestDataFactory.getAccount('terzo');
            terzo.ExternalId__c = 'BPR_004234';
            insert terzo;
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, false);
            insert opp; 
            opp = getOpp(opp.Id);
            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            List<Opportunity> opps = new List<Opportunity>{opp};
            Formula.recalculateFormulas(opps);
            System.enqueueJob(new SDG_ReST_Trattativa(opps));    
            Test.stopTest();
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                    //System.assertNotEquals(null, op.Account_ExternalId__c);
                }
            }
            
        } 
    }

    @isTest public static void testInsertOnDemandWithExistingProspectLinkedRequestAndContact() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account terzo = TestDataFactory.getAccount('terzo');
            terzo.ExternalId__c = 'BPR_004234';
            insert terzo;
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ParentId = terzo.Id;
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, false);
            insert opp; 
            opp = getOpp(opp.Id);
            List<Opportunity> oppBefore = [SELECT Id, ExternalId__c, Contact_ExternalId__c, Account_ExternalId__c  FROM Opportunity WHERE CreatedDate = TODAY];

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'contatti' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'contatti');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'prospect' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'prospect');
            multimock.setStaticResource(SDG_Rest_Utils.ICAM_BASEURL + 'trattative' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 'trattative');
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest(); 
            SDG_ReST_OnDemandSync_Handler.startSync(opp.Id); 
            List<Opportunity> opps = new List<Opportunity>{opp};
            Formula.recalculateFormulas(opps);
            System.enqueueJob(new SDG_ReST_Trattativa(opps));    
            Test.stopTest();
            List<Opportunity> oppOnDemand = [SELECT Id, ExternalId__c, Account_ExternalId__c, Contact_ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            if(!oppBefore.isEmpty()){
                for(Opportunity op : oppBefore){
                    System.assertEquals(null, op.ExternalId__c);
                    System.assertEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c); 
                }   
            }
            if(!oppOnDemand.isEmpty()){
                for(Opportunity op : oppOnDemand){
                    System.assertNotEquals(null, op.ExternalId__c);
                    System.assertNotEquals(null, op.Contact_ExternalId__c);
                    System.assertEquals(null, op.Account_ExternalId__c);
                }
            }
            
        } 
    }

    @isTest public static void testInsertTrattativaService() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, false);
            opp.RecordTypeId = SDG_ReST_Utils.getRecordType('Service', 'Opportunity');
            opp.StageName = 'New';
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('trattativa', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Trattativa(new List<Opportunity>{opp}));
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c, StageName FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertNotEquals(null, o.ExternalId__c);
                System.assertEquals('Inviata a Sage X3', o.StageName);
            }
  
        } 
    }

    @isTest public static void testUpdateProspectLocation() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('prospect', 200));

            Test.startTest();
            loc.ExternalId__c = 'PPT_004234_SL01'; 
            loc.Phone__c = '1111111111';
            update loc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateProspectOk() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('prospect', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateProspectLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateProspectError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateProspectUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateClienteLocation() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            acc.ExternalId__c = 'BPC_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'BPC_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('cliente', 200));

            Test.startTest(); 
            loc.Phone__c = '1111111111';
            update loc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateClienteOk() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            acc.ExternalId__c = 'BPC_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'BPC_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('cliente', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateClienteLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            acc.ExternalId__c = 'BPC_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'BPC_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateClienteError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            acc.ExternalId__c = 'BPC_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'BPC_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateClienteUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            acc.ExternalId__c = 'BPC_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'BPC_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateClienteWithNewLocation() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            acc.ExternalId__c = 'BPC_004234';
            insert acc;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            Schema.Location loc2 = TestDataFactory.getLocation(acc.Id, 2, false);
            loc2.DefaultAddress__c = true;
            insert loc2;
            Schema.Location loc3 = TestDataFactory.getLocation(acc.Id, 3, true);
            insert loc3;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'BPC_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('cliente', 200));

            Test.startTest(); 
            acc.Description = 'test2';
            update acc;  
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertNotEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateContactOk() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('contatto', 200));

            Test.startTest(); 
            cnt.Email = 'test2@email.com';
            update cnt;  
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertNotEquals(null, c.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateContactLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));

            Test.startTest(); 
            cnt.Email = 'test2@email.com';
            update cnt;  
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertNotEquals(null, c.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateContactError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));

            Test.startTest(); 
            cnt.Email = 'test2@email.com';
            update cnt;  
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertNotEquals(null, c.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateContactUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));

            Test.startTest(); 
            cnt.Email = 'test2@email.com';
            update cnt;  
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertNotEquals(null, c.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateTrattativaCompetitor() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            opp.ExternalId__c = '34234';
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('trattativa', 200));

            Test.startTest(); 
            opp.LossReason__c = 'Azienda concorrente';
            opp.Competitor__c = '001';
            opp.StageName = 'Closed Lost';
            opp.CheckForm__c = true;
            update opp;  
            Test.stopTest();

            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertNotEquals(null, o.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateTrattativaOk() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            opp.ExternalId__c = '34234';
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('trattativa', 200));

            Test.startTest(); 
            opp.Description = 'test2';
            update opp;  
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertNotEquals(null, o.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateTrattativaLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            opp.ExternalId__c = '34234';
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));

            Test.startTest(); 
            opp.Description = 'test2';
            update opp;  
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertNotEquals(null, o.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateTrattativaError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            opp.ExternalId__c = '34234';
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));

            Test.startTest(); 
            opp.Description = 'test2';
            update opp;  
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertNotEquals(null, o.ExternalId__c);
            }
        } 
    }

    @isTest public static void testUpdateTrattativaUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, true);
            opp.ExternalId__c = '34234';
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));

            Test.startTest(); 
            opp.Description = 'test2';
            update opp;  
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertNotEquals(null, o.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertProspectLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Prospect(new List<Account>{acc}, null, false));
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertEquals(null, a.ExternalId__c);
            }
  
        } 
    }

    @isTest public static void testInsertProspectError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Prospect(new List<Account>{acc}, null, false));
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertProspectUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            insert acc;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Prospect(new List<Account>{acc}, null, false));
            Test.stopTest();
            List<Account> AccList = [SELECT Id, ExternalId__c FROM Account WHERE CreatedDate = TODAY];
            System.assertEquals(null, acc.ExternalId__c);
            for(Account a : AccList){
                System.assertEquals(null, a.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertContactLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Contatto(new List<Contact>{cnt}, null, false));
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertEquals(null, c.ExternalId__c);
            }
  
        } 
    }

    @isTest public static void testInsertContactError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Contatto(new List<Contact>{cnt}, null, false));
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertEquals(null, c.ExternalId__c);
            }  
        } 
    }

    @isTest public static void testInsertContactUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Contatto(new List<Contact>{cnt}, null, false));
            Test.stopTest();
            List<Contact> CntList = [SELECT Id, ExternalId__c FROM Contact WHERE CreatedDate = TODAY];
            System.assertEquals(null, cnt.ExternalId__c);
            for(Contact c : CntList){
                System.assertEquals(null, c.ExternalId__c);
            }  
        } 
    }

    @isTest public static void testInsertTrattativaLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, false);
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Trattativa(new List<Opportunity>{opp}));
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertEquals(null, o.ExternalId__c);
            }
  
        } 
    }

    @isTest public static void testInsertTrattativaError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, false);
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Trattativa(new List<Opportunity>{opp}));
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertEquals(null, o.ExternalId__c);
            }
  
        } 
    }

    @isTest public static void testInsertTrattativaUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('prospect');
            acc.ExternalId__c = 'PPT_004234';
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            cnt.ExternalId__c = 'PPT_004234_000000000034234';
            insert cnt;
            Opportunity opp = TestDataFactory.getTrattativa(acc.Id, cnt.Id, false);
            insert opp; 
            opp = getOpp(opp.Id);

            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));
            Test.startTest(); 
            System.enqueueJob(new SDG_ReST_Trattativa(new List<Opportunity>{opp}));
            Test.stopTest();
            List<Opportunity> OppList = [SELECT Id, ExternalId__c FROM Opportunity WHERE CreatedDate = TODAY];
            System.assertEquals(null, opp.ExternalId__c);
            for(Opportunity o : OppList){
                System.assertEquals(null, o.ExternalId__c);
            }
  
        } 
    }

        /* 
        Case c = [SELECT ServReqCustomer__c, AccountId, ContactId, AssetId, ServiceContractId, GroupCustomer__c, BilledCustomer__c, ThirdPayer__c, 
        Subject__c, OriginDocNum__c, Line__c, RequestModel__c, StatisticFamily1__c, StatisticFamily2__c, StatisticFamily3__c, StatisticFamily4__c, 
        StatisticFamily5__c, MachineType__c, ClientFilter__c, Status, ServReqDetail__c, CreatedDate, StatusRequest__c, GlobalCover__c, GravityLevel__c,
        DesiredDueDate__c, Causal__c, Facility__c, TypeOfChange__c, Currency__c, PayTerm__c, VAC_BPartner__c FROM Case WHERE Subject__c = 'Assistenza Tecnica' LIMIT 1];
         
        WorkOrder wo = [SELECT CaseId, AccountId, ContactId, category__c, StartDate, EndDate, FullDay__c, DurationInMinutes, IsResolved__c, 
        IsSubcontracting__c, AmountNegotiated__c, Currency__c, Made__c, OriginDocNum__c, Distance__c, EstimatedTime__c, Street,
        PostalCode, City, Country, State, Phone__c, MobilePhone__c, Email__c, Indications__c 
        FROM WorkOrder WHERE Indications__c = 'indicazioni' LIMIT 1]; 
        */

    @isTest public static void testInsertRichiestaDiServizioOpenRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('richieste_servizio', 200));

            Test.startTest(); 
            insert c;     
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertRichiestaDiServizioOpenRequestLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200));

            Test.startTest(); 
            insert c;     
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertEquals(null, ca.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertRichiestaDiServizioOpenRequestError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));

            Test.startTest(); 
            insert c;     
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertEquals(null, ca.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertRichiestaDiServizioOpenRequestUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));

            Test.startTest(); 
            insert c;     
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertEquals(null, ca.ExternalId__c);
            }
        } 
    }

    @isTest public static void testInsertRichiestaDiServizioChiusaRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('5', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('richieste_servizio', 200));

            Test.startTest(); 
            insert c;     
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }      
    }

    @isTest public static void testInsertRichiestaDiServizioChiusaWithExternalIdRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('5', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'TEST';
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('richieste_servizio', 200));

            Test.startTest(); 
            insert c;     
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }      
    }

    @isTest public static void testUpdateRichiestaDiServizioChiusaRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('5', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('richieste_servizio', 200));

            Test.startTest();
            insert c;
            c.ClientFilter__c = false;
            update c;
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }
    } 

    @isTest public static void testUpdateRichiestaDiServizioChiusaRequestLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('5', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('locked', 200)); 

            Test.startTest();  
            c.ClientFilter__c = false;
            update c;
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }
    } 

    @isTest public static void testUpdateRichiestaDiServizioChiusaRequestUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('5', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 400));

            Test.startTest();
            c.ClientFilter__c = false;
            update c;
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }
    } 

    @isTest public static void testUpdateRichiestaDiServizioChiusaRequestError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('5', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('unhandled', 200));

            Test.startTest();
            c.ClientFilter__c = false;
            update c;
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertNotEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }
    } 

    @isTest public static void testUpdateChiusuraRichiestaDiServizioRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());       
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            Test.setMock(HttpCalloutMock.class, new SDG_ReST_Request_HttpCalloutMock('richieste_servizio', 200));

            Test.startTest();
            insert c;
            c.Status = '5';
            update c;
            Test.stopTest();
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            System.assertEquals(null, c.ExternalId__c);
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
        }
    } 

    @isTest public static void testInsertRichiestaDiServizioAndInterventoRequestLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'locked'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testInsertRichiestaDiServizioAndInterventoRequestError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'unhandled'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testInsertRichiestaDiServizioAndInterventoRequestUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'unhandled'
            );
            multimock.setStatusCode(400);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertEquals(null, ca.ExternalId__c);
            }
            System.assertEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoRequestLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.ExternalId__c = 'ACT2';
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'locked'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertNotEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertNotEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoRequestError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.ExternalId__c = 'ACT2';
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'unhandled'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertNotEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertNotEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoRequestUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.ExternalId__c = 'ACT2';
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'unhandled'
            );
            multimock.setStatusCode(400);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertEquals(null, ca.ExternalId__c);
            }
            System.assertNotEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateInterventoRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            wo.ExternalId__c = 'ICAM12202ACT00000255';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateInterventoRemoteRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.TypeAssistance__c = '1';
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Duration = 33.5;
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateInterventoOnSiteRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.TypeAssistance__c = '2';
            insert wo; 
            
            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Duration = 33.5;
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertEquals(null, rw.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoWithUsciteDiverseRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            Product2 prd = TestDataFactory.getProduct();
            insert prd;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            ProductItem prdItm = TestDataFactory.getProductItem(acc.Id, loc.Id, prd.Id);
            insert prdItm;
            ProductConsumed prdCns = TestDataFactory.getUscitaDiversa(wo.Id, prdItm.Id);
            insert prdCns;

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'uscite-diverse' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'uscita_diversa'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
            System.assertEquals(false, prdCns.IsSentToSageX3__c);
            List<ProductConsumed> resPrdCns = [SELECT Id, IsSentToSageX3__c FROM ProductConsumed WHERE CreatedDate = TODAY];
            for(ProductConsumed prdc : resPrdCns){
                System.assertEquals(true, prdc.IsSentToSageX3__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoWithMultipleUsciteDiverseRequest() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            insert wo; 
            Product2 prd = TestDataFactory.getProduct();
            insert prd;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            ProductItem prdItm = TestDataFactory.getProductItem(acc.Id, loc.Id, prd.Id);
            insert prdItm;
            ProductConsumed prdCns1 = TestDataFactory.getUscitaDiversa(wo.Id, prdItm.Id);
            prdCns1.ExternalId__c = 'IGORM2235MRI_1000';
            prdCns1.IsSentToSageX3__c = true;
            insert prdCns1;
            ProductConsumed prdCns2 = TestDataFactory.getUscitaDiversa(wo.Id, prdItm.Id);
            insert prdCns2;

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'uscite-diverse' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'uscita_diversa'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
            System.assertEquals(false, prdCns2.IsSentToSageX3__c);
            List<ProductConsumed> resPrdCns = [SELECT Id, ExternalId__c, IsSentToSageX3__c FROM ProductConsumed WHERE CreatedDate = TODAY];
            for(ProductConsumed prdc : resPrdCns){
                System.assertEquals(true, prdc.IsSentToSageX3__c);
                System.assertNotEquals(null, prdc.ExternalId__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoWithUsciteDiverseRequestLocked() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.ExternalId__c = 'ACT1';
            insert wo; 
            Product2 prd = TestDataFactory.getProduct();
            insert prd;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            ProductItem prdItm = TestDataFactory.getProductItem(acc.Id, loc.Id, prd.Id);
            insert prdItm;
            ProductConsumed prdCns = TestDataFactory.getUscitaDiversa(wo.Id, prdItm.Id);
            insert prdCns;

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'uscite-diverse' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'locked'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertNotEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertNotEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
            System.assertEquals(false, prdCns.IsSentToSageX3__c);
            List<ProductConsumed> resPrdCns = [SELECT Id, IsSentToSageX3__c FROM ProductConsumed WHERE CreatedDate = TODAY];
            for(ProductConsumed prdc : resPrdCns){
                System.assertEquals(false, prdc.IsSentToSageX3__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoWithUsciteDiverseRequestUnhandled() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.ExternalId__c = 'ACT1';
            insert wo; 
            Product2 prd = TestDataFactory.getProduct();
            insert prd;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            ProductItem prdItm = TestDataFactory.getProductItem(acc.Id, loc.Id, prd.Id);
            insert prdItm;
            ProductConsumed prdCns = TestDataFactory.getUscitaDiversa(wo.Id, prdItm.Id);
            insert prdCns;

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'uscite-diverse' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'unhandled'
            );
            multimock.setStatusCode(200);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertNotEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertNotEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
            System.assertEquals(false, prdCns.IsSentToSageX3__c);
            List<ProductConsumed> resPrdCns = [SELECT Id, IsSentToSageX3__c FROM ProductConsumed WHERE CreatedDate = TODAY];
            for(ProductConsumed prdc : resPrdCns){
                System.assertEquals(false, prdc.IsSentToSageX3__c);
            }
        }       
    }

    @isTest public static void testUpdateRichiestaDiServizioAndInterventoWithUsciteDiverseRequestError() {
        System.runAs(TestDataFactory.getUser('Manutentore on-site')) {
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId());
            Account acc = TestDataFactory.getAccount('cliente');
            insert acc;
            Contact cnt = TestDataFactory.getContact(acc.Id);
            insert cnt;
            Asset asst = TestDataFactory.getAsset(acc.Id, cnt.Id);
            insert asst;
            ServiceContract srvCnt = TestDataFactory.getContratto(acc.Id, cnt.Id);
            insert srvCnt;
            Case c = TestDataFactory.getRichiestaDiServizio('1', acc.Id, cnt.Id, asst.Id, srvCnt.Id);
            c.ExternalId__c = 'CNTSRV1';
            insert c;
            WorkOrder wo = TestDataFactory.getIntervento('New', c.Id, acc.Id, cnt.Id);
            wo.ExternalId__c = 'ACT1';
            insert wo; 
            Product2 prd = TestDataFactory.getProduct();
            insert prd;
            Schema.Location loc = TestDataFactory.getLocation(acc.Id, 1, false);
            insert loc;
            ProductItem prdItm = TestDataFactory.getProductItem(acc.Id, loc.Id, prd.Id);
            insert prdItm;
            ProductConsumed prdCns = TestDataFactory.getUscitaDiversa(wo.Id, prdItm.Id);
            insert prdCns;

            MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'richieste-servizio' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'richiesta_di_servizio'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'intervento' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'intervento'
            );
            multimock.setStaticResource(
                SDG_Rest_Utils.ICAM_BASEURL + 'uscite-diverse' + ((SDG_Rest_Utils.IsSandbox()) ? '?env=test' : ''), 
                'unhandled'
            );
            multimock.setStatusCode(400);
            multimock.setHeader('Content-Type', 'application/json');

            Test.setMock(HttpCalloutMock.class, multimock);

            Test.startTest();
            wo.Status = 'Completed';
            update wo;
            Test.stopTest(); 

            System.assertNotEquals(null, c.ExternalId__c);
            List<Case> resCase = [SELECT Id, ExternalId__c FROM Case WHERE CreatedDate = TODAY];
            for(Case ca : resCase){
                System.assertNotEquals(null, ca.ExternalId__c);
            }
            System.assertNotEquals(null, wo.ExternalId__c);
            List<WorkOrder> resWork = [SELECT Id, ExternalId__c FROM WorkOrder WHERE CreatedDate = TODAY];
            for(WorkOrder rw : resWork){
                System.assertNotEquals(null, rw.ExternalId__c);
            }
            System.assertEquals(false, prdCns.IsSentToSageX3__c);
            List<ProductConsumed> resPrdCns = [SELECT Id, IsSentToSageX3__c FROM ProductConsumed WHERE CreatedDate = TODAY];
            for(ProductConsumed prdc : resPrdCns){
                System.assertEquals(false, prdc.IsSentToSageX3__c);
            }
        }       
    }
}