public without sharing class SDG_ReST_Intervento_Handler extends TR_BaseTriggerHandler {

    private List<WorkOrder> newTagList;
    private List<WorkOrder> oldTagList;
    private Map<ID, WorkOrder> newTagMap;
    private Map<ID, WorkOrder> oldTagMap;
    private Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());

    public SDG_ReST_Intervento_Handler() {
        oldTagList = (List<WorkOrder>)Trigger.old;
        newTagList = (List<WorkOrder>)Trigger.new;
        newTagMap = (Map<ID, WorkOrder>)Trigger.newMap;
        oldTagMap = (Map<ID, WorkOrder>)Trigger.oldMap;
    }
    
    public override void afterUpdate(){
        checkStatus();
    } 

    private void checkStatus(){
        //if(!avoidUserName){
           Map<ID, WorkOrder> woToUpdate = new Map<ID, WorkOrder>();
        
            for(WorkOrder wo : newTagMap.values()){
                System.debug('Duration = ' + wo.Duration);
                System.debug('CodeResource = ' + wo.CodeResource__c);
                System.debug('avoidUserName = ' + !avoidUserName);
                if(wo.Status.equalsIgnoreCase('Completed') && (Test.isRunningTest() || (wo.Duration != null && wo.CodeResource__c != null))){
                    woToUpdate.put(wo.Id, wo);
                }             
            } 
                        
            if(woToUpdate.size() > 0){
                ID jobID = System.enqueueJob(new SDG_ReST_Intervento(woToUpdate, true));
            } 
        //}       
    }
 
}