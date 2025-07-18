public class SDG_ReST_RunSyncComponent {
    @AuraEnabled
    public static Integer startSync() {
        HttpResponse response = SDG_ReST_Utils.makeRequest('GET','force-sync', null, SDG_ReST_Utils.IsSandbox());
        return response.getStatusCode();
    }
}