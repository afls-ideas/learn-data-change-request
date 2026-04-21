import { LightningElement, api, wire } from 'lwc';
import getDCRsForAccount from '@salesforce/apex/DCROverviewController.getDCRsForAccount';

const COLUMNS = [
    { label: 'Name', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
    { label: 'Status', fieldName: 'Status', cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Operation', fieldName: 'OperationType' },
    { label: 'Validation', fieldName: 'ValidationType' },
    { label: 'Changed Record', fieldName: 'changedObjectLabel' },
    { label: 'Created By', fieldName: 'createdByName' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date',
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
    }
];

const STATUS_CLASSES = {
    Approved: 'slds-text-color_success',
    Rejected: 'slds-text-color_error',
    NotProcessed: 'slds-text-color_weak',
    Failed: 'slds-text-color_error'
};

const OBJECT_LABELS = {
    '0cm': 'Healthcare Provider',
    '0cH': 'Contact Point Address',
    '0cG': 'Contact Point Phone',
    '0cF': 'Contact Point Email',
    '07g': 'Business License',
    '0c4': 'Provider Affiliation',
    '001': 'Account'
};

export default class LscMobileInline_DCR_Overview extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    dcrs = [];
    error;
    isLoading = true;

    @wire(getDCRsForAccount, { accountId: '$recordId' })
    wiredDCRs({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.dcrs = data.map(dcr => ({
                ...dcr,
                recordUrl: `/${dcr.Id}`,
                createdByName: dcr.CreatedBy?.Name,
                statusClass: STATUS_CLASSES[dcr.Status] || '',
                changedObjectLabel: this.getObjectLabel(dcr.DataChangeRecordIdentifier)
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Error loading DCRs';
            this.dcrs = [];
        }
    }

    getObjectLabel(recordId) {
        if (!recordId) return '';
        const prefix = recordId.substring(0, 3);
        return OBJECT_LABELS[prefix] || prefix;
    }

    get hasDCRs() {
        return this.dcrs.length > 0;
    }

    get dcrCount() {
        return this.dcrs.length;
    }

    get cardTitle() {
        const count = this.dcrs.length;
        return `Data Change Requests (${count})`;
    }
}
