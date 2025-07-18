public without sharing class SDG_ReST_SyncLog_Request {

    public String env;
    public String job;
    public List<SDG_ReST_SyncLog_Task> tasks;

    class SDG_ReST_SyncLog_Task{
        public String obj;
        public Integer inserted;
        public Integer reject;    
    }

    public static SDG_ReST_SyncLog_Request parse(String json) {
		return (SDG_ReST_SyncLog_Request) System.JSON.deserialize(json, SDG_ReST_SyncLog_Request.class);
	}

    public static void insertSyncLog(String inputLog) {
		//CREA RECORD
         
        SDG_ReST_SyncLog_Request syncLog = SDG_ReST_SyncLog_Request.parse(inputLog.replaceAll('insert', 'inserted'));

        //concatena datetime
        List<SyncLog__c> logList = new List<SyncLog__c>();
        
        for(SDG_ReST_SyncLog_Task t : syncLog.tasks){
            if(t.reject > 0){
                logList.add(new SyncLog__c(Name = syncLog.job, ObjectName__c = t.obj, Inserted__c = t.inserted, Rejected__c = t.reject));
            } 
        } 

        List<Database.SaveResult> result = Database.insert(logList, false);   
        if(result != null && result.size() > 0){
            System.debug('Creati ' + result.size() + ' SyncLog.');
        }   
	}

    public static Integer deleteOldSyncLog(Integer days) {
        Integer numLogsDeleted = 0;
        List<Database.DeleteResult> deletedLogs = Database.delete(Database.query('SELECT Id FROM SyncLog__c WHERE CreatedDate < LAST_N_DAYS:' + days), false);
        if(deletedLogs != null && deletedLogs.size() > 0){
            System.debug('Eliminati ' + deletedLogs.size() + ' SyncLog.');
            numLogsDeleted = deletedLogs.size();
        }
        return numLogsDeleted;
	}
}