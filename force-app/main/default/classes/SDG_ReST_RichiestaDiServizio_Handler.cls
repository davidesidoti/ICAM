public without sharing class SDG_ReST_RichiestaDiServizio_Handler extends TR_BaseTriggerHandler {

    private List<Case> newTagList;
    private List<Case> oldTagList;
    private Map<ID, Case> newTagMap;
    private Map<ID, Case> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
 
    public SDG_ReST_RichiestaDiServizio_Handler() {
        oldTagList = (List<Case>)Trigger.old;
        newTagList = (List<Case>)Trigger.new;
        newTagMap = (Map<ID, Case>)Trigger.newMap;
        oldTagMap = (Map<ID, Case>)Trigger.oldMap;
    } 

    public override void afterInsert(){
        checkCaseStatus();
    } 
    
    public override void afterUpdate(){
        checkCaseStatus();
    } 

    private void checkCaseStatus(){
        List<String> caseStatus = new List<String>();
        Map<ID, Case> caseMap = new Map<ID, Case>();
        
        if(Trigger.isUpdate){
            for(CaseStatus cs: [Select ApiName From CaseStatus Where IsClosed = true]){
                caseStatus.add(cs.ApiName);
            } 
            for(Case c : newTagMap.values()){
                if(caseStatus.contains(c.Status) && !avoidUserName && 'Ticket'.equalsIgnoreCase(c.RecordType_Developer_Name__c)){
                    caseMap.put(c.Id, c);
                }
            }
        }
        else {
           for(Case c : newTagMap.values()){
                if('Ticket'.equalsIgnoreCase(c.RecordType_Developer_Name__c) && (!avoidUserName || 'MyICAM'.equalsIgnoreCase(c.Origin)) ){
                    caseMap.put(c.Id, c);
                }
            } 
        } 
                    
        if(caseMap.size() > 0){
            ID jobID = System.enqueueJob(new SDG_ReST_RichiestaDiServizio(caseMap));
        }
    }
    
}