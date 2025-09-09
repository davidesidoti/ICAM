public without sharing class SDG_ReST_Contatto_Handler extends TR_BaseTriggerHandler {

    private List<Contact> newTagList;
    private List<Contact> oldTagList;
    private Map<ID, Contact> newTagMap;
    private Map<ID, Contact> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
    // Record type ids for Prospect and Client accounts used to filter new contacts
    private Id recTypeProspect;
    private Id recTypeClient;

    public SDG_ReST_Contatto_Handler() {
        oldTagList = (List<Contact>)Trigger.old;
        newTagList = (List<Contact>)Trigger.new;
        newTagMap = (Map<ID, Contact>)Trigger.newMap;
        oldTagMap = (Map<ID, Contact>)Trigger.oldMap;
        // Initialize record type Ids for the Prospect and Client account types
        recTypeProspect = SDG_ReST_Utils.getRecordType('Prospect', 'Account');
        recTypeClient   = SDG_ReST_Utils.getRecordType('Customer', 'Account');
    }

    /**
     * Called after new Contact records are inserted.  New contacts associated
     * with Prospect or Client accounts (and with an Account ExternalId) are
     * queued for synchronisation with Sage X3.  Only executes if the user
     * triggering the insert is not marked as "to avoid" and is not the B2BMA
     * Integration user.
     */
    public override void afterInsert(){
        System.debug('ContactInsertTriggerHandler: afterInsert() for SDG_ReST_Contatto_Handler');
        if(!avoidUserName && UserInfo.getName() != 'B2BMA Integration'){
            List<Contact> cntToRequest = new List<Contact>();
            // Collect account ids from the inserted contacts
            Set<Id> accountIds = new Set<Id>();
            for(Contact cnt : newTagList){
                if(cnt.AccountId != null){
                    accountIds.add(cnt.AccountId);
                }
            }
            System.debug('ContactInsertTriggerHandler: accountIds for SDG_ReST_Contatto_Handler: ' + accountIds);
            // Query accounts to obtain their record types
            Map<Id, Account> accMap = accountIds.isEmpty() ? new Map<Id, Account>() :
                new Map<Id, Account>([SELECT Id, RecordTypeId FROM Account WHERE Id IN :accountIds]);
            System.debug('ContactInsertTriggerHandler: accMap for SDG_ReST_Contatto_Handler: ' + accMap);

            // Filter contacts: they must not yet have an ExternalId, must have an
            // Account_ExternalId__c and their account must be of type Prospect or Client
            for(Contact cnt : newTagList){
                if(cnt.ExternalId__c == null && cnt.AccountId != null && cnt.Account_ExternalId__c != null){
                    Account acc = accMap.get(cnt.AccountId);
                    if(acc != null && (acc.RecordTypeId == recTypeProspect || acc.RecordTypeId == recTypeClient)){
                        cntToRequest.add(cnt);
                    }
                }
            }
            System.debug('ContactInsertTriggerHandler: cntToRequest for SDG_ReST_Contatto_Handler: ' + cntToRequest);
            // Enqueue a queueable job if at least one contact qualifies
            if(!cntToRequest.isEmpty()){
                System.enqueueJob(new SDG_ReST_Contatto(cntToRequest, null, true));
            }
        }
    }

    /**
     * Called after Contact records are updated.  Existing contacts which
     * already have an ExternalId__c will be synchronised with Sage X3.  This
     * retains the original update behaviour.
     */
    public override void afterUpdate(){
        System.debug('ContactInsertTriggerHandler: afterUpdate() for SDG_ReST_Contatto_Handler');
        if(!avoidUserName && UserInfo.getName() != 'B2BMA Integration'){
            List<Contact> cntToRequest = new List<Contact>();
            for(Contact cnt : newTagMap.values()){
                if(cnt.ExternalId__c != null ){
                    cntToRequest.add(cnt);
                }
            }
            System.debug('ContactUpdateTriggerHandler: cntToRequest for SDG_ReST_Contatto_Handler: ' + cntToRequest);
                
            if(cntToRequest.size() > 0){
                ID jobID = System.enqueueJob(new SDG_ReST_Contatto(cntToRequest, null, true));
            }
        }
    }
}