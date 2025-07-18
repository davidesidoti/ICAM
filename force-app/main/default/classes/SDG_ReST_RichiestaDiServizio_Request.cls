public without sharing class SDG_ReST_RichiestaDiServizio_Request {
    
    public String SRENUMBPC;                    //Crono cliente
    public String SREDOO;                       //Committente
    public String SREBPC;                       //Cliente
    public String SRECCN;                       //Interlocutore
    public String SRETTR;                       //Titolo
    public String TSDCOD;                       //Famiglia statistica 1
    public String TSDCOD1;                      //Famiglia statistica 2
    public String TSDCOD2;                      //Famiglia statistica 3
    public String TSDCOD3;                      //Famiglia statistica 4
    public String TSDCOD4;                      //Famiglia statistica 5
    public String SREASS;                       //Assegnazione
    public String SREDET;                       //Dettaglio assegnazione
    public String SREDATASS;                    //Data assegnazione
    public String SRESAT;                       //Stato richiesta
    public String OVRCOV;                       //Copertura globale
    public String SREGRALEV;                    //Livello di gravità
    public String SRERESDAT;                    //Soluzione desiderata
    public String CONSPT;                       //Contratto supporto
    public String SREBPCINV;                    //Cliente fatturato
    public String SREBPCPYR;                    //Terzo pagante
    public String SREBPCGRU;                    //Cliente gruppo
    public String STOFCY;                       //Deposito
    public String SREPJT;                       //Trattativa
    public String SREREP;                       //Agente 1
    public String SREREP1;                      //Agente 2
    public String SREVACBPR;                    //Regime IVA Terzi
    public String SRECHGTYP;                    //Tipo di cambio
    public String SREPRITYP;                    //Tipo prezzo
    public String SRECUR;                       //Valuta
    public String SREPTE;                       //Condizione di Pagamento
    public String SREDEP;                       //Sconto
    public String SRENUM;                       //Crono
    public String SREDES;                       //Descrizione
    public List<SDG_ReST_Parco> PARCO;          //Parco interessato

    public without sharing class SDG_ReST_Parco {
        public String MACNUM;                   //Codice parco
    }

    public static String serializeRequest(Case c, Boolean prettyPrint){

        SDG_ReST_RichiestaDiServizio_Request rds = new SDG_ReST_RichiestaDiServizio_Request();
        rds.SRENUMBPC = c.ServReqCustomer__c;
        rds.SREDOO = null;
        rds.SREBPC = SDG_ReST_Utils.getExtId(c.Account_ExternalId__c, '_');
        rds.SRECCN = SDG_ReST_Utils.getExtId(c.Contact_ExternalId__c, '_');
        rds.SRETTR = !String.isBlank(c.Subject) ? c.Subject : c.Subject__c;
        rds.TSDCOD = c.StatisticFamily1__c;
        rds.TSDCOD1 = c.StatisticFamily2__c;
        rds.TSDCOD2 = c.StatisticFamily3__c;
        rds.TSDCOD3 = c.StatisticFamily4__c;
        rds.TSDCOD4 = (c.StatisticFamily5__c != '_' ? c.StatisticFamily5__c : null);
        rds.SREASS = c.Status;
        rds.SREDET = c.ServReqDetail__c;
        rds.SREDATASS = c.AssignedDate__c != null ? SDG_ReST_Utils.dateFormat(c.AssignedDate__c, 'yyyyMMdd') : c.CreatedDate.format('yyyyMMdd');
        rds.SRESAT = c.StatusRequest__c;
        //rds.OVRCOV = c.GlobalCover__c;
        rds.SREGRALEV = c.GravityLevel__c;
        rds.SRERESDAT = c.DesiredDueDate__c != null ? c.DesiredDueDate__c?.format('yyyyMMdd') : SDG_ReST_Utils.dateFormat(Date.newInstance(1753, 1, 1), 'yyyyMMdd');
        rds.CONSPT = c.ServiceContract_ExternalId__c;
        rds.SREBPCINV = SDG_ReST_Utils.getExtId(c.GroupCustomer_ExternalId__c, '_');
        rds.SREBPCPYR = SDG_ReST_Utils.getExtId(c.BilledCustomer_ExternalId__c, '_');
        rds.SREBPCGRU = SDG_ReST_Utils.getExtId(c.ThirdPayer_ExternalId__c, '_');
        rds.STOFCY = c.Facility__c;
        //rds.SREPJT = null;
        //rds.SREREP = null;
        //rds.SREREP1 = null;
        rds.SREVACBPR = c.VAC_BPartner__c;
        rds.SRECHGTYP = c.TypeOfChange__c;
        rds.SRECUR = c.Currency__c;
        rds.SREPTE = c.PayTerm__c;
        //rds.SREDEP = null; 
        rds.SRENUM = c.ExternalId__c;
        rds.SREDES = c.Description;
        rds.PARCO = new List<SDG_ReST_Parco>();
        SDG_ReST_Parco parcoElem = new SDG_ReST_Parco();
        parcoElem.MACNUM = c.Asset_ExternalId__c;
        rds.PARCO.add(parcoElem);
        
        return (prettyPrint ? System.JSON.serializePretty(rds, true) : System.JSON.serialize(rds, true));
    }

}