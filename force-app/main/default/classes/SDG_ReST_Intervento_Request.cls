public without sharing class SDG_ReST_Intervento_Request {
    
    public String SRVDEMNUM;                                   //Crono richiesta
    public String BPC;                                         //Cliente
    public String CCN;                                         //Interlocutore
    public String TYP;                                         //Categoria
    public String DAT;                                         //Inizio
    public String DATEND;                                      //Fine
    public String HOU;                                         //Ora
    public String HOUEND;                                      //Ora Fine
    public String FULDAY;                                      //Giornata intera
    public String WEE;                                         //Settimana
    public String DUR;                                         //Durata
    public String REP;                                         //Partecipante
    public String HTOTTIMSPG;                                  //Tempo passate (Ore)
    public String MTOTTIMSPG;                                  //Tempo passate (Min)
    public String PBLSOL;                                      //Problema risolto
    public String SCO;                                         //Subappaltato
    public String SCONUM;                                      //Conto lav.
    public String SCOAMT;                                      //Importo negoziato
    public String CUR;                                         //Valuta
    public String DON;                                         //Effettuato
    public String ITNORIVCR;                                   //N° documento origine
    public String DTCKIL;                                      //Distanza (Km)
    public String TRITIM;                                      //Tempo perc. stimato
    public String ADD;                                         //Indirizzo
    public String ADD1;                                        //Indirizzo
    public String ADD2;                                        //Indirizzo
    public String ZIP;                                         //CAP
    public String CTY;                                         //Città
    public String CRY;                                         //Paese
    public String SAT;                                         //Provincia
    public String TEL;                                         //Telefono
    public String MOB;                                         //Cellulare
    public String EML;                                         //Indirizzo e-mail
    public String IFFADD;                                      //Indicazioni
    public String NUM;                                         //Crono
    public String FULOBJ;                                      //Informazioni
    public String FULRPO;                                      //Resoconto
    public List<SDG_ReST_Materiali> MATERIALI;                 //Materiali

    public without sharing class SDG_ReST_Materiali {
        public String HDTMACSRE;                               //Parco interessato
        public String HDTCPN;                                  //Componente
        public String HDTTYP;                                  //Pezzo/Manodopera
        public String HDTITM;                                  //Articolo consumato
        public String HDTQTY;                                  //Quantità/Durata
        public String HDTUOM;                                  //Unità
        public String HDTSTOFCY;                               //Deposito
        public String HDTDONDAT;                               //Effettuato il
        public String HDTDONHOU;                               //Effettuato Articolo
        public String SPGTIMHOU;                               //Tempo trascorso
        public String SPGTIMMNT;                               //Tempo trascorso
        public String HDTSTOISS;                               //Uscita di stock
        public String HDTINV;                                  //Fatturabili
        public String HDTAMTINV;                               //Importo fatturato   
    }

    public static String doubleToString(Decimal val){
        String result = (String.valueOf(val).split('\\.')[0].leftPad(5, '0'));
        return result.substring(0, 3) + ':' + result.substring(3, 5);
    }

    public static String serializeRequest(WorkOrder wo, List<ProductConsumed> prdList, Boolean prettyPrint){
        SDG_ReST_Intervento_Request interv = new SDG_ReST_Intervento_Request();

        interv.SRVDEMNUM = wo?.Case_ExternalId__c;
        interv.BPC = SDG_ReST_Utils.getExtId(wo?.Account_ExternalId__c, '_');
        interv.CCN = SDG_ReST_Utils.getExtId(wo?.Contact_ExternalId__c, '_');
        interv.TYP = wo.Category__c;
        interv.DAT = wo.StartDate?.format('yyyyMMdd');
        interv.DATEND = wo.EndDate?.format('yyyyMMdd');
        interv.HOU = wo.StartDate?.format('HHmm');
        interv.HOUEND = wo.EndDate?.format('HHmm');
        interv.FULDAY = SDG_ReST_Utils.boolToString(wo.FullDay__c);
        interv.WEE = wo.Week__c?.toPlainString();
        interv.DUR = wo.Duration != null ? doubleToString(wo.Duration) : null;
        interv.REP = wo.CodeResource__c?.split(';')?.size() > 0 ? wo.CodeResource__c?.split(';')?.get(0) : null; 
        interv.HTOTTIMSPG = null;
        interv.MTOTTIMSPG = null; 
        interv.PBLSOL = SDG_ReST_Utils.boolToString(wo.IsResolved__c);
        interv.SCO = SDG_ReST_Utils.boolToString(wo.IsSubcontracting__c);
        interv.SCONUM = null;
        interv.SCOAMT = wo.AmountNegotiated__c != null ? String.valueOf(wo.AmountNegotiated__c) : null;
        interv.CUR = wo.Currency__c;
        interv.DON = SDG_ReST_Utils.boolToString(wo.Made__c);
        interv.ITNORIVCR = wo.OriginDocNum__c;
        interv.DTCKIL = wo.Distance__c != null ? String.valueOf(wo.Distance__c) : null;
        interv.TRITIM = wo.EstimatedTime__c != null ? String.valueOf(wo.EstimatedTime__c) : null;
        interv.ADD = wo.Street;
        interv.ADD1 = null;
        interv.ADD2 = null;
        interv.ZIP = wo.PostalCode;
        interv.CTY = wo.City;
        interv.CRY = wo.Country;
        interv.SAT = wo.State;
        interv.TEL = wo.Phone__c;
        interv.MOB = wo.MobilePhone__c;
        interv.EML = wo.Email__c;
        interv.IFFADD = wo.Indications__c;
        interv.NUM = wo.ExternalId__c;
        interv.FULOBJ = wo.Description;
        interv.FULRPO = null;
 
        if(prdList != null){
            List<SDG_ReST_Materiali> materials = new List<SDG_ReST_Materiali>();
            for(ProductConsumed prd : prdList){
                if(wo.Id == prd.WorkOrderId){
                    SDG_ReST_Materiali matElem = new SDG_ReST_Materiali();
                    matElem.HDTITM = prd.Product2?.ExternalId__c;
                    matElem.HDTQTY = prd.QuantityConsumed != null ? String.valueOf(prd.QuantityConsumed) : null;
                    matElem.HDTSTOFCY = 'ICAM1';
                    matElem.HDTTYP = '2';
                    matElem.HDTMACSRE = wo.Case_Asset_ExternalId__c;
                    matElem.HDTDONDAT = wo.StartDate?.format('yyyyMMdd');
                    //se prodotto proviene da una location del cliente HDTSTOISS 1
                    //se prodotto proviene da una location del manutentore HDTSTOISS 2
                    matElem.HDTSTOISS = SDG_ReST_Utils.boolToString(prd.Product2?.StockExit__c);
                    //matElem.HDTDONHOU = ;
                    matElem.HDTSTOISS = prd.Product2?.TypeOfArticle__c;
                    matelem.HDTUOM = prd.Product2?.QuantityUnitOfMeasure;
                    materials.add(matElem);
                }
            }
            if(materials != null){
                interv.MATERIALI = new List<SDG_ReST_Materiali>(materials);
            }
        }
        
        return (prettyPrint ? System.JSON.serializePretty(interv, true) : System.JSON.serialize(interv, true));
    }
    
}