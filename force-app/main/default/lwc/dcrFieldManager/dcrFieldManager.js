import { LightningElement, wire } from 'lwc';
import getCountries from '@salesforce/apex/DCRFieldManagerController.getCountries';
import getObjectDefinitions from '@salesforce/apex/DCRFieldManagerController.getObjectDefinitions';
import addManagedField from '@salesforce/apex/DCRFieldManagerController.addManagedField';
import removeManagedField from '@salesforce/apex/DCRFieldManagerController.removeManagedField';
import updateManagedField from '@salesforce/apex/DCRFieldManagerController.updateManagedField';
import addRecordTypeMapping from '@salesforce/apex/DCRFieldManagerController.addRecordTypeMapping';
import updateRecordTypeMapping from '@salesforce/apex/DCRFieldManagerController.updateRecordTypeMapping';
import removeRecordTypeMapping from '@salesforce/apex/DCRFieldManagerController.removeRecordTypeMapping';
import addPersonaDef from '@salesforce/apex/DCRFieldManagerController.addPersonaDef';
import removePersonaDef from '@salesforce/apex/DCRFieldManagerController.removePersonaDef';
import getDcrRecordTypes from '@salesforce/apex/DCRFieldManagerController.getDcrRecordTypes';
import getProfiles from '@salesforce/apex/DCRFieldManagerController.getProfiles';
import validateConfig from '@salesforce/apex/DCRFieldManagerController.validateConfig';
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

