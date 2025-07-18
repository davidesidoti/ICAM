public with sharing class SDG_ReST_OnDemandOfferSync_Handler {
    @AuraEnabled
    public static SDG_ReST_OnDemandSync_Response startSync(String quoteId) {
        SDG_ReST_OnDemandSync_Response result;

        // Prepare response and utilities
        Map<String, List<String>> addressList = SDG_ReST_Utils.getAddessesList();
        Boolean avoidUserName = SDG_ReST_Utils.checkIsToAvoid(UserInfo.getUserId());
        Id recTypeService = SDG_ReST_Utils.getRecordType('Service', 'Opportunity');
        Id recTypeProspect = SDG_ReST_Utils.getRecordType('Prospect', 'Account');
        Id recTypeCustomer = SDG_ReST_Utils.getRecordType('Customer', 'Account');
        
        // Only proceed if user is allowed or sandbox
        if(avoidUserName || SDG_ReST_Utils.IsSandbox()) {
            // Retrieve the custom offer record
            List<QuoteCustom__c> qcs = [
                SELECT Id, Opportunity__c
                FROM QuoteCustom__c
                WHERE Id = :quoteId
                LIMIT 1
            ];
            if(qcs.isEmpty()) {
                return new SDG_ReST_OnDemandSync_Response(
                    'Offerta non trovata',
                    'Nessuna offerta trovata per Id ' + quoteId,
                    SDG_ReST_OnDemandSync_Response.Toast_Event_Variant.error
                );
            }
            QuoteCustom__c qc = qcs[0];

            // Query the related opportunity
            Opportunity opp = [
                SELECT Id, Name, AccountId, ContactId__c, Account_ExternalId__c, Contact_ExternalId__c, RecordTypeId, ExternalId__c
                FROM Opportunity
                WHERE Id = :qc.Opportunity__c
                LIMIT 1
            ];
            System.debug('OFFERTA collegata a OPPORTUNITY = ' + opp);

            // Enqueue offer sync
            System.enqueueJob(new SDG_ReST_Offerta(new List<QuoteCustom__c>{ qc }, opp, true));
            
            // Handle Contact sync
            if(String.isNotBlank(opp.ContactId__c) && opp.Contact_ExternalId__c == null) {
                Contact cnt = [
                    SELECT Id, ExternalId__c
                    FROM Contact WHERE Id = :opp.ContactId__c
                ];
                if(cnt.ExternalId__c == null) {
                    System.enqueueJob(new SDG_ReST_Contatto(new List<Contact>{cnt}, opp, true));
                }
            }
            
            // Handle Account prospect/customer
            else if(String.isNotBlank(opp.AccountId) && (opp.Account_ExternalId__c == null || opp.RecordTypeId == recTypeService)) {
                Account acc = [
                    SELECT Id, RecordTypeDeveloperName__c, ExternalId__c, IntraCommunityVAT__c, ParentId
                    FROM Account WHERE Id = :opp.AccountId
                ];
                if(acc.ParentId == null && String.isNotBlank(acc.IntraCommunityVAT__c)) {
                    try {
                        Account accSamePIVA = [
                            SELECT Id, Name, ExternalId__c
                            FROM Account
                            WHERE RecordType.DeveloperName = 'BPartner'
                              AND isActive__c = true
                              AND IntraCommunityVAT__c = :acc.IntraCommunityVAT__c
                            LIMIT 1
                        ];
                        if(accSamePIVA != null) {
                            // Build HTML body with escaped apostrophes
                            List<String> htmlLines = new List<String>{
                                '<ul>',
                                '<li><b style="color:#e5142c;">Nome Record:</b> ' + acc.Name + '</li>',
                                '<li><b style="color:#e5142c;">Link a Salesforce:</b> <a href="' + URL.getOrgDomainUrl().toExternalForm() + '/' + acc.Id + '">Link</a></li>',
                                '<li><b style="color:#e5142c;">Problematica:</b> Il ' + acc.RecordTypeDeveloperName__c
                                    + ' è stato associato all\'interno di Salesforce al Terzo <a href="' + URL.getOrgDomainUrl().toExternalForm() + '/' + accSamePIVA.Id + '">' + accSamePIVA.Name + '</a> esistente. A causa di un limite tecnico, non è possibile inviarlo tramite integrazione a SageX3, perciò è necessario crearlo manualmente in SageX3, associato al Terzo identificato.</li>',
                                '</ul>'
                            };
                            String bodyEmail = String.join(htmlLines, '');

                            SDG_ReST_Utils.sendNotificationEmail(
                                '[ICAM] Necessaria operazione manuale sync Salesforce -> Sage X3',
                                bodyEmail,
                                addressList.get('toaddress'), addressList.get('ccaddress'), addressList.get('bccaddress')
                            );

                            result = new SDG_ReST_OnDemandSync_Response(
                                'Necessaria operazione manuale',
                                'Il ' + acc.RecordTypeDeveloperName__c +
                                ' è stato associato all\'interno di Salesforce al Terzo {0} esistente. A causa di un limite tecnico, non è possibile inviarlo tramite integrazione a SageX3, perciò è necessario crearlo manualmente in SageX3, associato al Terzo identificato.',
                                accSamePIVA.Id, accSamePIVA.Name, SDG_ReST_OnDemandSync_Response.Toast_Event_Variant.warning
                            );
                            return result;
                        }
                    } catch(System.QueryException e) {
                        System.enqueueJob(new SDG_ReST_Prospect(new List<Account>{acc}, opp, true));
                        result = new SDG_ReST_OnDemandSync_Response(
                            'Prospect/Cliente e Trattativa inviate a Sage X3',
                            'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.'
                        );
                        return result;
                    }
                }
                System.enqueueJob(new SDG_ReST_Prospect(new List<Account>{acc}, opp, true));
                result = new SDG_ReST_OnDemandSync_Response(
                    'Prospect/Cliente e Trattativa inviate a Sage X3',
                    'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.'
                );
                return result;
            }
            
            // Handle Opportunity sync if ExternalId missing
            if(String.isEmpty(opp.ExternalId__c) && String.isNotBlank(opp.Account_ExternalId__c)) {
                System.enqueueJob(new SDG_ReST_Trattativa(new List<Opportunity>{opp}));
                result = new SDG_ReST_OnDemandSync_Response(
                    'Trattativa inviata a Sage X3',
                    'Controllare nei prossimi minuti la campanella delle notifiche in alto a destra per eventuali notifiche di errore da Sage X3.'
                );
                return result;
            }
        }

        // User not authorized
        return new SDG_ReST_OnDemandSync_Response(
            'Utente non autorizzato',
            'L\'utente che ha lanciato la sincronizzazione non è abilitato ad eseguire tale operazione. Contattare l\'amministratore di sistema.',
            SDG_ReST_OnDemandSync_Response.Toast_Event_Variant.info
        );
    }
}
