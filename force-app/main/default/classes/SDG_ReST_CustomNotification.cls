public without sharing class SDG_ReST_CustomNotification {

    public String targetId;
    public String devName;
    public String title;
    public String body;

    public SDG_ReST_CustomNotification(String targetId, String devName, String title, String body) {
        this.targetId = targetId;
        this.devName = devName;
        this.title = title;
        this.body = body;
    }
}