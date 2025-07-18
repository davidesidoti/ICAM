import { LightningElement, wire, track } from 'lwc';
import startSync from '@salesforce/apex/SDG_ReST_RunSyncComponent.startSync';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LwcRunSync extends LightningElement {

    @track risposta;
    @track errorMsg;
    @track syncStarted = false;

    handleStartSync(){
        this.syncStarted = true;
        startSync()
        .then(result =>{
            this.risposta = result;
            if(this.risposta == 200){ //sync avviata
                const event = new ShowToastEvent({
                    title : 'OK',
                    message : 'Sync avviata con successo.',
                    variant : 'success'
                });
                this.dispatchEvent(event);
                this.syncStarted = false;
            }
            else if(this.risposta == 409){ //sync già in esecuzione
                const event = new ShowToastEvent({
                    title : 'INFO',
                    message : 'Esiste già una sync in esecuzione attualmente, riprovare in un secondo momento.',
                    variant : 'info'
                });
                this.dispatchEvent(event);
                this.syncStarted = false;
            } else if(this.risposta == 503){ //servizio non disponibile in ambiente Sandbox
                const event = new ShowToastEvent({
                    title : 'WARNING',
                    message : 'Errore, servizio non disponibile in ambiente Sandbox.',
                    variant : 'warning'
                });
                this.dispatchEvent(event); 
                this.syncStarted = false;
            }else {
                const event = new ShowToastEvent({ //altro errore
                    title : 'ERROR',
                    message : 'Errore: ' + this.risposta,
                    variant : 'error'
                });
                this.dispatchEvent(event); 
                this.syncStarted = false;
            }
            })
        .catch(error =>{
            this.errorMsg = error;
            const event = new ShowToastEvent({ // unhandled error
                title : 'ERROR',
                message : 'Unhandled error: ' + this.errorMsg,
                variant : 'error'
            });
            this.dispatchEvent(event);
            this.syncStarted = false;
        })
    }
}