import { LightningElement, api, wire } from 'lwc';
import getDCRsForAccount from '@salesforce/apex/DCROverviewController.getDCRsForAccount';

const FIELD_LABELS = {
    providertype: 'Provider Type',
    professionaltitle: 'Professional Title',
    name: 'Name',
    phone: 'Phone',
    fax: 'Fax',
    persongender: 'Gender',
    personmobilephone: 'Mobile Phone',
    personbirthdate: 'Birthdate',
    address: 'Address',
    status: 'Status',
    totallicensedbeds: 'Total Licensed Beds',
    providerclass: 'Provider Class',
    specialtyid: 'Specialty',
    role: 'Role',
    effectivestartdate: 'Start Date',
    effectiveenddate: 'End Date'
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
    dcrs = [];
    error;
    isLoading = true;
    expandedDcrId = null;

    @wire(getDCRsForAccount, { accountId: '$recordId' })
    wiredDCRs({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.dcrs = data.map(dcr => this.parseDCR(dcr));
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Error loading DCRs';
            this.dcrs = [];
        }
    }

    parseDCR(dcr) {
        let changes = [];
        let objectLabel = '';

        if (dcr.DataChangeInformation) {
            try {
                const info = JSON.parse(dcr.DataChangeInformation);
                const oldData = info.oldData || {};
                const newData = info.newData || {};
                const allKeys = new Set([...Object.keys(oldData), ...Object.keys(newData)]);

                allKeys.forEach(key => {
                    if (key === 'id' || key === 'accountid') return;
                    const oldVal = oldData[key];
                    const newVal = newData[key];
                    if (oldVal !== newVal) {
                        changes.push({
                            key,
                            label: FIELD_LABELS[key] || key,
                            oldValue: oldVal == null ? '(empty)' : String(oldVal),
                            newValue: newVal == null ? '(empty)' : String(newVal)
                        });
                    }
                });
            } catch (e) { /* ignore parse errors */ }
        }

        if (dcr.DataChangeRecordIdentifier) {
            const prefix = dcr.DataChangeRecordIdentifier.substring(0, 3);
            objectLabel = OBJECT_LABELS[prefix] || prefix;
        }

        return {
            id: dcr.Id,
            name: dcr.Name,
            status: dcr.Status,
            operationType: dcr.OperationType,
            validationType: dcr.ValidationType,
            objectLabel,
            createdByName: dcr.CreatedBy?.Name,
            createdDate: dcr.CreatedDate,
            changes,
            changeCount: changes.length,
            recordUrl: `/${dcr.Id}`,
            statusVariant: this.getStatusVariant(dcr.Status),
            statusLabel: this.getStatusLabel(dcr.Status),
            isPending: dcr.Status === 'NotProcessed'
        };
    }

    getStatusVariant(status) {
        const map = {
            NotProcessed: 'warning',
            Approved: 'success',
            Rejected: 'error',
            Failed: 'error',
            Qualified: 'success',
            Processed: 'success',
            NotQualified: 'warning',
            Retry: 'warning'
        };
        return map[status] || 'default';
    }

    getStatusLabel(status) {
        const map = {
            NotProcessed: 'Pending',
            Approved: 'Approved',
            Rejected: 'Rejected',
            Failed: 'Failed',
            Qualified: 'Qualified',
            Processed: 'Processed',
            NotQualified: 'Not Qualified',
            Retry: 'Retry'
        };
        return map[status] || status;
    }

    handleToggle(event) {
        const dcrId = event.currentTarget.dataset.id;
        this.expandedDcrId = this.expandedDcrId === dcrId ? null : dcrId;
    }

    get processedDcrs() {
        return this.dcrs.map(dcr => {
            const isExpanded = dcr.id === this.expandedDcrId;
            return {
                ...dcr,
                isExpanded,
                hasChanges: dcr.changes.length > 0,
                chevronIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    get hasDCRs() {
        return this.dcrs.length > 0;
    }

    get noResults() {
        return !this.isLoading && !this.hasDCRs;
    }

    get pendingCount() {
        return this.dcrs.filter(d => d.isPending).length;
    }

    get hasPending() {
        return this.pendingCount > 0;
    }

    get cardTitle() {
        return 'Data Change Requests';
    }

    get summaryText() {
        const total = this.dcrs.length;
        const pending = this.pendingCount;
        if (pending > 0) {
            return `${pending} pending of ${total} total`;
        }
        return `${total} total`;
    }
}
