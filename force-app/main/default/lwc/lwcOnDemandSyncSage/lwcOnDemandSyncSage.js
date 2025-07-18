import { LightningElement, api, track } from 'lwc';
import startSync from '@salesforce/apex/SDG_ReST_OnDemandSync_Handler.startSync';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class LwcOnDemandSyncSage extends NavigationMixin (LightningElement) {

    @api recordId;
    @track risposta;
    @track errorMsg;
    @track syncStarted = false;

    handleStartSync(){

        //console.log(recordId);
        this.syncStarted = true;
        startSync({ 
            recordId: this.recordId
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
    }
}