import { LightningElement, wire } from 'lwc';
import getCountries from '@salesforce/apex/DCRFieldManagerController.getCountries';
import getObjectDefinitions from '@salesforce/apex/DCRFieldManagerController.getObjectDefinitions';
import addManagedField from '@salesforce/apex/DCRFieldManagerController.addManagedField';
import removeManagedField from '@salesforce/apex/DCRFieldManagerController.removeManagedField';
import updateManagedField from '@salesforce/apex/DCRFieldManagerController.updateManagedField';
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

export default class DcrFieldManager extends LightningElement {
    countries = [];
    selectedCountryId = '';
    objectDefs = [];
    selectedObjectName = null;
    isLoading = true;
    isSaving = false;
    _wiredDefsResult;
    searchTerm = '';

    @wire(getCountries)
    wiredCountries({ data }) {
        if (data) {
            this.countries = data.map(c => ({ label: c.label, value: c.id }));
        }
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
            return {
                ...od,
                iconName: OBJECT_ICONS[od.objectName] || 'standard:custom',
                summary: od.managedCount > 0 ? `${od.managedCount} managed` : 'No fields managed',
                tileClass: isSelected ? 'tile tile-selected' : (od.managedCount > 0 ? 'tile tile-active' : 'tile'),
                badgeClass: od.managedCount > 0 ? 'slds-m-left_small badge-active' : 'slds-m-left_small badge-inactive'
            };
        });
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
