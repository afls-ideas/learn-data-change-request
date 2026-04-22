import { LightningElement, wire } from 'lwc';
import getCountries from '@salesforce/apex/DCRFieldManagerController.getCountries';
import getObjectDefinitions from '@salesforce/apex/DCRFieldManagerController.getObjectDefinitions';
import addManagedField from '@salesforce/apex/DCRFieldManagerController.addManagedField';
import removeManagedField from '@salesforce/apex/DCRFieldManagerController.removeManagedField';
import updateManagedField from '@salesforce/apex/DCRFieldManagerController.updateManagedField';
import addRecordTypeMapping from '@salesforce/apex/DCRFieldManagerController.addRecordTypeMapping';
import removeRecordTypeMapping from '@salesforce/apex/DCRFieldManagerController.removeRecordTypeMapping';
import addPersonaDef from '@salesforce/apex/DCRFieldManagerController.addPersonaDef';
import removePersonaDef from '@salesforce/apex/DCRFieldManagerController.removePersonaDef';
import getDcrRecordTypes from '@salesforce/apex/DCRFieldManagerController.getDcrRecordTypes';
import getProfiles from '@salesforce/apex/DCRFieldManagerController.getProfiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const OBJECT_ICONS = {
    Account: 'standard:account',
    HealthcareProvider: 'standard:care_request',
    HealthcareProviderSpecialty: 'standard:skill',
    HealthcareProviderNpi: 'standard:record',
    ContactPointAddress: 'standard:address',
    ContactPointPhone: 'standard:call',
    ContactPointEmail: 'standard:email',
    ContactPointSocial: 'standard:social',
    BusinessLicense: 'standard:contract',
    ProviderAffiliation: 'standard:relationship'
};

const CHANGE_UPDATE_OPTIONS = [
    { label: 'Do Not Apply Immediately', value: 'DoNotApplyChangesImmediately' },
    { label: 'Apply By Field', value: 'ApplyChangesByField' },
    { label: 'Apply Immediately', value: 'ApplyChangesImmediately' }
];

export default class DcrFieldManager extends LightningElement {
    countries = [];
    selectedCountryId = '';
    objectDefs = [];
    selectedObjectName = null;
    isLoading = true;
    isSaving = false;
    _wiredDefsResult;
    searchTerm = '';
    dcrRecordTypes = [];
    profiles = [];

    showRecordTypeModal = false;
    showPersonaModal = false;
    modalDefId = null;
    modalRecordTypeId = '';
    modalValidationType = 'Internal';
    modalProfileId = '';
    modalChangeUpdateType = 'DoNotApplyChangesImmediately';

    get changeUpdateOptions() {
        return CHANGE_UPDATE_OPTIONS;
    }

    get validationTypeOptions() {
        return [
            { label: 'Internal', value: 'Internal' },
            { label: 'External', value: 'External' }
        ];
    }

    get recordTypeOptions() {
        return this.dcrRecordTypes.map(rt => ({ label: rt.name, value: rt.id }));
    }

    get profileOptions() {
        const opts = [{ label: 'All Profiles', value: '' }];
        return opts.concat(this.profiles.map(p => ({ label: p.name, value: p.id })));
    }

    @wire(getCountries)
    wiredCountries({ data }) {
        if (data) {
            this.countries = data.map(c => ({ label: c.label, value: c.id }));
        }
    }

    @wire(getDcrRecordTypes)
    wiredRecordTypes({ data }) {
        if (data) this.dcrRecordTypes = data;
    }

    @wire(getProfiles)
    wiredProfiles({ data }) {
        if (data) this.profiles = data;
    }

    @wire(getObjectDefinitions, { countryId: '$selectedCountryId' })
    wiredDefs(result) {
        this._wiredDefsResult = result;
        if (result.data) {
            this.objectDefs = result.data.map(od => ({
                ...od,
                managedCount: od.fields.filter(f => f.isManaged).length,
                totalCount: od.fields.length
            }));
            this.isLoading = false;
        } else if (result.error) {
            this.isLoading = false;
        }
    }

    get hasObjects() {
        return !this.isLoading && this.objectDefs.length > 0;
    }

    get processedObjects() {
        return this.objectDefs.map(od => {
            const isSelected = od.objectName === this.selectedObjectName;
            const isConfigured = od.hasRecordType && od.hasPersonaDef;
            let statusLabel;
            if (isConfigured) {
                statusLabel = od.managedCount > 0 ? `${od.managedCount} managed` : 'Configured';
            } else {
                statusLabel = 'Not configured';
            }
            return {
                ...od,
                iconName: OBJECT_ICONS[od.objectName] || 'standard:custom',
                summary: statusLabel,
                tileClass: isSelected
                    ? 'tile tile-selected'
                    : (isConfigured ? 'tile tile-active' : 'tile tile-unconfigured'),
                badgeClass: isConfigured
                    ? 'slds-m-left_small badge-active'
                    : 'slds-m-left_small badge-inactive',
                isConfigured,
                configIcons: this.getConfigIcons(od)
            };
        });
    }

    getConfigIcons(od) {
        const icons = [];
        icons.push({
            key: 'rt',
            icon: od.hasRecordType ? 'utility:check' : 'utility:close',
            variant: od.hasRecordType ? 'success' : 'error',
            title: od.hasRecordType ? 'Record Type mapped' : 'No Record Type'
        });
        icons.push({
            key: 'pd',
            icon: od.hasPersonaDef ? 'utility:check' : 'utility:close',
            variant: od.hasPersonaDef ? 'success' : 'error',
            title: od.hasPersonaDef ? 'Persona defined' : 'No Persona'
        });
        return icons;
    }

