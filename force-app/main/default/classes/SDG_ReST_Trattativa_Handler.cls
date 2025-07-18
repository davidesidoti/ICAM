public without sharing class SDG_ReST_Trattativa_Handler extends TR_BaseTriggerHandler {

    private List<Opportunity> newTagList;
    private List<Opportunity> oldTagList;
    private Map<ID, Opportunity> newTagMap;
    private Map<ID, Opportunity> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
    
    public SDG_ReST_Trattativa_Handler() {
        oldTagList = (List<Opportunity>)Trigger.old;
        newTagList = (List<Opportunity>)Trigger.new;
        newTagMap = (Map<ID, Opportunity>)Trigger.newMap;
        oldTagMap = (Map<ID, Opportunity>)Trigger.oldMap;
    } 
    
    public override void afterUpdate(){
        if(!avoidUserName){
            List<Opportunity> oppToRequest = new List<Opportunity>();
            for(Opportunity opp : newTagMap.values()){
                if(opp.ExternalId__c != null ){
                    oppToRequest.add(opp);
                }
            }
                
            if(oppToRequest.size() > 0){
                ID jobID = System.enqueueJob(new SDG_ReST_Trattativa(oppToRequest));
            }  
        }
        
    } 
}