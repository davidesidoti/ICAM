public without sharing class SDG_ReST_Trattativa_Request{
	
	public String OPPEXTNUM;						//Identificativo esterno
	public String OPPCMP;							//Terzo
	public String OPPMCN;							//Interlocutore	
	public String OPPDATOPN;						//Data apertura
	public String CUR;								//Valuta
	public String OPPTYP;							//Categoria
	public String OPPREP;							//Agente
	public String OPPNUM;							//Crono trattativa
	public String YTIPOOFFERTA;						//Tipo offerta
	public String STRSTE;							//A partire dal
	public String OPPAMT;							//Importo
	public String PBYPRJ;							//Probabilità Progetto
	public String OPPSUC;							//Perc. riuscita
	public String DAMAVE;							//Per media
	public String DAMCUM;							//Totalizzato
	public String OPPCDA;							//Conclusione aspettata
	public String OPPORI;							//Origine
	public String YCIG;								//CIG
	public String YCUP;								//CUP
	public String YINDIRIZZO;						//Indirizzo consegna
	public String YCOMMESSA;						//Commessa pubblica
	public String YDESOPP;							//Denominazione
	public String YUTERESP;							//Utente responsabile
	public List<SDG_ReST_Associate> ASSOCIATE;		//Trattative associate
	public List<SDG_ReST_Prevendita> PREVENDITA;	//Fasi pre-vendita
	public List<SDG_ReST_PostVendita> POSTVENDITA;	//Fasi post-vendita
	public List<SDG_ReST_Concorrenti> CONCORRENTI;	//Concorrenti

	class SDG_ReST_Associate {
		public String SBBPJT;	 					//Sotto progetto
	}

	class SDG_ReST_Prevendita {
		public String STE;							//Fase
		public String DON;							//Compiuta
		public String ENDDAT;						//Data fine
		public String REN;							//Causale
	}

	class SDG_ReST_PostVendita {
		public String STEX;							//Fase
		public String DONX;							//Compiuta
		public String ENDDATX;						//Data fine
		public String RENX;							//Causale
	}

	class SDG_ReST_Concorrenti {
		public String CPP;							//Concorrente
		public String CPPAMT;						//Importo concorrente
		public String SHC;							//Punti deboli
		public String ASE;							//Punti forti
	}

    public static String serializeRequest(Opportunity opp, List<MapOpportunity__c> mapOppList, Boolean prettyPrint){
        SDG_ReST_Trattativa_Request trattativa = new SDG_ReST_Trattativa_Request();

        //trattativa.OPPEXTNUM = opp.;
        trattativa.OPPCMP = SDG_ReST_Utils.getExtId(opp.Account_ExternalId__c, '_');
        trattativa.OPPMCN = SDG_ReST_Utils.getExtId(opp.Contact_ExternalId__c, '_');
        trattativa.OPPDATOPN = opp.StartDate__c != null ? SDG_ReST_Utils.dateFormat(opp.StartDate__c, 'yyyyMMdd') : opp.CreatedDate.format('yyyyMMdd');
        trattativa.CUR = opp.Currency__c;
        trattativa.OPPTYP = opp.Category__c;
    	trattativa.OPPREP = SDG_ReST_Utils.getExtId(opp.Agent_ExternalId__c, '_');
        trattativa.YTIPOOFFERTA = opp.OfferType__c;
		trattativa.OPPNUM = opp.ExternalId__c;
        //trattativa.STRSTE = '';
		//trattativa.OPPORI = opp.Origin__c;
        trattativa.OPPAMT = String.valueof(opp.Amount);
        trattativa.PBYPRJ = String.valueOf(opp.ProjectProbability__c);
        trattativa.OPPSUC = String.valueOf(opp.Probability);
        trattativa.DAMAVE = SDG_ReST_Utils.boolToString(opp.Average__c);
        trattativa.DAMCUM = SDG_ReST_Utils.boolToString(opp.isTotalized__c);
        trattativa.OPPCDA = SDG_ReST_Utils.dateFormat(opp.ExpectedCloseDate__c, 'yyyyMMdd');
        trattativa.YCIG = opp.CIG__c;
        trattativa.YCUP = opp.CUP__c;
        trattativa.YINDIRIZZO = SDG_ReST_Utils.getExtId(opp.Location_ExternalId__c, '_');
        trattativa.YCOMMESSA = SDG_ReST_Utils.boolToString(opp.PublicOrder__c);
        trattativa.YDESOPP = opp.Name;
        trattativa.YUTERESP = opp.Owner_ExternalId__c;

		trattativa.PREVENDITA = new List<SDG_ReST_Prevendita>();

		SDG_ReST_Prevendita apeElem = new SDG_ReST_Prevendita();
		apeElem.STE = 'APE';
		apeElem.ENDDAT = opp.StartDate__c != null ? SDG_ReST_Utils.dateFormat(opp.StartDate__c, 'yyyyMMdd') : opp.CreatedDate.format('yyyyMMdd');
		apeElem.DON = '2';
		trattativa.PREVENDITA.add(apeElem);

		if(SDG_ReST_Utils.getSageStatusTrattativa(opp.StageName, mapOppList) != 'APE'){
			SDG_ReST_Prevendita prevElem = new SDG_ReST_Prevendita();
			prevElem.STE = SDG_ReST_Utils.getSageStatusTrattativa(opp.StageName, mapOppList);
			prevElem.ENDDAT = SDG_ReST_Utils.dateFormat(opp.LastStageChangeDate?.date() != null ? opp.LastStageChangeDate?.date() : opp.CreatedDate?.date(), 'yyyyMMdd');
			prevElem.DON = '2';
			prevElem.REN = (opp.StageName == 'Long Time Pending' || opp.StageName == 'Temporary Pending' || opp.StageName == 'In Pending' || opp.StageName == 'Aperta Posticipata') ? opp.PendingReason__c : (opp.StageName == 'Closed Lost' ? opp.LossReason__c : ( opp.StageName == 'Chiusa Annullata' ? opp.CancellationReason__c : null));
			trattativa.PREVENDITA.add(prevElem);
		}

		if(opp.StageName == 'Closed Lost' && opp.LossReason__c == 'Azienda concorrente' && String.isNotBlank(opp.Competitor__c)){
			trattativa.CONCORRENTI = new List<SDG_ReST_Concorrenti>();
			SDG_ReST_Concorrenti concElem = new SDG_ReST_Concorrenti();
			concElem.CPP = opp.Competitor__c;
			trattativa.CONCORRENTI.add(concElem);
		}
		
        return (prettyPrint ? System.JSON.serializePretty(trattativa, true) : System.JSON.serialize(trattativa, true));
    }

}