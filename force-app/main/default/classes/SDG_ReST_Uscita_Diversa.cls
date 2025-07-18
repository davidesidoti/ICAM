public without sharing class SDG_ReST_Uscita_Diversa {

    public String VCRTYP;               //Tipo Movimento
    public String IPTDAT;               //Data registrazione
    public String VCRDES;               //Descrizione
    public String PJT;                  //Commessa
    public String TRSCOD;               //Cod. movimento
    public String TRSFAM;               //Famiglia Movimenti
    public List<SDG_ReST_Righe> RIGHE;  //Righe

    public without sharing class SDG_ReST_Righe{
        public String VCRLYN;               //N° riga movimento
        public String ITMREF;               //Articolo
        public String PCU;                  //Unità
        public String QTYPCU;               //Quantità
        public String STU;                  //Unità Magazzino
        public String QTYSTU;               //Quantità UM
        public String LOT;                  //Lotto
        public String LOC;                  //Ubicazione
        public String STA;                  //Stato
    }
    
    public static String serializeRequest(String extId, List<ProductConsumed> prdList, Boolean prettyPrint){
        SDG_ReST_Uscita_Diversa uscitaDiversa = new SDG_ReST_Uscita_Diversa();

        uscitaDiversa.VCRTYP = '20';
        uscitaDiversa.VCRDES = extId;
        uscitaDiversa.IPTDAT = SDG_ReST_Utils.dateFormat(Date.today(), 'yyyyMMdd');
        //uscitaDiversa.PJT = null;
        uscitaDiversa.TRSCOD = 'UUD';
        uscitaDiversa.TRSFAM = 'UCT';
        if(prdList != null){
            uscitaDiversa.RIGHE = new List<SDG_ReST_Righe>();
            Integer lineNmb = 0;
            for(ProductConsumed prd : prdList){
                if(prd?.IsSentToSageX3__c != true){
                    SDG_ReST_Righe riga = new SDG_ReST_Righe();
                    lineNmb += 1000;
                    riga.VCRLYN = String.valueOf(lineNmb);
                    riga.ITMREF = prd.Product2?.ExternalId__c;
                    riga.PCU = prd.Product2?.QuantityUnitOfMeasure;
                    riga.QTYPCU = prd.QuantityConsumed != null ? String.valueOf(prd.QuantityConsumed) : null;
                    riga.LOC = prd.ProductItem?.Location?.ExternalId__c;
                    riga.LOT = prd.ProductItem?.Lot__c;
                    riga.STA = prd.ProductItem?.Status__c;
                    uscitaDiversa.RIGHE.add(riga);
                    prd.ExternalId__c = extId + '_' + prd.Product2?.ExternalId__c + '_' + String.valueOf(lineNmb);
                }
                else{
                    lineNmb = Integer.valueOf(SDG_ReST_Utils.getExtId(prd?.ExternalId__c, '_'));
                }
            }
        }

        return (prettyPrint ? System.JSON.serializePretty(uscitaDiversa, true) : System.JSON.serialize(uscitaDiversa, true));
    }
}