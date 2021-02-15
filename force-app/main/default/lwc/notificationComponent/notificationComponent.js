import { LightningElement, track } from 'lwc';
import retrieveItemsForTable from '@salesforce/apex/NotificationComponentController.retrieveItemsForTable';
import updateItemsFromTable from '@salesforce/apex/NotificationComponentController.updateItemsFromTable';

const columns = [
    {label: 'Дата события', fieldName: 'dateNotification', type: 'text'},
    {label: 'Сообщение', fieldName: 'message', type: 'text', initialWidth: 300},
    {label: 'ФИО', fieldName: 'patientName', type: 'text'},
    {label: 'Телефон', fieldName: 'patientPhone', type: 'phone'},
    {label: 'Больничный', fieldName: 'sickLeaveURL', type: 'url', typeAttributes: { 
        tooltip: { fieldName: 'sickLeaveURL'},  
        label: { fieldName: 'sickLeaveName'}}}
];

export default class NotificationComponent extends LightningElement {
    @track dataForTable;
    @track error;
    @track isDatatableLoading = true;
    @track isConfirmButtonDisabled = true;
    columns = columns;

    connectedCallback() {
        this.getItemsForTable();
    }

    updateTable() {
        this.getItemsForTable();
    }

    getItemsForTable() {
        this.initRecord();

        retrieveItemsForTable()
            .then(result => {
                this.dataForTable = result;
                this.isDatatableLoading = false;
            })
            .catch(error => {
                this.error = error.body.message;
                this.isDatatableLoading = false;
            });
    }

    getSelectedName(event) {
        const selectedRows = event.detail.selectedRows;
        this.isConfirmButtonDisabled = !selectedRows.length > 0;
    }

    confirmSelectedItems() {
        let selectRows = this.template.querySelector('lightning-datatable').getSelectedRows();
        if (selectRows && selectRows.length > 0) {
            this.initRecord();
            let selectRowsString = JSON.stringify(selectRows);

            updateItemsFromTable({notificationListJSON: selectRowsString})
                .then(result => {
                    this.updateTable();
                })
                .catch(error => {
                    this.error = error.body.message;
                    this.isDatatableLoading = false;
                });
        }
    }

    initRecord() {
        this.error = '';
        this.dataForTable = [];
        this.isDatatableLoading = true;
        this.isConfirmButtonDisabled = true;
    }
}