public without sharing class SDG_ReST_OnDemandSync_Response{
    @AuraEnabled public String title;
    @AuraEnabled public String message;
    @AuraEnabled public String variant;
    @AuraEnabled public String mode;
    @AuraEnabled public String recordId;
    @AuraEnabled public String recordName;

    public enum Toast_Event_Variant {success, info, warning, error}
    public enum Toast_Event_Mode {dismissible, pester, sticky}

    public SDG_ReST_OnDemandSync_Response(String title, String message, String recordId, String recordName, Toast_Event_Mode mode, Toast_Event_Variant variant){
        this.title = title;
        this.message = message;
        this.variant = variant.name();
        this.recordId = recordId;     
        this.recordName = recordName;
        this.mode = mode.name();
    }

    public SDG_ReST_OnDemandSync_Response(String title, String message, String recordId, String recordName, Toast_Event_Variant variant){
        this.title = title;
        this.message = message;
        this.variant = variant.name();
        this.recordId = recordId;     
        this.recordName = recordName;
        this.mode = Toast_Event_Mode.sticky.name();
    }
    
    public SDG_ReST_OnDemandSync_Response(String title, String message, Toast_Event_Variant variant){
        this.title = title;
        this.message = message;     
        this.variant = variant.name();
        this.mode = Toast_Event_Mode.dismissible.name();
    }

    public SDG_ReST_OnDemandSync_Response(String title, String message){
        this.title = title;
        this.message = message;     
        this.variant = Toast_Event_Variant.success.name();
        this.mode = Toast_Event_Mode.dismissible.name();
    }

    public SDG_ReST_OnDemandSync_Response(){
        this.title = 'Contatto, Prospect/Cliente e Opportunità inviati a Sage X3';
        this.message = 'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.';     
        this.variant = Toast_Event_Variant.success.name();
        this.mode = Toast_Event_Mode.dismissible.name();
    }

}