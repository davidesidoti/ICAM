public without sharing class SDG_ReST_Contatto_Request{

	public String CNTTTL;								//Stato civile
	public String CNTLNA;								//Cognome
	public String CNTFNA;								//Nome
	public String CRY;									//Paese
	public String CNTNUM;								//Crono
	public String CNTETS;								//Telefono
	public String CNTFAX;								//Fax
	public String CNTMOB;								//Cellulare
	public String CNTEMA;								//Indirizzo internet
	public String CNTWEB;								//Indirizzo internet
	public String CNTFBDMAG;							//Mailing vietato
	public String CNTLAN;								//Lingua
	public String CNTBIR;								//Data di nascita
	public String CNTCSP;								//Categoria
	public String ADD1;									//Indirizzo riga 1
	public String ADD2;									//Indirizzo riga 2
	public String ADD3;									//Indirizzo riga 3
	public String ZIP;									//CAP
	public String CTY;									//Città
	public String SAT;									//Provincia
	public String YREG;									//Reegione
	public List<SDG_ReST_Relazioni> RELAZIONI;			//Relazioni

	public without sharing class SDG_ReST_Relazioni {
		public String BPATYP;							//Tipo entità
		public String BPANUM;							//Entità
		public String CNTFNC;							//Funzione
		public String CNTSRV;							//Servizio
		public String CNTMSS;							//Ruolo
	}

    public static String serializeRequest(Contact cnt, Boolean prettyPrint){
        SDG_ReST_Contatto_Request contatto = new SDG_ReST_Contatto_Request();
        contatto.CNTTTL = cnt.MaritalStatus__c != null ? cnt.MaritalStatus__c : '1';
        contatto.CNTLNA = cnt.LastName;
        contatto.CNTFNA = cnt.FirstName;
		contatto.CNTNUM = SDG_ReST_Utils.getExtId(cnt.ExternalId__c, '_');
        contatto.CRY = cnt.Country__c;
        contatto.CNTETS = cnt.Phone;
        contatto.CNTFAX = cnt.Fax;
        contatto.CNTMOB = cnt.MobilePhone;
        contatto.CNTEMA = cnt.Email;
        contatto.CNTFBDMAG = SDG_ReST_Utils.boolToString(cnt.NoMailing__c);
        contatto.CNTLAN = cnt.Language__c;
        contatto.CNTBIR = SDG_ReST_Utils.dateFormat(cnt.Birthdate, 'yyyyMMdd');
        contatto.CNTCSP = cnt.Category__c;
		contatto.CNTWEB = cnt.Email;
        contatto.ADD1 = cnt.MailingStreet;
        //contatto.ADD2 = cnt.;
        //contatto.ADD3 = cnt.;
        contatto.ZIP = cnt.MailingPostalCode;
        contatto.CTY = cnt.MailingCity?.toUpperCase();
        contatto.SAT = cnt.MailingState?.toUpperCase();
		contatto.YREG = cnt.Region__c;
		
		if (cnt.Account_ExternalId__c != null) {
			contatto.RELAZIONI = new List<SDG_ReST_Relazioni>();
			SDG_ReST_Relazioni rel = new SDG_ReST_Relazioni();
			rel.BPANUM = SDG_ReST_Utils.getExtId(cnt.Account_ExternalId__c, '_');
			rel.BPATYP = '1';
			rel.CNTFNC = cnt.Role__c;
			rel.CNTMSS = cnt.Mission__c;
			rel.CNTSRV = cnt.Service__c;
			contatto.RELAZIONI.add(rel); 
			System.debug('CONTATTO RELAZIONI: ' + contatto.RELAZIONI);
		}

		return (prettyPrint ? System.JSON.serializePretty(contatto, true) : System.JSON.serialize(contatto, true));
    }

}