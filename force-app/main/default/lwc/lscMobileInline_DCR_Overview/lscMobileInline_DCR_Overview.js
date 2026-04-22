import { LightningElement, api, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';

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

const RELATED_QUERY = gql`
    query GetRelatedRecords($accountId: ID) {
        uiapi {
            query {
                HealthcareProvider(
                    where: { AccountId: { eq: $accountId } }
                    first: 100
                ) {
                    edges { node { Id Name { value } } }
                }
                ContactPointAddress(
                    where: { ParentId: { eq: $accountId } }
                    first: 100
                ) {
                    edges { node { Id Name { value } } }
                }
                ContactPointPhone(
                    where: { ParentId: { eq: $accountId } }
                    first: 100
                ) {
                    edges { node { Id Name { value } } }
                }
                ContactPointEmail(
                    where: { ParentId: { eq: $accountId } }
                    first: 100
                ) {
                    edges { node { Id Name { value } } }
                }
                BusinessLicense(
                    where: { AccountId: { eq: $accountId } }
                    first: 100
                ) {
                    edges { node { Id Name { value } } }
                }
            }
        }
    }
`;

const DCR_QUERY = gql`
    query GetDCRs($ids: [String]) {
        uiapi {
            query {
                LifeSciDataChangeRequest(
                    where: { DataChangeRecordIdentifier: { in: $ids } }
                    orderBy: { CreatedDate: { order: DESC } }
                    first: 50
                ) {
                    edges {
                        node {
                            Id
                            Name { value }
                            Status { value }
                            DataChangeInformation { value }
                            DataChangeRecordIdentifier { value }
                            CreatedDate { value }
                            CreatedBy {
                                Name { value }
                            }
                        }
                    }
                }
            }
        }
    }
`;

export default class LscMobileInline_DCR_Overview extends LightningElement {
    @api recordId;
    @api mobileHeight = 200;
    _relatedIds = null;
    dcrs = [];
    isExpanded = false;
    error;

    get relatedVars() {
        if (!this.recordId) return undefined;
        return { accountId: this.recordId };
    }

    @wire(graphql, { query: RELATED_QUERY, variables: '$relatedVars' })
    handleRelatedRecords({ data, errors }) {
        if (data) {
            const ids = new Set([this.recordId]);
            const queries = data.uiapi.query;
            for (const key of Object.keys(queries)) {
                queries[key]?.edges?.forEach(edge => {
                    const id = edge.node?.Id;
                    if (id) ids.add(id);
                });
            }
            this._relatedIds = [...ids];
        } else if (errors) {
            this.error = 'Error loading related records';
        }
    }

    get dcrVars() {
        if (!this._relatedIds || this._relatedIds.length === 0) return undefined;
        return { ids: this._relatedIds };
    }

    @wire(graphql, { query: DCR_QUERY, variables: '$dcrVars' })
    handleDCRs({ data, errors }) {
        if (data) {
            this.dcrs = data.uiapi.query.LifeSciDataChangeRequest.edges.map(edge =>
                this.parseDCR(edge.node)
            );
        } else if (errors) {
            this.error = 'Error loading DCRs';
        }
    }

    parseDCR(node) {
        let changes = [];
        let objectLabel = '';
        const dataChangeInfo = node.DataChangeInformation?.value;
        const recordIdentifier = node.DataChangeRecordIdentifier?.value;

        if (dataChangeInfo) {
            try {
                const info = JSON.parse(dataChangeInfo);
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

        if (recordIdentifier) {
            const prefix = recordIdentifier.substring(0, 3);
            objectLabel = OBJECT_LABELS[prefix] || prefix;
        }

        return {
            id: node.Id,
            name: node.Name.value,
            status: node.Status?.value,
            objectLabel,
            createdByName: node.CreatedBy?.Name?.value,
            createdDate: node.CreatedDate?.value,
            changes,
            hasChanges: changes.length > 0,
            recordUrl: `/${node.Id}`,
            isPending: node.Status?.value === 'NotProcessed'
        };
    }

    handleToggleAll() {
        this.isExpanded = !this.isExpanded;
    }

    get pendingDcrs() {
        return this.dcrs.filter(d => d.isPending);
    }

    get pendingCount() {
        return this.pendingDcrs.length;
    }

    get hasPending() {
        return this.pendingCount > 0;
    }

    get pluralS() {
        return this.pendingCount === 1 ? '' : 's';
    }

    get toggleIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
}