const COMPOUND_FIELD_MAP = {
    Account: {
        FirstName: 'Name',
        LastName: 'Name'
    },
    ContactPointAddress: {
        City: 'Address',
        Street: 'Address',
        PostalCode: 'Address',
        State: 'Address',
        Country: 'Address',
        StateCode: 'Address',
        CountryCode: 'Address'
    }
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
    activeStep = 'objectsAndRecTypes';
    isValidating = false;
    _validationResults = [];

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

    // Step navigation
    get isObjectsStep() {
        return this.activeStep === 'objectsAndRecTypes';
    }

    get isManagedFieldsStep() {
        return this.activeStep === 'managedFields';
    }

    get isValidateStep() {
        return this.activeStep === 'validateConfig';
    }

    get stepObjectsClass() {
        const step = this.activeStep;
        if (step === 'objectsAndRecTypes') return 'step-item step-item-active';
        return 'step-item step-item-complete';
    }

    get stepFieldsClass() {
        const step = this.activeStep;
        if (step === 'managedFields') return 'step-item step-item-active';
        if (step === 'validateConfig') return 'step-item step-item-complete';
        return 'step-item';
    }

    get stepValidateClass() {
        return this.activeStep === 'validateConfig'
            ? 'step-item step-item-active'
            : 'step-item';
    }

    handleStepClick(event) {
        const step = event.currentTarget.dataset.step;
        this.activeStep = step;
        if (step === 'objectsAndRecTypes') {
            this.selectedObjectName = null;
            this.searchTerm = '';
        }
    }

    async handleRecTypeMappingValidationChange(event) {
        const mappingId = event.target.dataset.mappingid;
        const validationType = event.detail.value;
        this.isSaving = true;
        try {
            await updateRecordTypeMapping({ recTypeMappingId: mappingId, validationType });
            this.showToast('Success', 'Validation type updated', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Update failed', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // Objects & RecordTypes view
    get configuredObjects() {
        return this._enrichedObjects().filter(o => o.hasRecordType);
    }

    get unconfiguredObjects() {
        return this._enrichedObjects().filter(o => !o.hasRecordType);
    }

    get hasConfiguredObjects() {
        return this.configuredObjects.length > 0;
    }

    get hasUnconfiguredObjects() {
        return this.unconfiguredObjects.length > 0;
    }

    get configuredCount() {
        return this.configuredObjects.length;
    }

    get unconfiguredCount() {
        return this.unconfiguredObjects.length;
    }

    _enrichedObjects() {
        return this.objectDefs.map(od => {
            const mappings = (od.recordTypeMappings || []).map(rtm => ({
                ...rtm,
                validationOptions: [
                    { label: 'Internal', value: 'Internal' },
                    { label: 'External', value: 'External' }
                ],
                countryLabel: rtm.countryId ? '' : null
            }));
            return {
                ...od,
                iconName: OBJECT_ICONS[od.objectName] || 'standard:custom',
                recordTypeMappings: mappings,
                managedCount: od.managedCount || 0,
                managedPlural: (od.managedCount || 0) === 1 ? '' : 's',
                personaCount: od.personas ? od.personas.length : 0,
                personaPlural: od.personas && od.personas.length === 1 ? '' : 's'
            };
        });
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
        const accountHasRecordType = this.objectDefs.some(o => o.objectName === 'Account' && o.hasRecordType);
        return this.objectDefs.map(od => {
            const isSelected = od.objectName === this.selectedObjectName;
            const hasOwnRecordType = od.hasRecordType;
            const inheritsRecordType = !hasOwnRecordType && accountHasRecordType && od.objectName !== 'Account';
            const isConfigured = hasOwnRecordType || inheritsRecordType;
            let statusLabel;
            if (isConfigured) {
                statusLabel = od.managedCount > 0
                    ? `DCR Enabled — ${od.managedCount} field${od.managedCount > 1 ? 's' : ''} managed`
                    : 'DCR Enabled — no fields managed';
            } else {
                statusLabel = 'DCR Not Enabled';
            }
            return {
                ...od,
                iconName: OBJECT_ICONS[od.objectName] || 'standard:custom',
                summary: statusLabel,
                statusClass: isConfigured ? 'tile-status tile-status-on' : 'tile-status tile-status-off',
                tileClass: isSelected ? 'tile tile-selected' : (isConfigured ? 'tile tile-active' : 'tile'),
                badgeClass: isConfigured
                    ? 'slds-m-left_small badge-active'
                    : 'slds-m-left_small badge-inactive',
                isConfigured,
                inheritsRecordType,
                configItems: this.getConfigItems(od, inheritsRecordType)
            };
        });
    }

    getConfigItems(od, inheritsRecordType) {
        const items = [];
        let rtLabel = 'No Record Type';
        if (od.hasRecordType) {
            rtLabel = 'Record Type';
        } else if (inheritsRecordType) {
            rtLabel = 'Inherits from Account';
        }
        items.push({
            key: 'rt',
            label: rtLabel,
            chipClass: 'config-chip'
        });
        let profileLabel = 'All Profiles';
        if (od.hasPersonaDef) {
            const names = od.personas.map(p => p.profileName);
            profileLabel = names.join(', ');
        }
        items.push({
            key: 'pd',
            label: profileLabel,
            chipClass: 'config-chip'
        });
        return items;
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
            isConfigured: od.hasRecordType,
            displayFields: filteredFields.map(f => {
                const compoundMap = COMPOUND_FIELD_MAP[od.objectName] || {};
                const compoundParent = compoundMap[f.apiName];
                const isCompoundComponent = !!compoundParent;
                const compoundChildren = Object.entries(compoundMap)
                    .filter(([, parent]) => parent === f.apiName)
                    .map(([child]) => child);
                const isCompoundParent = compoundChildren.length > 0;
                const isGlobal = f.isManaged && !f.countryId;
                const isCountrySpecific = f.isManaged && !!f.countryId;
                const showScope = f.isManaged && !!this.selectedCountryId;
                return {
                    ...f,
                    key: od.defId + '_' + f.apiName,
                    defId: od.defId,
                    rowClass: f.isManaged ? 'row-managed' : (isCompoundComponent ? 'row-compound' : ''),
                    typeLabel: f.type,
                    isCompoundComponent,
                    compoundHint: isCompoundComponent
                        ? `Covered by ${compoundParent} field`
                        : (isCompoundParent ? `Compound field — covers ${compoundChildren.join(', ')}` : ''),
                    isToggleable: !isCompoundComponent,
                    showCompoundHint: isCompoundComponent || isCompoundParent,
                    showScope,
                    scopeLabel: isGlobal ? 'Global' : (isCountrySpecific ? 'Country' : ''),
                    scopeClass: isGlobal ? 'scope-badge scope-global' : 'scope-badge scope-country',
                    validationOptions: [
                        { label: 'Internal', value: 'Internal' },
                        { label: 'External', value: 'External' }
                    ]
                };
            })
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

        const compoundMap = COMPOUND_FIELD_MAP[this.selectedObjectName] || {};
        const compoundParent = compoundMap[fieldApiName];
        if (compoundParent) {
            event.target.checked = !checked;
            this.showToast('Info', `${fieldLabel} is a component of the ${compoundParent} compound field. Enable ${compoundParent} instead.`, 'info');
            return;
        }

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
        if (!this.modalRecordTypeId) {
            this.showToast('Error', 'Please select a Record Type', 'error');
            return;
        }
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
            this.showToast('Success', 'Profile added', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to add Profile', 'error');
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
            this.showToast('Success', 'Profile removed', 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // Validate Config
    get hasValidationResults() {
        return this._validationResults.length > 0;
    }

    get validationResults() {
        const iconMap = {
            error: 'utility:error',
            warning: 'utility:warning',
            success: 'utility:success'
        };
        const iconClassMap = {
            error: 'vr-icon-error',
            warning: 'vr-icon-warning',
            success: 'vr-icon-success'
        };
        return this._validationResults.map((vr, idx) => ({
            ...vr,
            key: 'vr-' + idx,
            iconName: iconMap[vr.severity] || 'utility:info',
            iconClass: iconClassMap[vr.severity] || '',
            rowClass: 'vr-row vr-row-' + vr.severity
        }));
    }

    async handleRunValidation() {
        this.isValidating = true;
        this._validationResults = [];
        try {
            this._validationResults = await validateConfig();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Validation failed', 'error');
        } finally {
            this.isValidating = false;
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