    get selectedObject() {
        if (!this.selectedObjectName) return null;
        const od = this.objectDefs.find(o => o.objectName === this.selectedObjectName);
        if (!od) return null;

        const term = this.searchTerm.toLowerCase();
        let filteredFields = od.fields;
        if (term) {
            filteredFields = od.fields.filter(f =>
                f.label.toLowerCase().includes(term) ||
                f.apiName.toLowerCase().includes(term)
            );
        }

        return {
            ...od,
            managedCount: od.managedCount,
            summary: `${od.managedCount} of ${od.totalCount} fields managed`,
            badgeClass: od.managedCount > 0 ? 'slds-m-left_small badge-active' : 'slds-m-left_small badge-inactive',
            isConfigured: od.hasRecordType && od.hasPersonaDef,
            displayFields: filteredFields.map(f => ({
                ...f,
                key: od.defId + '_' + f.apiName,
                defId: od.defId,
                rowClass: f.isManaged ? 'row-managed' : '',
                typeLabel: f.type,
                validationOptions: [
                    { label: 'Internal', value: 'Internal' },
                    { label: 'External', value: 'External' }
                ]
            }))
        };
    }

    handleCountryChange(event) {
        this.selectedCountryId = event.detail.value;
        this.selectedObjectName = null;
        this.searchTerm = '';
        this.isLoading = true;
    }

    handleSelectObject(event) {
        this.selectedObjectName = event.currentTarget.dataset.object;
        this.searchTerm = '';
    }

    handleDeselectObject() {
        this.selectedObjectName = null;
        this.searchTerm = '';
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    async handleFieldToggle(event) {
        const checked = event.target.checked;
        const fieldApiName = event.target.dataset.field;
        const defId = event.target.dataset.def;
        const fieldLabel = event.target.dataset.label;
        const managedFieldId = event.target.dataset.managed;

        this.isSaving = true;
        try {
            if (checked) {
                await addManagedField({
                    defId,
                    fieldApiName,
                    fieldLabel,
                    validationType: 'Internal',
                    applyImmediately: false,
                    countryId: this.selectedCountryId || null
                });
                this.showToast('Success', `${fieldLabel} added to DCR`, 'success');
            } else {
                await removeManagedField({ managedFieldId });
                this.showToast('Success', `${fieldLabel} removed from DCR`, 'success');
            }
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Operation failed', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleValidationChange(event) {
        const managedFieldId = event.target.dataset.managed;
        const validationType = event.detail.value;
        const fieldObj = this.findFieldByManagedId(managedFieldId);

        this.isSaving = true;
        try {
            await updateManagedField({
                managedFieldId,
                validationType,
                applyImmediately: fieldObj ? fieldObj.applyImmediately : false
            });
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Update failed', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleApplyImmediatelyChange(event) {
        const managedFieldId = event.target.dataset.managed;
        const applyImmediately = event.target.checked;
        const fieldObj = this.findFieldByManagedId(managedFieldId);

        this.isSaving = true;
        try {
            await updateManagedField({
                managedFieldId,
                validationType: fieldObj ? fieldObj.validationType : 'Internal',
                applyImmediately
            });
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Update failed', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleAddRecordType(event) {
        event.stopPropagation();
        this.modalDefId = event.currentTarget.dataset.def;
        this.modalRecordTypeId = this.dcrRecordTypes.length > 0 ? this.dcrRecordTypes[0].id : '';
        this.modalValidationType = 'Internal';
        this.showRecordTypeModal = true;
    }

    handleCloseRecordTypeModal() {
        this.showRecordTypeModal = false;
    }

    handleModalRecordTypeChange(event) {
        this.modalRecordTypeId = event.detail.value;
    }

    handleModalValidationChange(event) {
        this.modalValidationType = event.detail.value;
    }

    async handleSaveRecordType() {
        this.isSaving = true;
        this.showRecordTypeModal = false;
        try {
            await addRecordTypeMapping({
                defId: this.modalDefId,
                recordTypeId: this.modalRecordTypeId,
                validationType: this.modalValidationType
            });
            this.showToast('Success', 'Record Type mapping added', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to add Record Type mapping', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleRemoveRecordType(event) {
        event.stopPropagation();
        const recTypeId = event.currentTarget.dataset.rectypeid;
        this.isSaving = true;
        try {
            await removeRecordTypeMapping({ recTypeId });
            this.showToast('Success', 'Record Type mapping removed', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleAddPersona(event) {
        event.stopPropagation();
        this.modalDefId = event.currentTarget.dataset.def;
        this.modalProfileId = '';
        this.modalChangeUpdateType = 'DoNotApplyChangesImmediately';
        this.showPersonaModal = true;
    }

    handleClosePersonaModal() {
        this.showPersonaModal = false;
    }

    handleModalProfileChange(event) {
        this.modalProfileId = event.detail.value;
    }

    handleModalChangeUpdateChange(event) {
        this.modalChangeUpdateType = event.detail.value;
    }

    async handleSavePersona() {
        this.isSaving = true;
        this.showPersonaModal = false;
        try {
            await addPersonaDef({
                defId: this.modalDefId,
                profileId: this.modalProfileId || null,
                changeUpdateType: this.modalChangeUpdateType
            });
            this.showToast('Success', 'Persona definition added', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to add Persona', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleRemovePersona(event) {
        event.stopPropagation();
        const personaDefId = event.currentTarget.dataset.personaid;
        this.isSaving = true;
        try {
            await removePersonaDef({ personaDefId });
            this.showToast('Success', 'Persona definition removed', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    findFieldByManagedId(managedFieldId) {
        for (const od of this.objectDefs) {
            for (const f of od.fields) {
                if (f.managedFieldId === managedFieldId) return f;
            }
        }
        return null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
