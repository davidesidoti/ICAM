import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getOffer from '@salesforce/apex/LBR_AcceptOffer_Handler.getOffer';
import shouldDisplayLWC from '@salesforce/apex/LBR_AcceptOffer_Handler.shouldDisplayLWC';
import isOpportunityRelatedToProspect from '@salesforce/apex/LBR_AcceptOffer_Handler.isOpportunityRelatedToProspect';
import getAccountFromOffer from '@salesforce/apex/LBR_AcceptOffer_Handler.getAccountFromOffer';
import updateAccount from '@salesforce/apex/LBR_AcceptOffer_Handler.updateAccount';
import convertProspectToClient from '@salesforce/apex/LBR_AcceptOffer_Handler.convertProspectToClient';
import getAvailableRecordTypes from '@salesforce/apex/LBR_AcceptOffer_Handler.getAvailableRecordTypes';
import rollbackAccountChanges from '@salesforce/apex/LBR_AcceptOffer_Handler.rollbackAccountChanges';
// import startSync from '@salesforce/apex/SDG_ReST_OnDemandSync_Handler.startSync';
import startTestSync from '@salesforce/apex/LBR_AcceptOffer_Handler.startTestSync';
import startSync from '@salesforce/apex/SDG_ReST_OnDemandOfferSync_Handler.startSync';
import updateOpportunityStage from '@salesforce/apex/LBR_AcceptOffer_Handler.updateOpportunityStage';
import rollbackOpportunityStage from '@salesforce/apex/LBR_AcceptOffer_Handler.rollbackOpportunityStage';
import updateOfferStatus from '@salesforce/apex/LBR_AcceptOffer_Handler.updateOfferStatus';
import rollbackOfferStatus from '@salesforce/apex/LBR_AcceptOffer_Handler.rollbackOfferStatus';
import getConstants from '@salesforce/apex/LBR_Utils.getConstants';
import hasExistingClosedOffer from '@salesforce/apex/LBR_AcceptOffer_Handler.hasExistingClosedOffer';

export default class LwcAcceptOfferFromOpportunity extends NavigationMixin (LightningElement) {
    @api recordId;
    showLWC = false;
    isOppRelatedToProspect = false;
    acceptanceStarted = false;
    originalOffer;
    originalAccountData;
    originalOpportunityStage;
    originalOfferStatus;
    accountData;
    error;
    constants;
    
    // Proprietà di controllo del modale
    showProspectModal = false;
    isLoading = false;

    connectedCallback() {
        this.loadConstants();
    }

    async loadConstants() {
        try {
            this.constants = await getConstants();
        } catch (error) {
            console.error('Error loading constants:', error);
        }
    }

    // Controlla se il LWC deve essere visibile o meno
    @wire(shouldDisplayLWC, { offerId: '$recordId' })
    wiredLWCVisibility({ error, data }) {
        if (data) {
            this.showLWC = data;
        } else if (error) {
            this.error = error;
            this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', 'Error determining LWC visibility: ' + error.body.message, this.constants?.TOAST_TYPE_ERROR || 'error');
            console.error('Error determining LWC visibility: ', error);
        }
    }

    // Controlla se l'account a cui è collegata l'opportunità è di tipo prospect
    @wire(isOpportunityRelatedToProspect, { offerId: '$recordId' })
    wiredOppRelatedToProspect({ error, data }) {
        if (data) {
            this.isOppRelatedToProspect = data;
        } else if (error) {
            this.error = error;
            this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', 'Error determining if the opportunity is related to a prospect account: ' + error.body.message, this.constants?.TOAST_TYPE_ERROR || 'error');
            console.error('Error determining if the opportunity is related to a prospect account: ', error);
        }
    }

