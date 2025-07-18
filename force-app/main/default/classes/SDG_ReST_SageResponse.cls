public without sharing class SDG_ReST_SageResponse {

    public Boolean error;
	public Boolean created;
	public List<String> errors;
    public List<String> messages;
	public List<String> warnings;

    public static SDG_ReST_SageResponse parse(String json) {
		return (SDG_ReST_SageResponse) System.JSON.deserialize(json, SDG_ReST_SageResponse.class);
	}
}