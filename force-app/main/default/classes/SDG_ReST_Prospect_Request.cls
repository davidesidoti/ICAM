public without sharing class SDG_ReST_Prospect_Request {

	public String BCGCOD;											//Categoria
	public String BPCNUM;											//Cliente
	public String BPRNAM;											//Ragione sociale
	public String BPRNAM2;											//Ragione sociale 2
	public String BPRSHO;											//Descrizione breve
	public String BPRLOG;											//Sigla
	public String PTE;												//Condizione pagamento
	public String CUR;												//Valuta
	public String CRN;												//Codice Fiscale
	public String EECNUM;											//N° IVA
	public String COMCAT;											//Categ. commissione
	public String REP;												//Agente
	public String TSCCOD1;											//Famiglia statistica 1
	public String TSCCOD2;											//Famiglia statistica 2
	public String TSCCOD3;											//Famiglia statistica 3
	public String TSCCOD4;											//Famiglia statistica 4
	public String TSCCOD5;											//Famiglia statistica 5
	public String CRY;												//Paese
	public String LAN;												//Lingua
	public String BUS;												//Attività
	public String ORIPPT;											//Origine
	public List<SDG_ReST_Indirizzi> INDIRIZZI;						//Indirizzi
	public List<SDG_ReST_Contatti> CONTATTI;						//Contatti

    public without sharing class SDG_ReST_Indirizzi {
		public String BPAADD;										//Codice Indirizzo
		public String BPADES;										//Descrizione
		public String BPAADDLIG1;									//Indirizzo riga 1
		public String BPAADDLIG2;									//Indirizzo riga 2
		public String BPAADDLIG3;									//Indirizzo riga 3
		public String POSCOD;										//CAP
		public String CTY;											//Città
		public String CRY;											//Paese
		public String TEL;											//Telefono
		public String FAX;											//Fax
        public String SAT;											//Provincia
        public String FCYWEB;										//Sito Web
        public String WEB;											//Indirizzo internet
		public String BPAADDFLG;									//Default
		public String YREG;											//Regione
	}
	public without sharing class SDG_ReST_Contatti {
		public String CCNCRM;										//Crono
		public String CNTLNA;										//Cognome
		public String CNTFNA;										//Nome
		public String CNTCRY;										//Paese
		public String CNTTTL;										//Stato civile
		public String CNTFNC;										//Funzione
		public String CNTSRV;										//Servizio
		public String CNTADD;										//Indirizzo
		public String CNTTEL;										//Telefono
		public String CNTFAX;										//Fax
		public String CNTMOB;										//Cellulare
		public String CNTWEB;										//Indirizzo internet
		public String CNTMSS;										//Missione
		public String CNTBIR;										//Data di nascita
		public String CNTFBDMAG;									//Mailing vietato
		public String CNTLAN;										//Lingua
		public String CNTCSP;										//Categoria
	}

    public static String serializeRequest(Account acc, List<Schema.Location> locationList, List<Contact> contactList, Boolean prettyPrint){
        SDG_ReST_Prospect_Request cliente = new SDG_ReST_Prospect_Request();
		
        cliente.BCGCOD = acc.Category__c;
        cliente.BPCNUM = SDG_ReST_Utils.getExtId(acc.ExternalId__c, '_');
        cliente.BPRNAM = acc.Name;
		cliente.BPRNAM2 = acc.BusinessName2__c;
        cliente.BPRSHO = acc.Description;
        cliente.BPRLOG = acc.Abbreviation__c;
        cliente.PTE = acc.PayTerm__c;
        cliente.CUR = acc.Currency__c;
        cliente.CRN = acc.FiscalCode__c;
        cliente.EECNUM = acc.IntraCommunityVAT__c;
        cliente.COMCAT = acc.CommissionCategory__c;
        cliente.REP = SDG_ReST_Utils.getExtId(acc.Rep1_ExternalId__c, '_');
        cliente.TSCCOD1 = acc.StatisticFamily1__c;
        cliente.TSCCOD2 = acc.StatisticFamily2__c;
		cliente.TSCCOD3 = acc.StatisticFamily3__c;
        cliente.TSCCOD4 = acc.StatisticFamily4__c;
		cliente.TSCCOD5 = acc.StatisticFamily5__c;
        cliente.CRY = acc.Country__c;
        cliente.LAN = acc.Language__c;
        //cliente.BUS = acc.Activity__c;
        cliente.ORIPPT = acc.Origin__c;

        if(locationList != null){
			cliente.INDIRIZZI = new List<SDG_ReST_Indirizzi>();

			//per ogni Location
			for(Schema.Location loc : locationList){
				SDG_ReST_Indirizzi locElem = new SDG_ReST_Indirizzi();	
				
				locElem.BPAADD = loc.Progressive_Sage__c;
				locElem.BPADES = loc.Name;
				locElem.BPAADDLIG1 = loc.Address1__c;
				locElem.BPAADDLIG2 = loc.Address2__c;
				locElem.BPAADDLIG3 = loc.Address3__c;
				locElem.POSCOD = loc.ZipPostalCode__c;
				locElem.CTY = loc.City__c;
				locElem.CRY = loc.Country__c;
				locElem.TEL = loc.Phone__c;
				locElem.FAX = loc.Fax__c;
				locElem.SAT = loc.State__c?.length() <= 2 ? loc.State__c?.toUpperCase() : null;
				locElem.FCYWEB = loc.FacilityWeb__c;
				locElem.WEB = loc.Email__c;
				locElem.BPAADDFLG = SDG_ReST_Utils.boolToString(loc.DefaultAddress__c);
				locElem.YREG = loc.Region__c;
		
				cliente.INDIRIZZI.add(locElem);
			}
		}

		//per ogni contatto
		if(contactList != null){
			cliente.CONTATTI = new List<SDG_ReST_Contatti>(); 
			for(Contact cnt : contactList){
				if(cnt.ExternalId__c != null){
					SDG_ReST_Contatti cntElem = new SDG_ReST_Contatti();	
					 cntElem.CCNCRM = SDG_ReST_Utils.getExtId(cnt.ExternalId__c, '_');
					cntElem.CNTLNA = cnt.LastName;
					cntElem.CNTFNA = cnt.FirstName;
					cntElem.CNTCRY = cnt.Country__c;
					cntElem.CNTTTL = cnt.MaritalStatus__c != null ? cnt.MaritalStatus__c : '1';
					cntElem.CNTFNC = cnt.Role__c;
					//cntElem.CNTSRV = cnt.Service__c;
					cntElem.CNTSRV = cnt.Title?.left(30);
					cntElem.CNTADD = SDG_ReST_Utils.getExtId(cnt.Location_ExternalId__c, '_');
					cntElem.CNTTEL = cnt.Phone;
					cntElem.CNTFAX = cnt.Fax;
					cntElem.CNTMOB = cnt.MobilePhone;
					// cntElem.CNTWEB = cnt.EmailAziendale__c;
					cntElem.CNTWEB = cnt.Email;
					cntElem.CNTMSS = cnt.Mission__c;
					cntElem.CNTBIR = SDG_ReST_Utils.dateFormat(cnt.Birthdate, 'yyyyMMdd');
					cntElem.CNTFBDMAG = SDG_ReST_Utils.boolToString(cnt.NoMailing__c);
					cntElem.CNTLAN = cnt.Language__c;
					cntElem.CNTCSP = cnt.Category__c;
					cliente.CONTATTI.add(cntElem); 
				}
			}
		}

		return (prettyPrint ? System.JSON.serializePretty(cliente, true) : System.JSON.serialize(cliente, true));
    }

}