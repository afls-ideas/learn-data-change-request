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
import getEligibleObjects from '@salesforce/apex/DCRFieldManagerController.getEligibleObjects';
import enableDcrObject from '@salesforce/apex/DCRFieldManagerController.enableDcrObject';
import disableDcrObject from '@salesforce/apex/DCRFieldManagerController.disableDcrObject';
import addCountry from '@salesforce/apex/DCRFieldManagerController.addCountry';
import removeCountry from '@salesforce/apex/DCRFieldManagerController.removeCountry';
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

const WELL_KNOWN_COUNTRIES = [
    { label: 'United States', isoCode: 'US' },
    { label: 'United Kingdom', isoCode: 'GB' },
    { label: 'Canada', isoCode: 'CA' },
    { label: 'Germany', isoCode: 'DE' },
    { label: 'France', isoCode: 'FR' },
    { label: 'India', isoCode: 'IN' },
    { label: 'Japan', isoCode: 'JP' },
    { label: 'Australia', isoCode: 'AU' },
    { label: 'Brazil', isoCode: 'BR' },
    { label: 'Italy', isoCode: 'IT' },
    { label: 'Spain', isoCode: 'ES' },
    { label: 'Mexico', isoCode: 'MX' },
    { label: 'China', isoCode: 'CN' },
    { label: 'South Korea', isoCode: 'KR' },
    { label: 'Netherlands', isoCode: 'NL' },
    { label: 'Switzerland', isoCode: 'CH' },
    { label: 'Sweden', isoCode: 'SE' },
    { label: 'Belgium', isoCode: 'BE' },
    { label: 'Ireland', isoCode: 'IE' },
    { label: 'Singapore', isoCode: 'SG' }
];

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
    activeStep = 'countries';
    isValidating = false;
    _validationResults = [];
    _wiredCountriesResult;

    gridRecordTypeFilter = '';
    eligibleObjects = [];
    _wiredEligibleResult;
    showStepInfoModal = false;
    stepInfoTitle = '';
    stepInfoDescription = '';
    stepInfoObjects = [];

    showRecordTypeModal = false;
    showPersonaModal = false;
    modalDefId = null;
    modalRecordTypeId = '';
    modalValidationType = 'Internal';
    modalCountryId = '';
    modalExternalSystemName = '';
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
    get isCountriesStep() {
        return this.activeStep === 'countries';
    }

    get isObjectsStep() {
        return this.activeStep === 'objectsAndRecTypes';
    }

    get isCountryGridStep() {
        return this.activeStep === 'countryGrid';
    }

    get isManagedFieldsStep() {
        return this.activeStep === 'managedFields';
    }

    get isValidateStep() {
        return this.activeStep === 'validateConfig';
    }

    get stepCountriesClass() {
        const step = this.activeStep;
        if (step === 'countries') return 'step-item step-item-active';
        return 'step-item step-item-complete';
    }

    get stepObjectsClass() {
        const step = this.activeStep;
        if (step === 'objectsAndRecTypes') return 'step-item step-item-active';
        if (step === 'countryGrid' || step === 'managedFields' || step === 'validateConfig') return 'step-item step-item-complete';
        if (step === 'countries') return 'step-item';
        return 'step-item';
    }

    get stepGridClass() {
        const step = this.activeStep;
        if (step === 'countryGrid') return 'step-item step-item-active';
        if (step === 'managedFields' || step === 'validateConfig') return 'step-item step-item-complete';
        return 'step-item';
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

    // Country x Object Grid
    get gridRecordTypeOptions() {
        const opts = [{ label: 'All Record Types', value: '' }];
        const seen = new Set();
        for (const od of this.objectDefs) {
            for (const rtm of (od.recordTypeMappings || [])) {
                if (rtm.recordTypeId && !seen.has(rtm.recordTypeId)) {
                    seen.add(rtm.recordTypeId);
                    opts.push({ label: rtm.recordTypeName, value: rtm.recordTypeId });
                }
            }
        }
        return opts;
    }

    handleGridRecordTypeChange(event) {
        this.gridRecordTypeFilter = event.detail.value;
    }

    _filterMappings(mappings) {
        if (!this.gridRecordTypeFilter) return mappings;
        return mappings.filter(rtm => rtm.recordTypeId === this.gridRecordTypeFilter);
    }

    get gridColumns() {
        return this.objectDefs
            .filter(od => (od.recordTypeMappings || []).length > 0)
            .map(od => ({
                key: od.defId,
                defId: od.defId,
                objectName: od.objectName,
                iconName: OBJECT_ICONS[od.objectName] || 'standard:custom'
            }));
    }

    _buildMappingDisplay(rtm) {
        return {
            key: rtm.id,
            recordTypeName: rtm.recordTypeName,
            validationType: rtm.validationType,
            badgeClass: rtm.validationType === 'External' ? 'grid-badge grid-badge-external' : 'grid-badge grid-badge-internal',
            externalSystemName: rtm.externalSystemName || '',
            hasExternalSystem: !!rtm.externalSystemName
        };
    }

    get gridGlobalRow() {
        const cols = this.gridColumns;
        return cols.map(col => {
            const od = this.objectDefs.find(o => o.defId === col.defId);
            const globalMappings = this._filterMappings(
                (od.recordTypeMappings || []).filter(rtm => !rtm.countryId)
            );
            return {
                key: 'global-' + col.defId,
                hasMappings: globalMappings.length > 0,
                cellClass: globalMappings.length > 0 ? 'grid-cell grid-cell-active' : 'grid-cell grid-cell-empty',
                mappings: globalMappings.map(rtm => this._buildMappingDisplay(rtm))
            };
        });
    }

    get gridCountryRows() {
        const countriesWithData = this.countries.filter(c => c.value !== '');
        const cols = this.gridColumns;
        const rtFilter = this.gridRecordTypeFilter;
        return countriesWithData.map(country => {
            const cells = cols.map(col => {
                const od = this.objectDefs.find(o => o.defId === col.defId);
                const overrides = this._filterMappings(
                    (od.recordTypeMappings || []).filter(rtm => rtm.countryId === country.value)
                );
                const hasGlobal = this._filterMappings(
                    (od.recordTypeMappings || []).filter(rtm => !rtm.countryId)
                ).length > 0;
                return {
                    key: country.value + '-' + col.defId,
                    defId: col.defId,
                    countryId: country.value,
                    hasMappings: overrides.length > 0,
                    canCreateOverride: !overrides.length && hasGlobal,
                    cellClass: overrides.length > 0 ? 'grid-cell grid-cell-override' : 'grid-cell grid-cell-inherited',
                    mappings: overrides.map(rtm => this._buildMappingDisplay(rtm)),
                    inheritLabel: rtFilter ? 'Inherits Global' : 'Inherits Global'
                };
            });
            return {
                key: country.value,
                countryLabel: country.label,
                cells
            };
        });
    }

    handleGridCellCreateOverride(event) {
        const defId = event.currentTarget.dataset.def;
        const countryId = event.currentTarget.dataset.country;
        this.modalDefId = defId;
        this.modalCountryId = countryId;
        this.modalValidationType = 'Internal';
        this.modalExternalSystemName = '';
        if (this.gridRecordTypeFilter) {
            this.modalRecordTypeId = this.gridRecordTypeFilter;
        } else {
            this.modalRecordTypeId = this.dcrRecordTypes.length > 0 ? this.dcrRecordTypes[0].id : '';
        }
        this.showRecordTypeModal = true;
    }

    handleStepClick(event) {
        const step = event.currentTarget.dataset.step;
        this.activeStep = step;
        if (step === 'objectsAndRecTypes') {
            this.selectedObjectName = null;
            this.searchTerm = '';
        }
    }

    handleStepInfo(event) {
        event.stopPropagation();
        const step = event.currentTarget.dataset.step;
        const info = {
            countries: {
                title: 'Step 0: Countries',
                description: 'Manage which countries (LifeSciCountry records) are available in the org. Countries are used throughout DCR configuration for country-specific record type mappings and managed field scoping.',
                objects: ['LifeSciCountry']
            },
            objectsAndRecTypes: {
                title: 'Step 1: DCR Objects & Record Types',
                description: 'Enable/disable DCR for objects, manage record type mappings (which Account record types route to Internal vs External validation), and configure persona definitions (profile-specific DCR behavior).',
                objects: ['LifeSciDataChangeDef', 'LifeSciDataChgDefRecType', 'LifeSciDataChgPersonaDef']
            },
            countryGrid: {
                title: 'Step 1A: Country × Object Grid',
                description: 'View and manage country-specific record type mapping overrides. Each cell shows whether a country uses a global default or has its own validation routing.',
                objects: ['LifeSciDataChgDefRecType']
            },
            managedFields: {
                title: 'Step 2: DCR Managed Fields',
                description: 'Toggle which fields are governed by DCR for each object. Only changes to managed fields will generate Data Change Requests.',
                objects: ['LifeSciDataChgDefMngFld']
            },
            validateConfig: {
                title: 'Step 3: Validate Config',
                description: 'Run read-only checks to detect validation type mismatches and parent-child alignment issues that cause DCRs to silently fail.',
                objects: ['Read-only — no objects modified']
            }
        };
        const stepInfo = info[step];
        if (stepInfo) {
            this.stepInfoTitle = stepInfo.title;
            this.stepInfoDescription = stepInfo.description;
            this.stepInfoObjects = stepInfo.objects;
            this.showStepInfoModal = true;
        }
    }

    handleCloseStepInfo() {
        this.showStepInfoModal = false;
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
        const selectedId = this.selectedCountryId;
        return this.objectDefs.map(od => {
            const allMappings = od.recordTypeMappings || [];
            let filteredMappings;
            if (selectedId) {
                const countrySpecific = allMappings.filter(rtm => rtm.countryId === selectedId);
                const countrySpecificRecTypeIds = new Set(countrySpecific.map(rtm => rtm.recordTypeId));
                const globalFallbacks = allMappings.filter(rtm =>
                    !rtm.countryId && !countrySpecificRecTypeIds.has(rtm.recordTypeId)
                );
                filteredMappings = [...countrySpecific, ...globalFallbacks];
            } else {
                filteredMappings = allMappings;
            }

            const mappings = filteredMappings.map(rtm => {
                let scopeLabel;
                let scopeClass;
                if (rtm.countryId) {
                    if (selectedId && rtm.countryId === selectedId) {
                        scopeLabel = 'Country Override';
                    } else {
                        scopeLabel = rtm.countryName || 'Country';
                    }
                    scopeClass = 'scope-badge scope-country';
                } else {
                    scopeLabel = 'Global';
                    scopeClass = 'scope-badge scope-global';
                }
                return {
                    ...rtm,
                    validationOptions: [
                        { label: 'Internal', value: 'Internal' },
                        { label: 'External', value: 'External' }
                    ],
                    scopeLabel,
                    scopeClass,
                    showScope: true
                };
            });
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
    wiredCountries(result) {
        this._wiredCountriesResult = result;
        if (result.data) {
            this.countries = result.data.map(c => ({ label: c.label, value: c.id, isoCode: c.isoCode }));
        }
    }

    // Countries step
    get activeCountries() {
        return this.countries.filter(c => c.value !== '');
    }

    get hasActiveCountries() {
        return this.activeCountries.length > 0;
    }

    get activeCountryCount() {
        return this.activeCountries.length;
    }

    get availableCountries() {
        const activeIsoCodes = new Set(this.activeCountries.map(c => c.isoCode));
        return WELL_KNOWN_COUNTRIES.filter(c => !activeIsoCodes.has(c.isoCode));
    }

    get hasAvailableCountries() {
        return this.availableCountries.length > 0;
    }

    get availableCountryCount() {
        return this.availableCountries.length;
    }

    async handleAddCountry(event) {
        const isoCode = event.currentTarget.dataset.iso;
        const label = event.currentTarget.dataset.label;
        this.isSaving = true;
        try {
            await addCountry({ masterLabel: label, isoCode });
            this.showToast('Success', `${label} (${isoCode}) added`, 'success');
            await refreshApex(this._wiredCountriesResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to add country', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleRemoveCountry(event) {
        const countryId = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        this.isSaving = true;
        try {
            await removeCountry({ countryId });
            this.showToast('Success', `${label} removed`, 'success');
            await refreshApex(this._wiredCountriesResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove country', 'error');
        } finally {
            this.isSaving = false;
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

    @wire(getEligibleObjects)
    wiredEligible(result) {
        this._wiredEligibleResult = result;
        if (result.data) {
            this.eligibleObjects = result.data;
        }
    }

    get enabledObjects() {
        return this.eligibleObjects
            .filter(o => o.isEnabled)
            .map(o => ({
                ...o,
                iconName: OBJECT_ICONS[o.objectName] || 'standard:custom'
            }));
    }

    get disabledObjects() {
        return this.eligibleObjects
            .filter(o => !o.isEnabled)
            .map(o => ({
                ...o,
                iconName: OBJECT_ICONS[o.objectName] || 'standard:custom'
            }));
    }

    get hasDisabledObjects() {
        return this.disabledObjects.length > 0;
    }

    get disabledCount() {
        return this.disabledObjects.length;
    }

    async handleEnableObject(event) {
        const objectName = event.currentTarget.dataset.object;
        this.isSaving = true;
        try {
            await enableDcrObject({ objectName });
            this.showToast('Success', `${objectName} enabled for DCR`, 'success');
            await Promise.all([
                refreshApex(this._wiredEligibleResult),
                refreshApex(this._wiredDefsResult)
            ]);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to enable object', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleDisableObject(event) {
        const defId = event.currentTarget.dataset.def;
        const objectName = event.currentTarget.dataset.object;
        this.isSaving = true;
        try {
            await disableDcrObject({ defId });
            this.showToast('Success', `${objectName} disabled for DCR`, 'success');
            await Promise.all([
                refreshApex(this._wiredEligibleResult),
                refreshApex(this._wiredDefsResult)
            ]);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to disable object', 'error');
        } finally {
            this.isSaving = false;
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
            const hasOwnRecordType = od.hasRecordType;
            const isConfigured = hasOwnRecordType;
            let statusLabel;
            if (isConfigured) {
                statusLabel = od.managedCount > 0
                    ? `DCR Enabled — ${od.managedCount} field${od.managedCount > 1 ? 's' : ''} managed`
                    : 'DCR Enabled — no fields managed';
            } else {
                statusLabel = 'No Record Type Mapping — DCR will not trigger';
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
                configItems: this.getConfigItems(od)
            };
        });
    }

    getConfigItems(od) {
        const items = [];
        const rtLabel = od.hasRecordType ? 'Record Type' : 'No Record Type';
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
                const canCreateOverride = f.isGlobalOnly && !!this.selectedCountryId;
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
                    canCreateOverride,
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

    async handleCreateOverride(event) {
        const fieldApiName = event.target.dataset.field;
        const defId = event.target.dataset.def;
        const fieldLabel = event.target.dataset.label;

        this.isSaving = true;
        try {
            await addManagedField({
                defId,
                fieldApiName,
                fieldLabel,
                validationType: 'Internal',
                applyImmediately: false,
                countryId: this.selectedCountryId
            });
            this.showToast('Success', `Country override created for ${fieldLabel}`, 'success');
            await refreshApex(this._wiredDefsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create override', 'error');
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
        this.modalCountryId = '';
        this.modalExternalSystemName = '';
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

    handleModalCountryChange(event) {
        this.modalCountryId = event.detail.value;
    }

    get isModalExternal() {
        return this.modalValidationType === 'External';
    }

    handleModalExternalSystemChange(event) {
        this.modalExternalSystemName = event.target.value;
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
                validationType: this.modalValidationType,
                countryId: this.modalCountryId || null,
                externalSystemName: this.modalExternalSystemName || null
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