    // Avvia il processo di accettazione dell'offerta
    handleStartOfferAcceptance() {
        this.isLoading = true;
        this.acceptanceStarted = true;
        console.log('Started handling Offer acceptance');

        // First check for existing closed offers
        hasExistingClosedOffer({ offerId: this.recordId })
            .then(hasClosedOffer => {
                if (hasClosedOffer) {
                    this.showToast(
                        this.constants?.TOAST_TITLE_WARNING || 'Warning',
                        'An offer has already been accepted for this opportunity.',
                        this.constants?.TOAST_TYPE_WARNING || 'warning'
                    );
                    this.isLoading = false;
                    this.acceptanceStarted = false;
                    return null;
                }
                return getOffer({ offerId: this.recordId });
            })
            .then(result => {
                if (!result) {
                    this.isLoading = false;
                    this.acceptanceStarted = false;
                    return null;
                }
                
                this.originalOffer = result;
                
                // Memorizza lo stato originale dell'opportunità per un eventuale ripristino
                if (result.Opportunity__r && result.Opportunity__r.StageName) {
                    this.originalOpportunityStage = result.Opportunity__r.StageName;
                } else {
                    // Se non disponibile, memorizza il valore predefinito corrispondente al controllo shouldDisplayLWC
                    this.originalOpportunityStage = this.constants?.OPP_STAGE_PROPOSAL || 'Proposal';
                }
                
                // Memorizza lo stato originale dell'offerta per un eventuale ripristino
                this.originalOfferStatus = result.OfferStatus__c;
                console.log('Original offer status:', this.originalOfferStatus);
                
                // Recupera i dati dell'account
                return getAccountFromOffer({ offerId: this.recordId });
            })
            .then(accountResult => {
                if (!accountResult) {
                    this.isLoading = false;
                    this.acceptanceStarted = false;
                    return;
                }
                
                this.accountData = accountResult;
                // Memorizza i dati originali dell'account
                this.originalAccountData = {
                    Id: accountResult.Id,
                    Name: accountResult.Name,
                    Phone: accountResult.Phone || null,
                    BillingStreet: accountResult.BillingStreet || null,
                    BillingCity: accountResult.BillingCity || null,
                    BillingPostalCode: accountResult.BillingPostalCode || null,
                    BillingCountry: accountResult.BillingCountry || null,
                    RecordTypeDeveloperName__c: accountResult.RecordTypeDeveloperName__c,
                };
                Object.keys(accountResult).forEach(key => {
                    if (key !== this.constants?.FIELD_ATTRIBUTES && !Object.prototype.hasOwnProperty.call(this.originalAccountData, key)) {
                        this.originalAccountData[key] = accountResult[key];
                    }
                });
                
                // Logica decisionale: se prospect, mostra modale; se cliente, procedi direttamente
                if (this.isOppRelatedToProspect) {
                    this.showProspectModal = true;
                    this.isLoading = false;
                } else {
                    // Se l'account è già un cliente, procedi con l'aggiornamento dell'opportunità e dell'offerta
                    this.processOpportunityAndSync();
                }
            })
            .catch(error => {
                if (error.message === 'Offer already accepted') {
                    return; // Already handled the warning toast
                }
                
                this.error = error;
                this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', 'Error retrieving data: ' + error.body.message, this.constants?.TOAST_TYPE_ERROR || 'error');
                console.error('Error in offer acceptance process: ', error);
                this.isLoading = false;
                this.acceptanceStarted = false;
            });
    }
    
    // Gestisce la chiusura/annullamento del modale
    handleModalCancel() {
        this.showProspectModal = false;
        this.acceptanceStarted = false;
        this.isLoading = false;
    }
    
    // Gestisce l'invio del form dal modale
    handleModalSubmit(event) {
        event.preventDefault(); // Ferma l'invio predefinito del form
        this.isLoading = true;
        
        // Ottieni i dati del form
        const fields = event.detail.fields;
        
        // Crea una copia sicura dei campi senza campi relativi al record type
        const safeFields = { ...fields };
        // Rimuovi eventuali campi che potrebbero causare problemi
        delete safeFields[this.constants?.FIELD_RECORD_TYPE_ID];
        delete safeFields[this.constants?.FIELD_RECORD_TYPE_DEV_NAME];
        
        // Prima, controlla i record type disponibili (per debug)
        getAvailableRecordTypes()
            .then(() => {
                // Passo 1: Aggiorna i campi dell'account
                return updateAccount({ accountId: this.accountData.Id, accountFields: safeFields });
            })
            .then(() => {
                console.log('Account fields updated successfully.');
                this.showToast(this.constants?.TOAST_TITLE_SUCCESS || 'Success', this.constants?.TOAST_MSG_ACCOUNT_UPDATED || 'Account information updated successfully', this.constants?.TOAST_TYPE_SUCCESS || 'success');
                
                // Passo 2: Converti da Prospect a Cliente (solo se necessario)
                if (this.isOppRelatedToProspect) {
                    return convertProspectToClient({ accountId: this.accountData.Id });
                }
                return Promise.resolve(false); // Salta la conversione se già cliente
            })
            .then(converted => {
                console.log('Account conversion result:', converted);
                
                if (converted) {
                    this.showToast(this.constants?.TOAST_TITLE_SUCCESS || 'Success', this.constants?.TOAST_MSG_ACCOUNT_CONVERTED || 'Account converted to Client successfully', this.constants?.TOAST_TYPE_SUCCESS || 'success');
                }
                
                // Chiudi modale
                this.showProspectModal = false;
                
                // Procedi con l'aggiornamento dell'opportunità e dell'offerta
                this.processOpportunityAndSync();
            })
            .catch(error => {
                this.error = error;
                let errorMsg = 'Error processing account: ';
                
                if (error.body && error.body.message) {
                    errorMsg += error.body.message;
                } else {
                    errorMsg += JSON.stringify(error);
                }
                
                this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', errorMsg, this.constants?.TOAST_TYPE_ERROR || 'error');
                console.error('Error processing account: ', error);
                this.isLoading = false;
            });
    }
    
