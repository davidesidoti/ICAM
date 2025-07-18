public without sharing class SDG_ReST_CustomEmail {

    public String urlSalesforce;
    public String urlPath;
    public String objectName;
    public String request;
    public String response;

    public SDG_ReST_CustomEmail(String recordId, String urlPath, String objectName, String request, String response) {
        this.urlSalesforce = URL.getSalesforceBaseUrl().toExternalForm() + '/' + recordId;
        this.urlPath = urlPath;
        this.objectName = objectName;
        this.request = request;
        this.response = response;
    }
}