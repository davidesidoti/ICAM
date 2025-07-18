public without sharing class SDG_ReST_OnDemandSync_Handler {
    
    @AuraEnabled
    public static SDG_ReST_OnDemandSync_Response startSync(String recordId) {

        SDG_ReST_OnDemandSync_Response result = new SDG_ReST_OnDemandSync_Response();

        //carica la lista delle email attive per le notifiche email in to, cc e bcc
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();
        
        Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
        Id recTypeService = SDG_ReST_Utils.getRecordType('Service', 'Opportunity');
        Id recTypeProspect = SDG_ReST_Utils.getRecordType('Prospect', 'Account');
        Id recTypeCustomer = SDG_ReST_Utils.getRecordType('Customer', 'Account');
        
        //se non siamo in sandbox e l'utente attivo non è avoidUsername
        if( ((!avoidUserName) || SDG_ReST_Utils.IsSandbox()) ){
            
            //recupera l'opportunity dal recordId
            Opportunity opp = [
                SELECT Id, Name, AccountId, ContactId__c, ProjectProbability__c, Probability, Account_ExternalId__c, Contact_ExternalId__c, Type,
                Amount, Average__c, isTotalized__c, CreatedDate, ExpectedCloseDate__c, Description, Currency__c, OfferType__c, RecordTypeId, Origin__c,
                ExternalId__c, CIG__c, CUP__c, Facility__c, PublicOrder__c, StageName, PendingReason__c, LossReason__c, CancellationReason__c, Competitor__c,
                RUPName__c, Category__c, Agent_ExternalId__c, Owner_ExternalId__c, Location_ExternalId__c, RecordType.DeveloperName, LastStageChangeDate, StartDate__c 
                FROM Opportunity WHERE Id =: recordId
            ];
            system.debug('TRATTATIVA = ' + opp);
                     
            //se esiste un contact collegato all'opportunity
            if(String.isNotBlank(opp.ContactId__c) && opp.Contact_ExternalId__c == null){
    
                //recupera il contact collegato all'opportunity
                Contact cnt = [
                    SELECT Id, MaritalStatus__c, LastName, FirstName, Name, MailingCountry, Phone, Fax, MobilePhone, Email, Language__c, Birthdate, 
                    Category__c, MailingStreet, MailingPostalCode, MailingCity, MailingState, ExternalId__c, Account_ExternalId__c, Account.ExternalId__c,
                    Title, Role__c, Mission__c, Service__c, NoMailing__c, Region__c, Country__c, Location_ExternalId__c, EmailAziendale__c 
                    FROM Contact WHERE Id =: opp.ContactId__c
                ];
                system.debug('CONTACT = ' + cnt);
                
                //se il contact non ha un external id inviala a Sage
                if(cnt.ExternalId__c == null) {
                    List<Contact> cntList = new List<Contact>{cnt};
                    
                    System.enqueueJob(new SDG_ReST_Contatto(cntList, opp, true));
                }
            }
            
            //se c'è un account collegato all'opportunity senza external id
            else if(String.isNotBlank(opp?.AccountId) && (opp.Account_ExternalId__c == null || opp.RecordTypeId == recTypeService)){
                
                //recupera l'account associato all'opportunity
                Account acc = [
                    SELECT Id, Category__c, Name, Description, Abbreviation__c, PayTerm__c, Currency__c, FiscalCode__c, IntraCommunityVAT__c, AccountCode__c,
                    StatisticFamily1__c, StatisticFamily2__c, StatisticFamily3__c, StatisticFamily4__c, StatisticFamily5__c, AutorizationPending__c, CommissionCategory__c, 
                    RecordTypeDeveloperName__c, RecordTypeId, ExternalId__c, Language__c, Country__c, Activity__c, Origin__c, ParentId, BusinessName2__c,
                    Rep1_ExternalId__c, BilledAddress_ExternalId__c, PayerAddress_ExternalId__c, BilledCustomer_ExternalId__c, VACBPartner__c,
                    PayerCustomer_ExternalId__c FROM Account WHERE Id =: opp.AccountId
                ];
                system.debug('PROSPECT = ' + acc);

                //se l'account non ha terzo e ha la partita IVA popolata
                if(acc.ParentId == null && String.isNotBlank(acc.IntraCommunityVAT__c)){
                    try {
                        //controllo che esista un terzo attivo con la stessa partita IVA
                        Account accSamePIVA = [
                            SELECT Id, Category__c, Name, Description, Abbreviation__c, PayTerm__c, Currency__c, FiscalCode__c, IntraCommunityVAT__c, RecordTypeId, RecordType.DeveloperName, Customer__c, BusinessName2__c,
                            StatisticFamily1__c, StatisticFamily2__c, StatisticFamily3__c, StatisticFamily4__c, StatisticFamily5__c, AutorizationPending__c, CommissionCategory__c, ExternalId__c, Language__c, Country__c, 
                            Activity__c, Origin__c, ParentId, Prospect__c, (SELECT Id, ExternalId__c, IntraCommunityVAT__c, Name FROM ChildAccounts WHERE RecordType.DeveloperName = 'Prospect' OR RecordType.DeveloperName = 'Customer') 
                            FROM Account WHERE RecordType.DeveloperName = 'BPartner' AND isActive__c = true AND IntraCommunityVAT__c =: acc.IntraCommunityVAT__c LIMIT 1            
                        ];        
                        
                        //se esiste un terzo attivo con la stessa partita iva senza prospect ne clienti
                        if(accSamePIVA != null && accSamePIVA?.ChildAccounts?.size() == 0 && accSamePIVA?.Prospect__c == false && accSamePIVA?.Prospect__c == false){
                            System.debug('ChildAccounts: ' + accSamePIVA.ChildAccounts.size());
                            //associo il terzo all'account dell'opportunity e mi creo l'external id, sarà poi inserito manualmente su Sage X3 per un limite dell'API
                            acc.ParentId = accSamePIVA?.Id;
                            acc.ExternalId__c = accSamePIVA?.ExternalId__c?.replaceFirst('BPR', acc.RecordTypeId == recTypeCustomer ? 'BPC' : 'PPT');
                            List<Account> accs = new List<Account>{acc};
                            SDG_ReST_Utils.updateNoTrigger(accs, 'SDG_ReST_Prospect_Handler');
                            SDG_ReST_Utils.sendNotificationEmail(
                                '[ICAM] Necessaria operazione manuale sync Salesforce -> Sage X3', 
                                '<ul>' + 
                                    '<li><b style="color:#e5142c;">Nome Record:</b> ' + acc.Name + '</li>' +
                                    '<li><b style="color:#e5142c;">Link a Salesforce:</b> <a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + acc.Id + '">Link</a></li>' +                                        
                                    '<li><b style="color:#e5142c;">Problematica:</b> ' + 'Il ' + acc.RecordTypeDeveloperName__c + ' è stato associato all\'interno di Salesforce al Terzo <a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + accSamePIVA.Id + '">' + accSamePIVA.Name + '</a> esistente. A causa di un limite tecnico, non è possibile inviarlo tramite integrazione a SageX3, perciò è necessario crearlo manualmente in SageX3, associato al Terzo identificato.' + '</li>' +
                                '</ul>'
                                , addressList.get('toaddress'), 
                                addressList.get('ccaddress'), addressList.get('bccaddress')
                            );
                            result = new SDG_ReST_OnDemandSync_Response('Necessaria operazione manuale', 'Il ' + acc.RecordTypeDeveloperName__c + ' è stato associato all\'interno di Salesforce al Terzo {0} esistente. A causa di un limite tecnico, non è possibile inviarlo tramite integrazione a SageX3, perciò è necessario crearlo manualmente in SageX3, associato al Terzo identificato.', accSamePIVA.Id, accSamePIVA.Name, SDG_ReST_OnDemandSync_Response.Toast_Event_Variant.warning);
                        }
                    }
                    //se non esiste un terzo attivo con la stessa partita IVA, invio l'account a SageX3 
                    catch (System.QueryException e) {
                        System.debug('ERRORE: ' + e);
                        List<Account> accs = new List<Account>{acc};
                        System.enqueueJob(new SDG_ReST_Prospect(accs, opp, true));
                        result = new SDG_ReST_OnDemandSync_Response('Prospect/Cliente e Trattativa inviate a Sage X3', 'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.');
                    }
                }
                //se non esiste un terzo attivo con la stessa partita IVA, invio l'account a SageX3 
                else{
                    List<Account> accs = new List<Account>{acc};
                    System.enqueueJob(new SDG_ReST_Prospect(accs, opp, true));
                    result = new SDG_ReST_OnDemandSync_Response('Prospect/Cliente e Trattativa inviate a Sage X3', 'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.');
                }
            } 

            //se l'opportunity non ha un external id e ha un account associato, inviala a Sage
            else if(String.isEmpty(opp.ExternalId__c) && String.isNotBlank(opp.Account_ExternalId__c)){
                List<Opportunity> opps = new List<Opportunity>{opp};
                System.enqueueJob(new SDG_ReST_Trattativa(opps));  
                result = new SDG_ReST_OnDemandSync_Response('Trattativa inviata a Sage X3', 'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.');
            } 
        }
        else{
            result = new SDG_ReST_OnDemandSync_Response('Utente non autorizzato', 'L\'utente che ha lanciato la sincronizzazione non è abilitato ad eseguire tale operazione. Contattare l\'amministratore di sistema.', SDG_ReST_OnDemandSync_Response.Toast_Event_Variant.info);
        }
        return result;
    }
    
}