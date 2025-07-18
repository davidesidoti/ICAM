public with sharing class LBR_Utils {
    // Nomi degli stadi dell'opportunità
    public static final String OPP_STAGE_PROPOSAL = 'Proposal';
    public static final String OPP_STAGE_NEW = 'New';
    public static final String OPP_STAGE_LONG_TIME_PENDING = 'Long Time Pending';
    public static final String OPP_STAGE_TEMPORARY_PENDING = 'Temporary Pending';
    public static final String OPP_STAGE_IN_PENDING = 'In Pending';
    public static final String OPP_STAGE_APERTA_POSTICIPATA = 'Aperta Posticipata';
    public static final String OPP_STAGE_CLOSED_LOST = 'Closed Lost';
    public static final String OPP_STAGE_CLOSED_WON = 'Closed Won';
    
    // Nomi dei tipi di record dell'account
    public static final String ACC_RECORD_TYPE_PROSPECT = 'Prospect';
    public static final String ACC_RECORD_TYPE_CLIENT = 'Client';
    public static final String ACC_RECORD_TYPE_CUSTOMER = 'Customer';
    
    // Nomi dei campi di sistema
    public static final String FIELD_RECORD_TYPE_ID = 'RecordTypeId';
    public static final String FIELD_RECORD_TYPE_DEV_NAME = 'RecordTypeDeveloperName__c';
    public static final String FIELD_ID = 'Id';
    public static final String FIELD_SYSTEM_PREFIX = 'System';
    public static final String FIELD_PERSON_ACCOUNT_SUFFIX = '__pc';
    public static final String FIELD_ATTRIBUTES = 'attributes';
    public static final String FIELD_NAME = 'Name';
    public static final String FIELD_PHONE = 'Phone';
    public static final String FIELD_BILLING_STREET = 'BillingStreet';
    public static final String FIELD_BILLING_CITY = 'BillingCity';
    public static final String FIELD_BILLING_POSTAL_CODE = 'BillingPostalCode';
    public static final String FIELD_BILLING_COUNTRY = 'BillingCountry';
    
    // Valori dello stato dell'offerta
    public static final String OFFER_STATUS_TOTALMENTE_ORDINATO = '3';
    
    // Tipi di messaggi toast
    public static final String TOAST_TYPE_SUCCESS = 'success';
    public static final String TOAST_TYPE_ERROR = 'error';
    public static final String TOAST_TYPE_INFO = 'info';
    public static final String TOAST_TYPE_WARNING = 'warning';
    
    // Titoli dei messaggi toast
    public static final String TOAST_TITLE_SUCCESS = 'Success';
    public static final String TOAST_TITLE_ERROR = 'Error';
    public static final String TOAST_TITLE_INFO = 'Info';
    public static final String TOAST_TITLE_WARNING = 'Warning';
    
    // Messaggi toast
    public static final String TOAST_MSG_ACCOUNT_UPDATED = 'Account information updated successfully';
    public static final String TOAST_MSG_ACCOUNT_CONVERTED = 'Account converted to Client successfully';
    public static final String TOAST_MSG_OPP_MOVED = 'Opportunity moved to Closed Won stage';
    public static final String TOAST_MSG_OFFER_UPDATED = 'Offer status updated to Totalmente ordinato';
    public static final String TOAST_MSG_PROCESS_COMPLETED = 'Offer acceptance process completed successfully';
    public static final String TOAST_MSG_ROLLBACK_STARTED = 'Attempting to rollback all changes...';
    public static final String TOAST_MSG_ROLLBACK_COMPLETED = 'Changes have been rolled back';
    public static final String TOAST_MSG_ROLLBACK_FAILED = 'Could not rollback all changes automatically';
    
    // Messaggi di errore
    public static final String ERROR_MSG_NO_OPP_ID = 'Cannot find opportunity ID in the offer data';
    public static final String ERROR_MSG_SYNC_FAILED = 'Error during synchronization. ';
    public static final String ERROR_MSG_UNEXPECTED = 'An unexpected error occurred.';

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getConstants() {
        Map<String, String> constants = new Map<String, String>();
        
        // Opportunity stages
        constants.put('OPP_STAGE_PROPOSAL', OPP_STAGE_PROPOSAL);
        constants.put('OPP_STAGE_NEW', OPP_STAGE_NEW);
        constants.put('OPP_STAGE_LONG_TIME_PENDING', OPP_STAGE_LONG_TIME_PENDING);
        constants.put('OPP_STAGE_TEMPORARY_PENDING', OPP_STAGE_TEMPORARY_PENDING);
        constants.put('OPP_STAGE_IN_PENDING', OPP_STAGE_IN_PENDING);
        constants.put('OPP_STAGE_APERTA_POSTICIPATA', OPP_STAGE_APERTA_POSTICIPATA);
        constants.put('OPP_STAGE_CLOSED_LOST', OPP_STAGE_CLOSED_LOST);
        constants.put('OPP_STAGE_CLOSED_WON', OPP_STAGE_CLOSED_WON);
        
        // Account record types
        constants.put('ACC_RECORD_TYPE_PROSPECT', ACC_RECORD_TYPE_PROSPECT);
        constants.put('ACC_RECORD_TYPE_CLIENT', ACC_RECORD_TYPE_CLIENT);
        constants.put('ACC_RECORD_TYPE_CUSTOMER', ACC_RECORD_TYPE_CUSTOMER);
        
        // Field names
        constants.put('FIELD_RECORD_TYPE_ID', FIELD_RECORD_TYPE_ID);
        constants.put('FIELD_RECORD_TYPE_DEV_NAME', FIELD_RECORD_TYPE_DEV_NAME);
        constants.put('FIELD_ID', FIELD_ID);
        constants.put('FIELD_SYSTEM_PREFIX', FIELD_SYSTEM_PREFIX);
        constants.put('FIELD_PERSON_ACCOUNT_SUFFIX', FIELD_PERSON_ACCOUNT_SUFFIX);
        constants.put('FIELD_ATTRIBUTES', FIELD_ATTRIBUTES);
        constants.put('FIELD_NAME', FIELD_NAME);
        constants.put('FIELD_PHONE', FIELD_PHONE);
        constants.put('FIELD_BILLING_STREET', FIELD_BILLING_STREET);
        constants.put('FIELD_BILLING_CITY', FIELD_BILLING_CITY);
        constants.put('FIELD_BILLING_POSTAL_CODE', FIELD_BILLING_POSTAL_CODE);
        constants.put('FIELD_BILLING_COUNTRY', FIELD_BILLING_COUNTRY);
        
        // Offer status
        constants.put('OFFER_STATUS_TOTALMENTE_ORDINATO', OFFER_STATUS_TOTALMENTE_ORDINATO);
        
        // Toast types
        constants.put('TOAST_TYPE_SUCCESS', TOAST_TYPE_SUCCESS);
        constants.put('TOAST_TYPE_ERROR', TOAST_TYPE_ERROR);
        constants.put('TOAST_TYPE_INFO', TOAST_TYPE_INFO);
        constants.put('TOAST_TYPE_WARNING', TOAST_TYPE_WARNING);
        
        // Toast titles
        constants.put('TOAST_TITLE_SUCCESS', TOAST_TITLE_SUCCESS);
        constants.put('TOAST_TITLE_ERROR', TOAST_TITLE_ERROR);
        constants.put('TOAST_TITLE_INFO', TOAST_TITLE_INFO);
        constants.put('TOAST_TITLE_WARNING', TOAST_TITLE_WARNING);
        
        // Toast messages
        constants.put('TOAST_MSG_ACCOUNT_UPDATED', TOAST_MSG_ACCOUNT_UPDATED);
        constants.put('TOAST_MSG_ACCOUNT_CONVERTED', TOAST_MSG_ACCOUNT_CONVERTED);
        constants.put('TOAST_MSG_OPP_MOVED', TOAST_MSG_OPP_MOVED);
        constants.put('TOAST_MSG_OFFER_UPDATED', TOAST_MSG_OFFER_UPDATED);
        constants.put('TOAST_MSG_PROCESS_COMPLETED', TOAST_MSG_PROCESS_COMPLETED);
        constants.put('TOAST_MSG_ROLLBACK_STARTED', TOAST_MSG_ROLLBACK_STARTED);
        constants.put('TOAST_MSG_ROLLBACK_COMPLETED', TOAST_MSG_ROLLBACK_COMPLETED);
        constants.put('TOAST_MSG_ROLLBACK_FAILED', TOAST_MSG_ROLLBACK_FAILED);
        
        // Error messages
        constants.put('ERROR_MSG_NO_OPP_ID', ERROR_MSG_NO_OPP_ID);
        constants.put('ERROR_MSG_SYNC_FAILED', ERROR_MSG_SYNC_FAILED);
        constants.put('ERROR_MSG_UNEXPECTED', ERROR_MSG_UNEXPECTED);
        
        return constants;
    }
}