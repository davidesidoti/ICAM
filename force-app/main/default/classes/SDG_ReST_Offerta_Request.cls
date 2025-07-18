public without sharing class SDG_ReST_Offerta_Request {

    // Campi base dell'offerta
    public String QUONUM;      // Numero Offerta
    public String QUOSRC;      // ExternalId Offerta
    public String QUODAT;      // Data Offerta (yyyyMMdd)
    public String OPPSRC;      // ExternalId Opportunity collegata
    public String CUR;         // Valuta
    public String AMT;         // Importo
    public String OTXT;        // Testo Offerta

    // Classe annidata per eventuali relazioni (es. Quote -> Opportunity)
    public without sharing class SDG_ReST_Relazioni {
        public String BPATYP;    // Tipo entità ("O" per Opportunity)
        public String BPANUM;    // ExternalId entità collegata
        public String FUNZ;      // Funzione/ruolo
        public String SRV;       // Servizio
    }

    public List<SDG_ReST_Relazioni> RELAZIONI;

    public static String serializeRequest(QuoteCustom__c off, Boolean prettyPrint) {
        SDG_ReST_Offerta_Request req = new SDG_ReST_Offerta_Request();
        // Mappatura campi
        req.QUONUM = off.Name;
        req.QUOSRC = SDG_ReST_Utils.getExtId(off.ExternalId__c, '_');
        req.QUODAT = SDG_ReST_Utils.dateFormat(off.OfferDate__c, 'yyyyMMdd');
        req.OPPSRC = SDG_ReST_Utils.getExtId(off.ExternalIdOpportunity__c, '_');
        req.CUR   = off.Currency__c;
        req.AMT   = off.SICIPrice__c != null ? String.valueOf(off.SICIPrice__c) : null;
        req.OTXT  = off.OfferText__c;

        // Imposta eventuali relazioni Quote -> Opportunity
        req.RELAZIONI = new List<SDG_ReST_Relazioni>();
        if(off.Opportunity__c != null) {
            SDG_ReST_Relazioni rel = new SDG_ReST_Relazioni();
            rel.BPATYP = 'O';
            rel.BPANUM = req.OPPSRC;
            rel.FUNZ   = null;
            rel.SRV    = null;
            req.RELAZIONI.add(rel);
        }

        // Serializzazione JSON
        if(prettyPrint) {
            return JSON.serializePretty(req, true);
        }
        return JSON.serialize(req, true);
    }
}