    // Metodo per aggiornare lo stato dell'opportunità e dell'offerta, poi procedere con la sincronizzazione se necessario
    processOpportunityAndSync() {
        this.isLoading = true;
        
        // Ottieni l'ID dell'opportunità dai dati dell'offerta
        const oppId = this.originalOffer.Opportunity__c;
        if (!oppId) {
            this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', this.constants?.ERROR_MSG_NO_OPP_ID || 'Cannot find opportunity ID in the offer data', this.constants?.TOAST_TYPE_ERROR || 'error');
            this.isLoading = false;
            return;
        }
        
        console.log('Updating opportunity stage to Closed Won');
        
        // Aggiorna lo stato dell'opportunità a Closed Won
        updateOpportunityStage({ 
            oppId: oppId, 
            newStage: this.constants?.OPP_STAGE_CLOSED_WON || 'Closed Won'
        })
        .then(() => {
            console.log('Opportunity stage updated successfully');
            this.showToast(this.constants?.TOAST_TITLE_SUCCESS || 'Success', this.constants?.TOAST_MSG_OPP_MOVED || 'Opportunity moved to Closed Won stage', this.constants?.TOAST_TYPE_SUCCESS || 'success');
            
            // Ora aggiorna lo stato dell'offerta
            console.log('Updating offer status to Totalmente ordinato');
            return updateOfferStatus({
                offerId: this.recordId,
                newStatus: this.constants?.OFFER_STATUS_TOTALMENTE_ORDINATO || '3'
            });
        })
        .then(() => {
            console.log('Offer status updated successfully');
            this.showToast(this.constants?.TOAST_TITLE_SUCCESS || 'Success', this.constants?.TOAST_MSG_OFFER_UPDATED || 'Offer status updated to Totalmente ordinato', this.constants?.TOAST_TYPE_SUCCESS || 'success');
            
            startSync({ 
                quoteId: this.recordId
            })
            .then(result =>{

                this.syncStarted = false;
                
                this.risposta = result;
                console.log('risposta: ', this.risposta);
                if(this.risposta !== null){
                    console.log('risposta.title: ', this.risposta.title);
                    console.log('risposta.message: ', this.risposta.message);
                    console.log('risposta.variant: ', this.risposta.variant);
                    console.log('risposta.mode: ', this.risposta.mode);
                    console.log('risposta.recordId: ', this.risposta.recordId);
                }
                
                if(this.risposta.recordId !== null){
                    this[NavigationMixin.GenerateUrl]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.risposta.recordId,
                            actionName: 'view'
                        }
                    })
                    .then((url) => {
                        const event = new ShowToastEvent({ //sync avviata
                            title : this.risposta.title,
                            message : this.risposta.message,
                            variant : this.risposta.variant,
                            mode: this.risposta.mode,
                            messageData: [
                                {
                                    url: url,
                                    label: this.risposta.recordName,
                                }
                            ]
                        });
                        this.dispatchEvent(event);
                    });
                }
                else{
                    const event = new ShowToastEvent({ //sync avviata
                        title : this.risposta.title,
                        message : this.risposta.message,
                        variant : this.risposta.variant,
                        mode: this.risposta.mode,
                    });
                    this.dispatchEvent(event);
                }
            })
            .catch(error =>{
                console.log(error);
                this.errorMsg = error;
                const event = new ShowToastEvent({ //unhandled error
                    title : 'ERROR',
                    message : 'Unhandled error: ' + this.errorMsg,
                    variant : 'error',
                    mode: 'sticky'
                });
                this.dispatchEvent(event);
                this.syncStarted = false;
            })

