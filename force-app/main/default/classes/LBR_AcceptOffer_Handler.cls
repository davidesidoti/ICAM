public with sharing class LBR_AcceptOffer_Handler {
    @AuraEnabled(cacheable=true)
    public static Boolean shouldDisplayLWC(Id offerId) {
        try {
            if (!Schema.sObjectType.Opportunity.isAccessible()) {
                throw new AuraHandledException('Insufficient access to Opportunity object');
            }
            // Recupera l'opportunità
            Opportunity opp = getOppFromOffer(offerId);
            QuoteCustom__c offer = getOffer(offerId);
            
            if (opp == null) {
                return false;
            }

            return opp.StageName == LBR_Utils.OPP_STAGE_PROPOSAL && offer.OfferStatus__c != LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isOpportunityRelatedToProspect(Id offerId){
        try {
            if (!Schema.sObjectType.Opportunity.isAccessible() || !Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('Insufficient access to required objects');
            }
            Opportunity opp = getOppFromOffer(offerId);
            if (opp == null) {
                return false;
            }
            Account acc = getAccountFromOpportunity(opp);
            return acc.RecordTypeDeveloperName__c == LBR_Utils.ACC_RECORD_TYPE_PROSPECT;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static QuoteCustom__c getOffer(Id offerId) {
        try {
            if (!Schema.sObjectType.QuoteCustom__c.isAccessible()) {
                throw new AuraHandledException('Insufficient access to QuoteCustom__c object');
            }
            string query = buildQueryWithAllFields('QuoteCustom__c') + ' WHERE Id = :offerId';
            QuoteCustom__c offer = Database.query(query);
            return offer;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Recupera l'account associato con l'offerta
    @AuraEnabled
    public static Account getAccountFromOffer(Id offerId) {
        try {
            if (!Schema.sObjectType.Opportunity.isAccessible() || !Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('Insufficient access to required objects');
            }
            Opportunity opp = getOppFromOffer(offerId);
            if (opp == null) {
                throw new AuraHandledException('No opportunity found for this offer');
            }
            
            Account acc = getAccountFromOpportunity(opp);
            if (acc == null) {
                throw new AuraHandledException('No account found for the opportunity');
            }
            
            return acc;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Aggiorna i campi dell'account
    @AuraEnabled
    public static Account updateAccount(Id accountId, Map<String, Object> accountFields) {
        try {
            if (!Schema.sObjectType.Account.isUpdateable()) {
                throw new AuraHandledException('Insufficient access to update Account');
            }
            System.debug('Starting account field update.');
            
            // Recupera l'account
            Account acc = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
            
            // Applica gli aggiornamenti dai fields
            for (String fieldName : accountFields.keySet()) {
                // Salta field di sistema e record type che verrà aggiornato dopo
                if (fieldName != LBR_Utils.FIELD_RECORD_TYPE_ID && 
                    fieldName != LBR_Utils.FIELD_RECORD_TYPE_DEV_NAME && 
                    !fieldName.startsWith(LBR_Utils.FIELD_SYSTEM_PREFIX)) {
                    
                    acc.put(fieldName, accountFields.get(fieldName));
                }
            }
            
            // Aggiorna l'account
            System.debug('About to update account fields.');
            update acc;
            System.debug('Account fields updated successfully');
            
            // Ritorna l'account aggiornato
            string query = buildQueryWithAllFields('Account') + ' WHERE Id = :accountId';
            return Database.query(query);
        } catch (Exception e) {
            System.debug('Error in updateAccount: ' + e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error updating account fields: ' + e.getMessage());
        }
    }
    
    // Converte l'account da Prospect a Cliente
    @AuraEnabled
    public static Boolean convertProspectToClient(Id accountId) {
        try {
            if (!Schema.sObjectType.Account.isUpdateable() || !Schema.sObjectType.RecordType.isAccessible()) {
                throw new AuraHandledException('Insufficient access to required objects');
            }
            System.debug('Starting account conversion.');
            
            // Recupera le informazioni del record type
            Account acc = [SELECT Id, RecordTypeId, RecordTypeDeveloperName__c 
                          FROM Account 
                          WHERE Id = :accountId 
                          LIMIT 1];
            
            System.debug('Current account record type: ' + acc.RecordTypeDeveloperName__c);
            
            // Procede solo se l'account è un Prospect
            if (acc.RecordTypeDeveloperName__c != LBR_Utils.ACC_RECORD_TYPE_PROSPECT) {
                System.debug('Account is not a Prospect, skipping conversion');
                return false;
            }
            
            // Recupera tutti i possibili record type
            List<RecordType> allRTs = [
                SELECT Id, DeveloperName, Name
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND IsActive = true
            ];
            
            // Cerca il record type Cliente
            List<RecordType> clientRTs = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND (DeveloperName = :LBR_Utils.ACC_RECORD_TYPE_CLIENT OR Name = :LBR_Utils.ACC_RECORD_TYPE_CLIENT)
                AND IsActive = true 
                LIMIT 1
            ];
            
            if (clientRTs.isEmpty()) {
                System.debug('No Client record type found');
                
                // Prova a cercare altri record type se Cliente risulta vuoto
                clientRTs = [
                    SELECT Id 
                    FROM RecordType 
                    WHERE SObjectType = 'Account' 
                    AND (DeveloperName LIKE :('%' + LBR_Utils.ACC_RECORD_TYPE_CLIENT + '%') OR 
                         DeveloperName LIKE :('%' + LBR_Utils.ACC_RECORD_TYPE_CUSTOMER + '%') OR
                         Name LIKE :('%' + LBR_Utils.ACC_RECORD_TYPE_CLIENT + '%') OR 
                         Name LIKE :('%' + LBR_Utils.ACC_RECORD_TYPE_CUSTOMER + '%'))
                    AND IsActive = true 
                    LIMIT 1
                ];
                
                if (clientRTs.isEmpty()) {
                    throw new AuraHandledException('Could not find a Client record type');
                }
            }
            
            Id clientRecordTypeId = clientRTs[0].Id;
            
            // Aggiorna solo il record type
            acc.RecordTypeId = clientRecordTypeId;

            System.debug('About to convert account.');
            update acc;
            System.debug('Account converted successfully');
            
            return true;
        } catch (Exception e) {
            System.debug('Error in convertProspectToClient: ' + e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error converting account: ' + e.getMessage());
        }
    }
    
    // Metodo per aggiornare lo stato dell'offerta
    @AuraEnabled
    public static QuoteCustom__c updateOfferStatus(Id offerId, String newStatus) {
        try {
            if (!Schema.sObjectType.QuoteCustom__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient access to update QuoteCustom__c');
            }
            System.debug('Starting offer status update to: ' + newStatus);
            
            // Recupera l'offerta
            QuoteCustom__c offer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c WHERE Id = :offerId LIMIT 1];
            
            // Aggiorna lo stato
            offer.OfferStatus__c = newStatus;
            
            // Aggiorna l'offerta
            update offer;
            System.debug('Offer status updated successfully to: ' + newStatus);
            
            // Ritorna l'offerta aggiornata
            string query = buildQueryWithAllFields('QuoteCustom__c') + ' WHERE Id = :offerId';
            return Database.query(query);
        } catch (Exception e) {
            System.debug('Error updating offer status: ' + e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error updating offer status: ' + e.getMessage());
        }
    }
    
    // Metodo per ripristinare lo stato dell'offerta al suo valore originale
    @AuraEnabled
    public static Boolean rollbackOfferStatus(Id offerId, String originalStatus) {
        try {
            if (!Schema.sObjectType.QuoteCustom__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient access to update QuoteCustom__c');
            }
            System.debug('Starting rollback of offer status to: ' + originalStatus);
            
            // Recupera l'offerta
            QuoteCustom__c offer = [SELECT Id, OfferStatus__c FROM QuoteCustom__c WHERE Id = :offerId LIMIT 1];
            
            // Ripristina lo stato originale
            offer.OfferStatus__c = originalStatus;
            
            // Aggiorna l'offerta
            update offer;
            System.debug('Offer status rolled back successfully to: ' + originalStatus);
            
            return true;
        } catch (Exception e) {
            System.debug('Error rolling back offer status: ' + e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error rolling back offer status: ' + e.getMessage());
        }
    }
    
    // Metodo per aggiornare lo stato dell'opportunità a "Closed Won" o qualsiasi altro stato specificato
    @AuraEnabled
    public static Opportunity updateOpportunityStage(Id oppId, String newStage) {
        try {
            if (!Schema.sObjectType.Opportunity.isUpdateable()) {
                throw new AuraHandledException('Insufficient access to update Opportunity');
            }
            System.debug('Starting opportunity stage update to: ' + newStage);
            
            // Recupera l'opportunità
            Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :oppId LIMIT 1];
            
            // Aggiorna lo stato
            opp.StageName = newStage;
            
            // Aggiorna l'opportunità
            update opp;
            System.debug('Opportunity stage updated successfully to: ' + newStage);
            
            // Ritorna l'opportunità aggiornata
            string query = buildQueryWithAllFields('Opportunity') + ' WHERE Id = :oppId';
            return Database.query(query);
        } catch (Exception e) {
            System.debug('Error updating opportunity stage: ' + e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error updating opportunity stage: ' + e.getMessage());
        }
    }
    
    // Metodo per ripristinare lo stato dell'opportunità al suo valore originale
    @AuraEnabled
    public static Boolean rollbackOpportunityStage(Id oppId, String originalStage) {
        try {
            if (!Schema.sObjectType.Opportunity.isUpdateable()) {
                throw new AuraHandledException('Insufficient access to update Opportunity');
            }
            System.debug('Starting rollback of opportunity stage to: ' + originalStage);
            
            // Recupera l'opportunità
            Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :oppId LIMIT 1];
            
            // Ripristina lo stato originale
            opp.StageName = originalStage;
            
            // Aggiorna l'opportunità
            update opp;
            System.debug('Opportunity stage rolled back successfully to: ' + originalStage);
            
            return true;
        } catch (Exception e) {
            System.debug('Error rolling back opportunity stage: ' + e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error rolling back opportunity stage: ' + e.getMessage());
        }
    }
    
    // Metodo per recuperare informazioni sui record types
    @AuraEnabled
    public static List<Map<String, String>> getAvailableRecordTypes() {
        try {
            if (!Schema.sObjectType.RecordType.isAccessible()) {
                throw new AuraHandledException('Insufficient access to RecordType object');
            }
            List<Map<String, String>> result = new List<Map<String, String>>();
            
            List<RecordType> rts = [
                SELECT Id, DeveloperName, Name
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND IsActive = true
            ];
            
            for (RecordType rt : rts) {
                Map<String, String> rtInfo = new Map<String, String>();
                rtInfo.put('id', rt.Id);
                rtInfo.put('developerName', rt.DeveloperName);
                rtInfo.put('label', rt.Name);
                result.add(rtInfo);
            }
            
            return result;
        } catch (Exception e) {
            System.debug('Error in getAvailableRecordTypes: ' + e.getMessage());
            throw new AuraHandledException('Error getting record types: ' + e.getMessage());
        }
    }

    // Esegue un rollback dei campi cambiati nel caso in cui ci sia un errore di sincronizzazione
    @AuraEnabled
    public static Boolean rollbackAccountChanges(Id accountId, Boolean convertBackToProspect, String originalData) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!hasRequiredPermissions()) {
                throw new AuraHandledException('Insufficient access to required objects');
            }
            
            Account acc = getAccountForRollback(accountId);
            Map<String, Object> originalFields = parseOriginalData(originalData);
            
            if (convertBackToProspect) {
                convertToProspect(acc);
            }
            
            restoreAccountFields(acc, originalFields);
            update acc;
            
            return true;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error in rollback: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error during rollback: ' + e.getMessage());
        }
    }
    
    private static Boolean hasRequiredPermissions() {
        return Schema.sObjectType.Account.isUpdateable() && Schema.sObjectType.RecordType.isAccessible();
    }
    
    private static Account getAccountForRollback(Id accountId) {
        return Database.query(buildQueryWithAllFields('Account') + ' WHERE Id = :accountId LIMIT 1');
    }
    
    private static Map<String, Object> parseOriginalData(String originalData) {
        if (String.isBlank(originalData)) {
            return new Map<String, Object>();
        }
        
        try {
            Object deserializedData = JSON.deserializeUntyped(originalData);
            return deserializedData instanceof Map<String, Object> ? 
                (Map<String, Object>)deserializedData : new Map<String, Object>();
        } catch (Exception e) {
            System.debug('Error parsing original data: ' + e.getMessage());
            return new Map<String, Object>();
        }
    }
    
    public static void convertToProspect(Account acc) {
        if (acc.RecordTypeDeveloperName__c == LBR_Utils.ACC_RECORD_TYPE_PROSPECT) {
            return;
        }
        
        List<RecordType> prospectRTs = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Account' 
            AND (DeveloperName = :LBR_Utils.ACC_RECORD_TYPE_PROSPECT OR Name = :LBR_Utils.ACC_RECORD_TYPE_PROSPECT)
            AND IsActive = true 
            LIMIT 1
        ];
        
        if (prospectRTs.isEmpty()) {
            prospectRTs = [
                SELECT Id FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND (DeveloperName LIKE :('%' + LBR_Utils.ACC_RECORD_TYPE_PROSPECT + '%') OR 
                     Name LIKE :('%' + LBR_Utils.ACC_RECORD_TYPE_PROSPECT + '%'))
                AND IsActive = true 
                LIMIT 1
            ];
        }
        
        if (!prospectRTs.isEmpty()) {
            acc.RecordTypeId = prospectRTs[0].Id;
        }
    }
    
    public static void restoreAccountFields(Account acc, Map<String, Object> originalFields) {
        if (originalFields.isEmpty()) {
            return;
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        
        for (String fieldName : originalFields.keySet()) {
            if (isFieldRestorable(fieldName, fieldMap)) {
                acc.put(fieldName, originalFields.get(fieldName));
            }
        }
    }
    
    public static Boolean isFieldRestorable(String fieldName, Map<String, Schema.SObjectField> fieldMap) {
        if (fieldName == LBR_Utils.FIELD_ID || fieldName == LBR_Utils.FIELD_RECORD_TYPE_ID || 
            fieldName == LBR_Utils.FIELD_RECORD_TYPE_DEV_NAME || 
            fieldName.startsWith(LBR_Utils.FIELD_SYSTEM_PREFIX) || fieldName.endsWith(LBR_Utils.FIELD_PERSON_ACCOUNT_SUFFIX)) {
            return false;
        }
        
        if (!fieldMap.containsKey(fieldName)) {
            return false;
        }
        
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
        return dfr.isUpdateable();
    }

    @AuraEnabled
    public static String startTestSync(Id recordId, Boolean simulateError) {
        try {
            System.debug('Starting sync process for Opportunity ID: ' + recordId);
            
            // Forza un errore per scopi di test se richiesto
            if (simulateError) {
                System.debug('Simulating a sync error for testing');
                throw new AuraHandledException('This is a simulated error to test rollback functionality');
            }
            
            return 'Synchronization completed successfully';
        } catch (Exception e) {
            System.debug('Error in startSync: ' + e.getMessage());
            throw new AuraHandledException('Error during synchronization: ' + e.getMessage());
        }
    }
    
    // Recupera l'account dall'opportunità
    private static Account getAccountFromOpportunity(Opportunity opp) {
        Id accId = opp.AccountId;
        string query = buildQueryWithAllFields('Account') + ' WHERE Id = :accId';
        Account acc = Database.query(query);
        return acc;
    }

    // Recupera l'opportunità dall'offerta
    private static Opportunity getOppFromOffer(Id offerId) {
        QuoteCustom__c offer = getOffer(offerId);

        // Controlla se l'offerta ha un'opportunità collegata
        if (offer.Opportunity__c == null) {
            return null;
        }

        Id oppId = offer.Opportunity__c;
        string query = buildQueryWithAllFields('Opportunity') + ' WHERE Id = :oppId';
        Opportunity opp = Database.query(query);
        return opp;
    }

    // Metodo per assemblare una query stringa con tutti i campi dell'oggetto in questione
    private static String buildQueryWithAllFields(String objectName) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();

        // Crea la lista con tutti i campi
        List<String> fieldNames = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            if (fieldName != LBR_Utils.FIELD_RECORD_TYPE_ID && !fieldName.endsWith(LBR_Utils.FIELD_PERSON_ACCOUNT_SUFFIX)) {
                fieldNames.add(fieldName);
            }
        }

        return 'SELECT ' + String.join(fieldNames, ', ') + ' FROM ' + objectName;
    }

    @AuraEnabled
    public static Boolean hasExistingClosedOffer(Id offerId) {
        try {
            if (!Schema.sObjectType.QuoteCustom__c.isAccessible()) {
                throw new AuraHandledException('Insufficient access to QuoteCustom__c object');
            }
            
            // Get the opportunity from the offer
            QuoteCustom__c currentOffer = getOffer(offerId);
            if (currentOffer == null || currentOffer.Opportunity__c == null) {
                return false;
            }
            
            // Query for other offers in the same opportunity with status '3'
            List<QuoteCustom__c> existingOffers = [
                SELECT Id 
                FROM QuoteCustom__c 
                WHERE Opportunity__c = :currentOffer.Opportunity__c 
                AND Id != :offerId 
                AND OfferStatus__c = :LBR_Utils.OFFER_STATUS_TOTALMENTE_ORDINATO
                LIMIT 1
            ];
            
            return !existingOffers.isEmpty();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}