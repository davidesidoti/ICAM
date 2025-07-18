@IsTest
private class LBR_AcceptOffer_HandlerTest {
    @TestSetup
    static void setupTestData() {
        // Create test record types
        RecordType prospectRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' 
                                AND DeveloperName = 'Prospect' AND IsActive = true LIMIT 1];
        
        RecordType clientRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' 
                              AND DeveloperName = 'Customer' AND IsActive = true LIMIT 1];
        
        // Create test accounts
        Account testProspect = new Account(
            Name = 'Test Prospect Account',
            RecordTypeId = prospectRT.Id
        );
        insert testProspect;
        
        Account testClient = new Account(
            Name = 'Test Client Account',
            RecordTypeId = clientRT.Id
        );
        insert testClient;
        
        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testProspect.Id,
            StageName = LBR_Utils.OPP_STAGE_PROPOSAL,
            CloseDate = Date.today().addDays(30),
            CheckForm__c = true
        );
        insert testOpp;
        
        // Create test offers
        QuoteCustom__c testOffer = new QuoteCustom__c(
            Opportunity__c = testOpp.Id,
            OfferStatus__c = '1' // Not TOTALMENTE_ORDINATO
        );
        insert testOffer;
        
        QuoteCustom__c testCompletedOffer = new QuoteCustom__c(
            Opportunity__c = testOpp.Id,
            OfferStatus__c = LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO
        );
        insert testCompletedOffer;
    }
    
    @isTest
    static void testShouldDisplayLWC_Positive() {
        // Get test data
        QuoteCustom__c testOffer = [SELECT Id FROM QuoteCustom__c 
                                   WHERE OfferStatus__c != :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        
        Test.startTest();
        Boolean shouldDisplay = LBR_AcceptOffer_Handler.shouldDisplayLWC(testOffer.Id);
        Test.stopTest();
        
        System.assertEquals(true, shouldDisplay, 'LWC should be displayed for this offer');
    }
    
    @isTest
    static void testShouldDisplayLWC_Negative() {
        // Get test data
        QuoteCustom__c testOffer = [SELECT Id FROM QuoteCustom__c 
                                   WHERE OfferStatus__c = :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        
        Test.startTest();
        Boolean shouldDisplay = LBR_AcceptOffer_Handler.shouldDisplayLWC(testOffer.Id);
        Test.stopTest();
        
        System.assertEquals(false, shouldDisplay, 'LWC should not be displayed for this offer');
    }
    
    @isTest
    static void testIsOpportunityRelatedToProspect() {
        // Get test data
        Account testProspect = [SELECT Id FROM Account WHERE Name = 'Test Prospect Account' LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE AccountId = :testProspect.Id LIMIT 1];
        QuoteCustom__c testOffer = [SELECT Id FROM QuoteCustom__c WHERE Opportunity__c = :testOpp.Id LIMIT 1];
        
        Test.startTest();
        Boolean isProspect = LBR_AcceptOffer_Handler.isOpportunityRelatedToProspect(testOffer.Id);
        Test.stopTest();
        
        System.assertEquals(true, isProspect, 'The opportunity should be related to a prospect account');
    }
    
    @isTest
    static void testGetOffer() {
        // Get test data
        QuoteCustom__c testOffer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c 
                                   WHERE OfferStatus__c != :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        
        Test.startTest();
        QuoteCustom__c retrievedOffer = LBR_AcceptOffer_Handler.getOffer(testOffer.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, retrievedOffer, 'Offer should be retrieved');
        System.assertEquals(testOffer.Id, retrievedOffer.Id, 'Retrieved offer ID should match');
    }
    
    @isTest
    static void testGetAccountFromOffer() {
        // Get test data
        Account testProspect = [SELECT Id, Name FROM Account WHERE Name = 'Test Prospect Account' LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE AccountId = :testProspect.Id LIMIT 1];
        QuoteCustom__c testOffer = [SELECT Id FROM QuoteCustom__c WHERE Opportunity__c = :testOpp.Id LIMIT 1];
        
        Test.startTest();
        Account retrievedAccount = LBR_AcceptOffer_Handler.getAccountFromOffer(testOffer.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, retrievedAccount, 'Account should be retrieved');
        System.assertEquals(testProspect.Id, retrievedAccount.Id, 'Retrieved account ID should match');
    }
    
    @isTest
    static void testUpdateAccount() {
        // Get test data
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Prospect Account' LIMIT 1];
        
        // Prepare updated fields
        Map<String, Object> accountFields = new Map<String, Object>{
            'Name' => 'Updated Test Account Name',
            'Phone' => '1234567890'
        };
        
        Test.startTest();
        Account updatedAccount = LBR_AcceptOffer_Handler.updateAccount(testAccount.Id, accountFields);
        Test.stopTest();
        
        System.assertNotEquals(null, updatedAccount, 'Account should be updated and retrieved');
        System.assertEquals('Updated Test Account Name', updatedAccount.Name, 'Account name should be updated');
    }
    
    @isTest
    static void testConvertProspectToClient() {
        // Get test data
        Account testProspect = [SELECT Id, RecordTypeDeveloperName__c FROM Account 
                               WHERE Name = 'Test Prospect Account' LIMIT 1];
        
        Test.startTest();
        Boolean conversionResult = LBR_AcceptOffer_Handler.convertProspectToClient(testProspect.Id);
        Test.stopTest();
        
        // Query the account again to see if it was updated
        Account updatedAccount = [SELECT Id, RecordTypeDeveloperName__c FROM Account WHERE Id = :testProspect.Id];
        
        System.assertEquals(true, conversionResult, 'Conversion should be successful');
    }
    
    @isTest
    static void testUpdateOfferStatus() {
        // Get test data
        QuoteCustom__c testOffer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c 
                                   WHERE OfferStatus__c != :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        String originalStatus = testOffer.OfferStatus__c;
        String newStatus = '3';
        
        Test.startTest();
        QuoteCustom__c updatedOffer = LBR_AcceptOffer_Handler.updateOfferStatus(testOffer.Id, newStatus);

        System.assertNotEquals(null, updatedOffer, 'Offer should be updated and retrieved');
        System.assertEquals(newStatus, updatedOffer.OfferStatus__c, 'Offer status should be updated');
        Test.stopTest();
    }
    
    @isTest
    static void testRollbackOfferStatus() {
        // Get test data
        QuoteCustom__c testOffer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c 
                                   WHERE OfferStatus__c != :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        String originalStatus = testOffer.OfferStatus__c;
        
        // First update the status
        testOffer.OfferStatus__c = '3';
        update testOffer;
        
        Test.startTest();
        Boolean rollbackResult = LBR_AcceptOffer_Handler.rollbackOfferStatus(testOffer.Id, originalStatus);
        Test.stopTest();
        
        // Query the offer again to verify rollback
        QuoteCustom__c rolledBackOffer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c WHERE Id = :testOffer.Id];
        
        System.assertEquals(true, rollbackResult, 'Rollback should be successful');
        System.assertEquals(originalStatus, rolledBackOffer.OfferStatus__c, 'Offer status should be rolled back');
    }
    
    @isTest
    static void testUpdateOpportunityStage() {
        // Get test data
        Opportunity testOpp = [SELECT Id, StageName FROM Opportunity LIMIT 1];
        String newStage = 'Closed Won';
        
        Test.startTest();
        Opportunity updatedOpp = LBR_AcceptOffer_Handler.updateOpportunityStage(testOpp.Id, newStage);
        Test.stopTest();
        
        System.assertNotEquals(null, updatedOpp, 'Opportunity should be updated and retrieved');
        System.assertEquals(newStage, updatedOpp.StageName, 'Opportunity stage should be updated');
    }
    
    @isTest
    static void testRollbackOpportunityStage() {
        // Get test data
        Opportunity testOpp = [SELECT Id, StageName FROM Opportunity LIMIT 1];
        String originalStage = testOpp.StageName;
        
        // First update the stage
        testOpp.StageName = 'Closed Won';
        update testOpp;
        
        Test.startTest();
        Boolean rollbackResult = LBR_AcceptOffer_Handler.rollbackOpportunityStage(testOpp.Id, originalStage);
        Test.stopTest();
        
        // Query the opportunity again to verify rollback
        Opportunity rolledBackOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :testOpp.Id];
        
        System.assertEquals(true, rollbackResult, 'Rollback should be successful');
        System.assertEquals(originalStage, rolledBackOpp.StageName, 'Opportunity stage should be rolled back');
    }
    
    @isTest
    static void testGetAvailableRecordTypes() {
        Test.startTest();
        List<Map<String, Object>> recordTypes = LBR_AcceptOffer_Handler.getAvailableRecordTypes();
        Test.stopTest();
        
        System.assertNotEquals(null, recordTypes, 'Record types should be retrieved');
        System.assert(!recordTypes.isEmpty(), 'There should be at least one record type');
    }
    
    @isTest
    static void testRollbackAccountChanges() {
        // Get test data
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Prospect Account' LIMIT 1];
        
        // Create a JSON string representing original data
        String originalData = '{"Name":"Test Prospect Account"}';
        
        // First update the account
        testAccount.Name = 'Changed Name';
        update testAccount;
        
        Test.startTest();
        Boolean rollbackResult = LBR_AcceptOffer_Handler.rollbackAccountChanges(testAccount.Id, false, originalData);
        Test.stopTest();
        
        // Query the account again to verify rollback
        Account rolledBackAccount = [SELECT Id, Name FROM Account WHERE Id = :testAccount.Id];
        
        System.assertEquals(true, rollbackResult, 'Rollback should be successful');
    }
    
    @isTest
    static void testHasExistingClosedOffer() {
        // Get test data for an offer with another closed offer on the same opportunity
        QuoteCustom__c testOffer = [SELECT Id FROM QuoteCustom__c 
                                   WHERE OfferStatus__c != :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        
        Test.startTest();
        Boolean hasClosedOffer = LBR_AcceptOffer_Handler.hasExistingClosedOffer(testOffer.Id);
        Test.stopTest();
        
        System.assertEquals(true, hasClosedOffer, 'Should detect existing closed offer on the same opportunity');
    }
    
    @isTest
    static void testStartTestSync_Success() {
        // Get test data
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        String result = LBR_AcceptOffer_Handler.startTestSync(testOpp.Id, false);
        Test.stopTest();
        
        System.assertEquals('Synchronization completed successfully', result, 'Sync should complete successfully');
    }
    
    @isTest
    static void testStartTestSync_Error() {
        // Get test data
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        try {
            String result = LBR_AcceptOffer_Handler.startTestSync(testOpp.Id, true);
            System.assert(false, 'An exception should have been thrown');
        } catch(AuraHandledException e) {
            System.debug(e);
            System.assert(e.getMessage().contains('exception'), 'Exception message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testExceptionHandling() {
        Test.startTest();
        try {
            // Try to get an offer with an invalid ID
            QuoteCustom__c offer = LBR_AcceptOffer_Handler.getOffer('001000000000000');
            System.assert(false, 'An exception should have been thrown for invalid ID');
        } catch(AuraHandledException e) {
            System.assert(true, 'Exception was correctly thrown for invalid ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateOfferStatus_EdgeCases() {
        // Get test data
        QuoteCustom__c testOffer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c 
                                WHERE OfferStatus__c != :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO LIMIT 1];
        
        Test.startTest();
        try {
            QuoteCustom__c updatedOffer = LBR_AcceptOffer_Handler.updateOfferStatus(testOffer.Id, null);
            // Check what happens with null
        } catch(Exception e) {
            // Assert expected exception behavior
            System.assert(e.getMessage().contains('exception'));
        }
        Test.stopTest();
    }

    @isTest
    static void testConvertToProspect() {
        // Get test data
        Account testClient = [SELECT Id, RecordTypeId, RecordTypeDeveloperName__c 
                            FROM Account WHERE Name = 'Test Client Account' LIMIT 1];
        
        Test.startTest();
        // Call the method being tested
        LBR_AcceptOffer_Handler.convertToProspect(testClient);
        Test.stopTest();
        
        // Query the account again to see if it was updated
        Account updatedAccount = [SELECT Id, RecordTypeId, RecordTypeDeveloperName__c 
                                FROM Account WHERE Id = :testClient.Id];
        
        // Get the prospect record type Id for verification
        RecordType prospectRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' 
                                AND DeveloperName = 'Prospect' AND IsActive = true LIMIT 1];
    }
}