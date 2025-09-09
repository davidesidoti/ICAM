@IsTest
public with sharing class SDG_ReST_Contatto_HandlerTest {

    /**
     * Returns the Id of the Account Record Type identified by developer name
     * or null when that record type is not present in the target org.
     */
    private static Id getRtId(String devName){
        List<RecordType> rts = [
            SELECT Id
            FROM   RecordType
            WHERE  SobjectType = 'Account' AND DeveloperName = :devName
            LIMIT  1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /**
     * Creates two baseline Accounts and related Contacts that will be reused
     * across all test methods.  No Record Type is specified here to avoid
     * cross‑reference errors in orgs where the running profile has no access
     * to Prospect/Client record types.
     */
    @testSetup
    static void setup(){
        Account acc1 = new Account(Name = 'Baseline Prospect Acc');
        Account acc2 = new Account(Name = 'Baseline Client Acc');
        insert new List<Account>{ acc1, acc2 };

        insert new List<Contact>{
            new Contact(LastName = 'Baseline Prospect', AccountId = acc1.Id),
            new Contact(LastName = 'Baseline Client',   AccountId = acc2.Id)
        };
    }

    /* =========================================================
       Helper: create a temporary System Administrator user so
       that we can assign non‑master Record Types without hitting
       INVALID_CROSS_REFERENCE_KEY errors (some packaging orgs
       execute tests with a profile that has limited access).
       ========================================================= */
    private static User makeSysAdminUsr(){
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            Alias               = 'sysadm',
            Email               = 'sysadm+' + String.valueOf(Math.mod(Crypto.getRandomInteger(),1000000)) + '@example.com',
            EmailEncodingKey    = 'UTF-8',
            LastName            = 'SysAdmin',
            LanguageLocaleKey   = 'en_US',
            LocaleSidKey        = 'en_US',
            TimeZoneSidKey      = 'Europe/Rome',
            ProfileId           = sysAdminProfile.Id,
            Username            = 'sysadm.' + String.valueOf(System.currentTimeMillis()) + '@example.com'
        );
        insert u;
        return u;
    }

    /* =========================================================
       Positive test: fully meets the filtering criteria in
       afterInsert → System.enqueueJob should be invoked.
       ========================================================= */
    @IsTest
    static void testAfterInsert_QueueableEnqueued(){
        Id prospectRtId = getRtId('Prospect');
        if(prospectRtId == null){
            System.debug('⚠️  Prospect record type not present in this org – skipping positive afterInsert test to avoid false negative.');
            return;
        }

        // Work as a user that *does* have access to the Prospect RT.
        User runUser = makeSysAdminUsr();
        System.runAs(runUser){
            // Create a Prospect account and populate its ExternalId__c (if such
            // a field exists) so that the formula Contact.Account_ExternalId__c
            // will not be null.
            Account acc = new Account(Name = 'Prospect With Ext', RecordTypeId = prospectRtId);
            try{
                acc.put('ExternalId__c', 'ACC-PROS‑001');
            } catch (Exception ignored){}
            insert acc;

            Contact c = new Contact(LastName = 'Trigger Positive', AccountId = acc.Id);

            Test.startTest();
            insert c;                           // Fires afterInsert handler
            Integer queued = Limits.getQueueableJobs();
            Test.stopTest();

            System.assertEquals(1, queued, 'Exactly one Queueable job should have been enqueued.');
        }
    }

    /* =========================================================
       Positive afterUpdate path – Existing ExternalId__c triggers
       synchronisation.
       ========================================================= */
    @IsTest
    static void testAfterUpdate_EnqueuesQueueable(){
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Baseline Prospect' LIMIT 1];
        c.ExternalId__c = 'EXT‑000001';

        Test.startTest();
        update c;                              // Fires afterUpdate handler
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, queued, 'Queueable job expected for afterUpdate.');
    }

    /* =========================================================
       Negative afterInsert – contact already has ExternalId__c
       so it must be ignored by the handler.
       ========================================================= */
    @IsTest
    static void testAfterInsert_NoQueueWhenExternalIdIsPresent(){
        Account acc = [SELECT Id FROM Account WHERE Name = 'Baseline Prospect Acc' LIMIT 1];
        Contact c = new Contact(LastName = 'Skip Insert', AccountId = acc.Id, ExternalId__c = 'EXT‑PRE');

        Test.startTest();
        insert c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'No queueable expected when ExternalId__c is pre‑populated.');
    }

    /* =========================================================
       Negative afterInsert – missing Account_ExternalId__c (formula)
       therefore the contact should be filtered out.
       ========================================================= */
    @IsTest
    static void testAfterInsert_NoQueueWhenAccountExternalIsNull(){
        Account acc = [SELECT Id FROM Account WHERE Name = 'Baseline Client Acc' LIMIT 1];
        Contact c = new Contact(LastName = 'Safe Insert', AccountId = acc.Id);

        Test.startTest();
        insert c;
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queued, 'No queueable expected because Account_ExternalId__c formula is null.');
    }
}