            // Controlla se l'account è già un cliente
            if (!this.isOppRelatedToProspect) {
                // Se l'account è già un cliente, completa il processo senza sincronizzazione
                console.log('Account is already a customer. Skipping sync process.');
                this.showToast(this.constants?.TOAST_TITLE_SUCCESS || 'Success', this.constants?.TOAST_MSG_PROCESS_COMPLETED || 'Offer acceptance process completed successfully', this.constants?.TOAST_TYPE_SUCCESS || 'success');
                this.isLoading = false;
                this.acceptanceStarted = false;
            } else {
                // Se l'account era un prospect (ora convertito a cliente), procedi con la sincronizzazione
                console.log('Account was converted from Prospect to Client. Proceeding with sync.');
                this.syncAndFinish();
            }
        })
        .catch(error => {
            this.error = error;
            let errorMsg = 'Error updating records: ';
            
            if (error.body && error.body.message) {
                errorMsg += error.body.message;
            } else {
                errorMsg += JSON.stringify(error);
            }
            
            this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', errorMsg, this.constants?.TOAST_TYPE_ERROR || 'error');
            console.error('Error in update process: ', error);
            this.isLoading = false;
            this.acceptanceStarted = false;
        });
    }
    
    // Questa funzione gestirà la sincronizzazione finale
    syncAndFinish() {
        this.isLoading = true;
        
        // Ottieni l'ID dell'opportunità dai dati dell'offerta
        const oppId = this.originalOffer.Opportunity__c;
        if (!oppId) {
            this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', this.constants?.ERROR_MSG_NO_OPP_ID || 'Cannot find opportunity ID in the offer data', this.constants?.TOAST_TYPE_ERROR || 'error');
            this.isLoading = false;
            return;
        }
        
        console.log('Starting sync process.');
        
        // Memorizza lo stato originale dell'account, dell'opportunità e dell'offerta per un eventuale ripristino
        const originalAccountState = {
            wasProspect: this.isOppRelatedToProspect,
            accountId: this.accountData.Id,
            originalData: this.originalAccountData
        };
        
        const originalOpportunityState = {
            opportunityId: oppId,
            originalStage: this.originalOpportunityStage
        };
        
        const originalOfferState = {
            offerId: this.recordId,
            originalStatus: this.originalOfferStatus
        };
        
        // Avvia sincronizzazione con SAGE
        startTestSync({
            recordId: oppId,
            simulateError: false
        })
        .then(result => {
            console.log('Sync completed successfully: ', result);
            this.showToast(this.constants?.TOAST_TITLE_SUCCESS || 'Success', this.constants?.TOAST_MSG_PROCESS_COMPLETED || 'Offer acceptance process completed successfully', this.constants?.TOAST_TYPE_SUCCESS || 'success');
            this.isLoading = false;
            this.acceptanceStarted = false;
        })
        .catch(error => {
            console.error('Error in sync process:', error);
            
            // Prepara il messaggio di errore
            let errorMsg = this.constants?.ERROR_MSG_SYNC_FAILED || 'Error during synchronization. ';
            if (error.body && error.body.message) {
                errorMsg += error.body.message;
            } else if (typeof error === 'string') {
                errorMsg += error;
            } else {
                errorMsg += this.constants?.ERROR_MSG_UNEXPECTED || 'An unexpected error occurred.';
            }
                
            this.showToast(this.constants?.TOAST_TITLE_ERROR || 'Error', errorMsg, this.constants?.TOAST_TYPE_ERROR || 'error');
                
            // Avvia processo di ripristino
            let rollbackPromises = [];
            
            // Rollback all changes
            this.showToast(this.constants?.TOAST_TITLE_INFO || 'Info', this.constants?.TOAST_MSG_ROLLBACK_STARTED || 'Attempting to rollback all changes...', this.constants?.TOAST_TYPE_INFO || 'info');
            
            // Ripristina lo stato dell'opportunità
            rollbackPromises.push(
                rollbackOpportunityStage({
                    oppId: originalOpportunityState.opportunityId, 
                    originalStage: originalOpportunityState.originalStage
                })
            );
            
            // Ripristina lo stato dell'offerta
            rollbackPromises.push(
                rollbackOfferStatus({
                    offerId: originalOfferState.offerId,
                    originalStatus: originalOfferState.originalStatus
                })
            );
            
            // Se l'account è stato convertito, ripristinalo
            if (originalAccountState.wasProspect) {
                rollbackPromises.push(
                    rollbackAccountChanges({
                        accountId: originalAccountState.accountId,
                        convertBackToProspect: true,
                        originalData: JSON.stringify(this.originalAccountData)
                    })
                );
            }
            
            // Esegui tutti i ripristini
            Promise.all(rollbackPromises)
            .then(results => {
                console.log('Rollback completed:', results);
                this.showToast(this.constants?.TOAST_TITLE_INFO || 'Info', this.constants?.TOAST_MSG_ROLLBACK_COMPLETED || 'Changes have been rolled back', this.constants?.TOAST_TYPE_INFO || 'info');
            })
            .catch(rollbackError => {
                console.error('Error during rollback:', rollbackError);
                this.showToast(this.constants?.TOAST_TITLE_WARNING || 'Warning', this.constants?.TOAST_MSG_ROLLBACK_FAILED || 'Could not rollback all changes automatically', this.constants?.TOAST_TYPE_WARNING || 'warning');
            })
            .finally(() => {
                this.isLoading = false;
                this.acceptanceStarted = false;
            });
        });
    }
    
    // Metodo di supporto per mostrare le notifiche toast
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}