public without sharing class SDG_ReST_Contatto_Handler extends TR_BaseTriggerHandler {

    private List<Contact> newTagList;
    private List<Contact> oldTagList;
    private Map<ID, Contact> newTagMap;
    private Map<ID, Contact> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
    
    public SDG_ReST_Contatto_Handler() {
        oldTagList = (List<Contact>)Trigger.old;
        newTagList = (List<Contact>)Trigger.new;
        newTagMap = (Map<ID, Contact>)Trigger.newMap;
        oldTagMap = (Map<ID, Contact>)Trigger.oldMap;
    } 
    
    public override void afterUpdate(){
        if(!avoidUserName && UserInfo.getName() != 'B2BMA Integration'){
            List<Contact> cntToRequest = new List<Contact>();
            for(Contact cnt : newTagMap.values()){
                if(cnt.ExternalId__c != null ){
                    cntToRequest.add(cnt);
                }
            }
                
            if(cntToRequest.size() > 0){
                ID jobID = System.enqueueJob(new SDG_ReST_Contatto(cntToRequest, null, true));
            }
        }
        
    } 
}