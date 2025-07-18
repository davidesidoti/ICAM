public without sharing class SDG_ReST_SyncLogResponse {
    public String statusMessage;
	public String status;

	
	public static SDG_ReST_SyncLogResponse parse(String json) {
		return (SDG_ReST_SyncLogResponse) System.JSON.deserialize(json, SDG_ReST_SyncLogResponse.class);
	}

    public SDG_ReST_SyncLogResponse() {
        this.status = 'ERROR';
        this.statusMessage = '';
    }

    public override String toString() {
        return JSON.serialize(this, true);
    }
}