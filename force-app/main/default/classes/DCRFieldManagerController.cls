public with sharing class DCRFieldManagerController {

    public class ObjectDefinition {
        @AuraEnabled public String defId;
        @AuraEnabled public String objectName;
        @AuraEnabled public String developerName;
        @AuraEnabled public List<FieldInfo> fields;
        @AuraEnabled public Boolean hasRecordType;
        @AuraEnabled public String recTypeId;
        @AuraEnabled public String recTypeValidation;
        @AuraEnabled public List<RecordTypeMappingInfo> recordTypeMappings;
        @AuraEnabled public Boolean hasPersonaDef;
        @AuraEnabled public String personaDefId;
        @AuraEnabled public String personaChangeUpdateType;
        @AuraEnabled public List<PersonaInfo> personas;
    }

    public class RecordTypeMappingInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String recordTypeId;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public String validationType;
        @AuraEnabled public String countryId;
        @AuraEnabled public String countryName;
        @AuraEnabled public String externalSystemName;
    }

    public class FieldInfo {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isManaged;
        @AuraEnabled public String managedFieldId;
        @AuraEnabled public Boolean applyImmediately;
        @AuraEnabled public String validationType;
        @AuraEnabled public String countryId;
    }

    public class CountryOption {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String isoCode;
    }

    public class PersonaInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String profileId;
        @AuraEnabled public String profileName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String changeUpdateType;
    }

    public class ProfileOption {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }

    @AuraEnabled(cacheable=true)
    public static List<CountryOption> getCountries() {
        List<CountryOption> countries = new List<CountryOption>();
        CountryOption allOption = new CountryOption();
        allOption.id = '';
        allOption.label = 'All Countries';
        allOption.isoCode = '';
        countries.add(allOption);

        for (LifeSciCountry c : [
            SELECT Id, MasterLabel, IsoCode FROM LifeSciCountry ORDER BY MasterLabel
        ]) {
            CountryOption co = new CountryOption();
            co.id = c.Id;
            co.label = c.MasterLabel + ' (' + c.IsoCode + ')';
            co.isoCode = c.IsoCode;
            countries.add(co);
        }
        return countries;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProfileOption> getProfiles() {
        List<ProfileOption> profiles = new List<ProfileOption>();
        for (Profile p : [SELECT Id, Name FROM Profile WHERE UserType = 'Standard' ORDER BY Name]) {
            ProfileOption po = new ProfileOption();
            po.id = p.Id;
            po.name = p.Name;
            profiles.add(po);
        }
        return profiles;
    }

    @AuraEnabled(cacheable=true)
    public static List<ObjectDefinition> getObjectDefinitions(String countryId) {
        Map<Id, LifeSciDataChangeDef> defs = new Map<Id, LifeSciDataChangeDef>([
            SELECT Id, DeveloperName, ObjectName
            FROM LifeSciDataChangeDef
            WHERE IsActive = true
            ORDER BY ObjectName
        ]);

        String query = 'SELECT Id, LifeSciDataChgDefId, FieldApiName, ShouldApplyChngImmediately, ValidationType, CountryId FROM LifeSciDataChgDefMngFld';
        if (String.isNotBlank(countryId)) {
            query += ' WHERE CountryId = :countryId OR CountryId = null';
        }
        List<LifeSciDataChgDefMngFld> managedFields = Database.query(query);

        Map<Id, Map<String, LifeSciDataChgDefMngFld>> managedByDef = new Map<Id, Map<String, LifeSciDataChgDefMngFld>>();
        for (LifeSciDataChgDefMngFld mf : managedFields) {
            if (!managedByDef.containsKey(mf.LifeSciDataChgDefId)) {
                managedByDef.put(mf.LifeSciDataChgDefId, new Map<String, LifeSciDataChgDefMngFld>());
            }
            managedByDef.get(mf.LifeSciDataChgDefId).put(mf.FieldApiName, mf);
        }

        List<LifeSciDataChgDefRecType> recTypes = [
            SELECT Id, LifeSciDataChgDefId, RecordTypeId, ValidationType, CountryId, ExternalValidationSysName
            FROM LifeSciDataChgDefRecType
        ];
        Map<Id, LifeSciDataChgDefRecType> recTypeByDef = new Map<Id, LifeSciDataChgDefRecType>();
        Map<Id, List<LifeSciDataChgDefRecType>> allRecTypesByDef = new Map<Id, List<LifeSciDataChgDefRecType>>();
        Set<Id> allRecordTypeIds = new Set<Id>();
        for (LifeSciDataChgDefRecType rt : recTypes) {
            recTypeByDef.put(rt.LifeSciDataChgDefId, rt);
            if (!allRecTypesByDef.containsKey(rt.LifeSciDataChgDefId)) {
                allRecTypesByDef.put(rt.LifeSciDataChgDefId, new List<LifeSciDataChgDefRecType>());
            }
            allRecTypesByDef.get(rt.LifeSciDataChgDefId).add(rt);
            if (rt.RecordTypeId != null) allRecordTypeIds.add(rt.RecordTypeId);
        }
        Map<Id, RecordType> recordTypeNameMap = new Map<Id, RecordType>(
            [SELECT Id, Name FROM RecordType WHERE Id IN :allRecordTypeIds]
        );

        Set<Id> countryIdsFromMappings = new Set<Id>();
        for (LifeSciDataChgDefRecType rt : recTypes) {
            if (rt.CountryId != null) countryIdsFromMappings.add(rt.CountryId);
        }
        Map<Id, LifeSciCountry> countryNameMap = new Map<Id, LifeSciCountry>(
            [SELECT Id, MasterLabel, IsoCode FROM LifeSciCountry WHERE Id IN :countryIdsFromMappings]
        );

        List<LifeSciDataChgPersonaDef> personaDefs = [
            SELECT Id, LifeSciDataChgDefId, ProfileId, IsActive, ChangeUpdateType
            FROM LifeSciDataChgPersonaDef
        ];
        Map<Id, List<LifeSciDataChgPersonaDef>> personasByDef = new Map<Id, List<LifeSciDataChgPersonaDef>>();
        for (LifeSciDataChgPersonaDef pd : personaDefs) {
            if (!personasByDef.containsKey(pd.LifeSciDataChgDefId)) {
                personasByDef.put(pd.LifeSciDataChgDefId, new List<LifeSciDataChgPersonaDef>());
            }
            personasByDef.get(pd.LifeSciDataChgDefId).add(pd);
        }

        Set<Id> profileIds = new Set<Id>();
        for (LifeSciDataChgPersonaDef pd : personaDefs) {
            if (pd.ProfileId != null) profileIds.add(pd.ProfileId);
        }
        Map<Id, Profile> profileMap = new Map<Id, Profile>([
            SELECT Id, Name FROM Profile WHERE Id IN :profileIds
        ]);

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<ObjectDefinition> result = new List<ObjectDefinition>();

        for (LifeSciDataChangeDef def : defs.values()) {
            Schema.SObjectType sot = globalDescribe.get(def.ObjectName);
            if (sot == null) continue;

            Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();
            Map<String, LifeSciDataChgDefMngFld> managed = managedByDef.containsKey(def.Id)
                ? managedByDef.get(def.Id)
                : new Map<String, LifeSciDataChgDefMngFld>();

            ObjectDefinition od = new ObjectDefinition();
            od.defId = def.Id;
            od.objectName = def.ObjectName;
            od.developerName = def.DeveloperName;
            od.fields = new List<FieldInfo>();

            LifeSciDataChgDefRecType rt = recTypeByDef.get(def.Id);
            od.hasRecordType = (rt != null);
            if (rt != null) {
                od.recTypeId = rt.Id;
                od.recTypeValidation = rt.ValidationType;
            }

            od.recordTypeMappings = new List<RecordTypeMappingInfo>();
            List<LifeSciDataChgDefRecType> defRecTypes = allRecTypesByDef.get(def.Id);
            if (defRecTypes != null) {
                for (LifeSciDataChgDefRecType drt : defRecTypes) {
                    RecordTypeMappingInfo rtm = new RecordTypeMappingInfo();
                    rtm.id = drt.Id;
                    rtm.recordTypeId = drt.RecordTypeId;
                    rtm.validationType = drt.ValidationType;
                    rtm.countryId = drt.CountryId;
                    rtm.externalSystemName = drt.ExternalValidationSysName;
                    if (drt.CountryId != null && countryNameMap.containsKey(drt.CountryId)) {
                        LifeSciCountry c = countryNameMap.get(drt.CountryId);
                        rtm.countryName = c.MasterLabel + ' (' + c.IsoCode + ')';
                    }
                    if (drt.RecordTypeId != null && recordTypeNameMap.containsKey(drt.RecordTypeId)) {
                        rtm.recordTypeName = recordTypeNameMap.get(drt.RecordTypeId).Name;
                    }
                    od.recordTypeMappings.add(rtm);
                }
            }

            List<LifeSciDataChgPersonaDef> pds = personasByDef.get(def.Id);
            od.hasPersonaDef = (pds != null && !pds.isEmpty());
            od.personas = new List<PersonaInfo>();
            if (pds != null) {
                for (LifeSciDataChgPersonaDef pd : pds) {
                    PersonaInfo pi = new PersonaInfo();
                    pi.id = pd.Id;
                    pi.profileId = pd.ProfileId;
                    pi.isActive = pd.IsActive;
                    pi.changeUpdateType = pd.ChangeUpdateType;
                    if (pd.ProfileId != null && profileMap.containsKey(pd.ProfileId)) {
                        pi.profileName = profileMap.get(pd.ProfileId).Name;
                    } else {
                        pi.profileName = 'All Profiles';
                    }
                    od.personas.add(pi);
                }
            }

            Set<String> addedFields = new Set<String>();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                Boolean isCompoundField = dfr.getType().name() == 'ADDRESS';
                if (!isCompoundField && !dfr.isUpdateable() && !dfr.isCreateable()) continue;
                if (dfr.isCalculated()) continue;

                FieldInfo fi = new FieldInfo();
                fi.apiName = dfr.getName();
                fi.label = dfr.getLabel();
                fi.type = dfr.getType().name();

                LifeSciDataChgDefMngFld mf = managed.get(dfr.getName());
                if (mf != null) {
                    fi.isManaged = true;
                    fi.managedFieldId = mf.Id;
                    fi.applyImmediately = mf.ShouldApplyChngImmediately;
                    fi.validationType = mf.ValidationType;
                    fi.countryId = mf.CountryId;
                } else {
                    fi.isManaged = false;
                    fi.applyImmediately = false;
                    fi.validationType = 'Internal';
                }

                od.fields.add(fi);
                addedFields.add(dfr.getName());
            }

            for (String managedFieldName : managed.keySet()) {
                if (!addedFields.contains(managedFieldName) && fieldMap.containsKey(managedFieldName.toLowerCase())) {
                    Schema.DescribeFieldResult dfr = fieldMap.get(managedFieldName.toLowerCase()).getDescribe();
                    FieldInfo fi = new FieldInfo();
                    fi.apiName = dfr.getName();
                    fi.label = dfr.getLabel();
                    fi.type = dfr.getType().name();
                    LifeSciDataChgDefMngFld mf = managed.get(managedFieldName);
                    fi.isManaged = true;
                    fi.managedFieldId = mf.Id;
                    fi.applyImmediately = mf.ShouldApplyChngImmediately;
                    fi.validationType = mf.ValidationType;
                    fi.countryId = mf.CountryId;
                    od.fields.add(fi);
                }
            }

            od.fields.sort(new FieldInfoComparator());
            result.add(od);
        }

        return result;
    }

    @AuraEnabled
    public static String addManagedField(String defId, String fieldApiName, String fieldLabel, String validationType, Boolean applyImmediately, String countryId) {
        LifeSciDataChgDefMngFld mf = new LifeSciDataChgDefMngFld();
        mf.Name = fieldLabel;
        mf.LifeSciDataChgDefId = defId;
        mf.FieldApiName = fieldApiName;
        mf.ValidationType = validationType;
        mf.ShouldApplyChngImmediately = applyImmediately;
        if (String.isNotBlank(countryId)) {
            mf.CountryId = countryId;
        }
        try {
            insert mf;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return mf.Id;
    }

    @AuraEnabled
    public static void removeManagedField(String managedFieldId) {
        delete [SELECT Id FROM LifeSciDataChgDefMngFld WHERE Id = :managedFieldId];
    }

    @AuraEnabled
    public static void updateManagedField(String managedFieldId, String validationType, Boolean applyImmediately) {
        LifeSciDataChgDefMngFld mf = [
            SELECT Id FROM LifeSciDataChgDefMngFld WHERE Id = :managedFieldId
        ];
        mf.ValidationType = validationType;
        mf.ShouldApplyChngImmediately = applyImmediately;
        update mf;
    }

    @AuraEnabled
    public static String addRecordTypeMapping(String defId, String recordTypeId, String validationType, String countryId, String externalSystemName) {
        LifeSciDataChgDefRecType rt = new LifeSciDataChgDefRecType();
        rt.LifeSciDataChgDefId = defId;
        rt.RecordTypeId = recordTypeId;
        rt.ValidationType = validationType;
        rt.IsNewRecApprovalRequired = true;
        if (String.isNotBlank(countryId)) {
            rt.CountryId = countryId;
        }
        if (String.isNotBlank(externalSystemName)) {
            rt.ExternalValidationSysName = externalSystemName;
        }
        try {
            insert rt;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return rt.Id;
    }

    @AuraEnabled
    public static void updateRecordTypeMapping(String recTypeMappingId, String validationType) {
        LifeSciDataChgDefRecType rt = [SELECT Id FROM LifeSciDataChgDefRecType WHERE Id = :recTypeMappingId];
        rt.ValidationType = validationType;
        update rt;
    }

    @AuraEnabled
    public static void removeRecordTypeMapping(String recTypeId) {
        delete [SELECT Id FROM LifeSciDataChgDefRecType WHERE Id = :recTypeId];
    }

    @AuraEnabled
    public static String addPersonaDef(String defId, String profileId, String changeUpdateType) {
        LifeSciDataChgPersonaDef pd = new LifeSciDataChgPersonaDef();
        pd.LifeSciDataChgDefId = defId;
        if (String.isNotBlank(profileId)) {
            pd.ProfileId = profileId;
        }
        pd.ChangeUpdateType = changeUpdateType;
        pd.IsActive = true;
        try {
            insert pd;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return pd.Id;
    }

    @AuraEnabled
    public static void removePersonaDef(String personaDefId) {
        delete [SELECT Id FROM LifeSciDataChgPersonaDef WHERE Id = :personaDefId];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDcrRecordTypes() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        Set<Id> usedIds = new Set<Id>();
        for (LifeSciDataChgDefRecType existing : [SELECT RecordTypeId FROM LifeSciDataChgDefRecType]) {
            usedIds.add(existing.RecordTypeId);
        }
        for (RecordType rt : [SELECT Id, Name, SobjectType FROM RecordType WHERE SobjectType = 'Account' ORDER BY Name]) {
            result.add(new Map<String, String>{ 'id' => rt.Id, 'name' => rt.Name });
        }
        for (Id usedId : usedIds) {
            Boolean found = false;
            for (Map<String, String> r : result) {
                if (r.get('id') == usedId) { found = true; break; }
            }
            if (!found) {
                List<RecordType> rts = [SELECT Id, Name FROM RecordType WHERE Id = :usedId];
                if (!rts.isEmpty()) {
                    result.add(new Map<String, String>{ 'id' => rts[0].Id, 'name' => rts[0].Name });
                }
            }
        }
        return result;
    }

    public class ValidationResult {
        @AuraEnabled public String severity; // error, warning, success
        @AuraEnabled public String objectName;
        @AuraEnabled public String message;
        @AuraEnabled public String detail;
    }

    @AuraEnabled
    public static List<ValidationResult> validateConfig() {
        List<ValidationResult> results = new List<ValidationResult>();

        Map<Id, LifeSciDataChangeDef> defs = new Map<Id, LifeSciDataChangeDef>([
            SELECT Id, ObjectName, IsActive FROM LifeSciDataChangeDef WHERE IsActive = true
        ]);

        // Collect all rec type mappings grouped by def, keyed by validation type
        Map<Id, Set<String>> recTypeValidationsByDef = new Map<Id, Set<String>>();
        Map<Id, List<LifeSciDataChgDefRecType>> recTypesByDef = new Map<Id, List<LifeSciDataChgDefRecType>>();
        Set<Id> recordTypeIds = new Set<Id>();
        for (LifeSciDataChgDefRecType rt : [
            SELECT Id, LifeSciDataChgDefId, RecordTypeId, ValidationType
            FROM LifeSciDataChgDefRecType
        ]) {
            if (!recTypeValidationsByDef.containsKey(rt.LifeSciDataChgDefId)) {
                recTypeValidationsByDef.put(rt.LifeSciDataChgDefId, new Set<String>());
            }
            recTypeValidationsByDef.get(rt.LifeSciDataChgDefId).add(rt.ValidationType);
            if (!recTypesByDef.containsKey(rt.LifeSciDataChgDefId)) {
                recTypesByDef.put(rt.LifeSciDataChgDefId, new List<LifeSciDataChgDefRecType>());
            }
            recTypesByDef.get(rt.LifeSciDataChgDefId).add(rt);
            if (rt.RecordTypeId != null) recordTypeIds.add(rt.RecordTypeId);
        }
        Map<Id, RecordType> rtNames = new Map<Id, RecordType>(
            [SELECT Id, Name FROM RecordType WHERE Id IN :recordTypeIds]
        );

        // Collect managed fields grouped by def
        Map<Id, List<LifeSciDataChgDefMngFld>> fieldsByDef = new Map<Id, List<LifeSciDataChgDefMngFld>>();
        for (LifeSciDataChgDefMngFld mf : [
            SELECT Id, LifeSciDataChgDefId, FieldApiName, ValidationType
            FROM LifeSciDataChgDefMngFld
        ]) {
            if (!fieldsByDef.containsKey(mf.LifeSciDataChgDefId)) {
                fieldsByDef.put(mf.LifeSciDataChgDefId, new List<LifeSciDataChgDefMngFld>());
            }
            fieldsByDef.get(mf.LifeSciDataChgDefId).add(mf);
        }

        // Check 1: Managed field ValidationType must match at least one RecType mapping ValidationType
        for (LifeSciDataChangeDef def : defs.values()) {
            Set<String> rtValidations = recTypeValidationsByDef.get(def.Id);
            List<LifeSciDataChgDefMngFld> fields = fieldsByDef.get(def.Id);

            if (rtValidations == null || rtValidations.isEmpty()) {
                continue; // No rec type mappings — handled by other checks
            }
            if (fields == null || fields.isEmpty()) {
                continue; // No managed fields
            }

            for (LifeSciDataChgDefMngFld mf : fields) {
                if (!rtValidations.contains(mf.ValidationType)) {
                    // Build detail about what rec type mappings exist
                    List<String> rtDetails = new List<String>();
                    for (LifeSciDataChgDefRecType rt : recTypesByDef.get(def.Id)) {
                        String rtName = rtNames.containsKey(rt.RecordTypeId) ? rtNames.get(rt.RecordTypeId).Name : String.valueOf(rt.RecordTypeId);
                        rtDetails.add(rtName + ' → ' + rt.ValidationType);
                    }

                    ValidationResult vr = new ValidationResult();
                    vr.severity = 'error';
                    vr.objectName = def.ObjectName;
                    vr.message = 'Validation type mismatch: managed field "' + mf.FieldApiName + '" is ' + mf.ValidationType + ' but no record type mapping is ' + mf.ValidationType;
                    vr.detail = 'Record type mappings: ' + String.join(rtDetails, '; ') + '. DCR will silently skip this field.';
                    results.add(vr);
                }
            }
        }

        // Check 2: Child object RecType mapping validation type must match Account's mapping for the same Account record type
        Id accountDefId = null;
        for (LifeSciDataChangeDef def : defs.values()) {
            if (def.ObjectName == 'Account') {
                accountDefId = def.Id;
                break;
            }
        }

        if (accountDefId != null) {
            // Build map of Account's record type ID → set of validation types
            Map<Id, Set<String>> accountRtValidations = new Map<Id, Set<String>>();
            List<LifeSciDataChgDefRecType> accountMappings = recTypesByDef.get(accountDefId);
            if (accountMappings != null) {
                for (LifeSciDataChgDefRecType art : accountMappings) {
                    if (!accountRtValidations.containsKey(art.RecordTypeId)) {
                        accountRtValidations.put(art.RecordTypeId, new Set<String>());
                    }
                    accountRtValidations.get(art.RecordTypeId).add(art.ValidationType);
                }
            }

            for (LifeSciDataChangeDef def : defs.values()) {
                if (def.ObjectName == 'Account') continue;
                List<LifeSciDataChgDefRecType> childMappings = recTypesByDef.get(def.Id);
                if (childMappings == null) continue;

                for (LifeSciDataChgDefRecType childRt : childMappings) {
                    String rtName = rtNames.containsKey(childRt.RecordTypeId) ? rtNames.get(childRt.RecordTypeId).Name : String.valueOf(childRt.RecordTypeId);
                    Set<String> accountVals = accountRtValidations.get(childRt.RecordTypeId);

                    if (accountVals == null) {
                        ValidationResult vr = new ValidationResult();
                        vr.severity = 'error';
                        vr.objectName = def.ObjectName;
                        vr.message = 'Record type "' + rtName + '" has no matching Account mapping';
                        vr.detail = def.ObjectName + ' maps ' + rtName + ' → ' + childRt.ValidationType + ', but Account has no mapping for this record type. DCR will silently skip.';
                        results.add(vr);
                    } else if (!accountVals.contains(childRt.ValidationType)) {
                        List<String> accountDetails = new List<String>();
                        for (String v : accountVals) accountDetails.add(rtName + ' → ' + v);

                        ValidationResult vr = new ValidationResult();
                        vr.severity = 'error';
                        vr.objectName = def.ObjectName;
                        vr.message = 'Parent-child validation type mismatch for "' + rtName + '": ' + def.ObjectName + ' is ' + childRt.ValidationType + ' but Account is ' + String.join(new List<String>(accountVals), '/');
                        vr.detail = 'Account mappings: ' + String.join(accountDetails, '; ') + '. Child object validation type must match Account for DCR to trigger.';
                        results.add(vr);
                    }
                }
            }
        }

        // If no issues found, add a success result
        if (results.isEmpty()) {
            ValidationResult vr = new ValidationResult();
            vr.severity = 'success';
            vr.objectName = '';
            vr.message = 'All validation checks passed';
            vr.detail = 'Managed field validation types align with record type mappings, and child object mappings match Account.';
            results.add(vr);
        }

        return results;
    }

    public class DcrEligibleObject {
        @AuraEnabled public String objectName;
        @AuraEnabled public Boolean isEnabled;
        @AuraEnabled public String defId;
    }

    @AuraEnabled(cacheable=true)
    public static List<DcrEligibleObject> getEligibleObjects() {
        List<String> knownObjects = new List<String>{
            'Account', 'BusinessLicense', 'ContactPointAddress',
            'ContactPointEmail', 'ContactPointPhone', 'ContactPointSocial',
            'HealthcareProvider', 'HealthcareProviderNpi',
            'HealthcareProviderSpecialty', 'ProviderAffiliation'
        };

        Map<String, LifeSciDataChangeDef> existingByObject = new Map<String, LifeSciDataChangeDef>();
        for (LifeSciDataChangeDef def : [
            SELECT Id, ObjectName, IsActive FROM LifeSciDataChangeDef
        ]) {
            existingByObject.put(def.ObjectName, def);
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<DcrEligibleObject> result = new List<DcrEligibleObject>();
        for (String objName : knownObjects) {
            if (globalDescribe.get(objName) == null) continue;
            DcrEligibleObject eo = new DcrEligibleObject();
            eo.objectName = objName;
            LifeSciDataChangeDef existing = existingByObject.get(objName);
            eo.isEnabled = (existing != null && existing.IsActive);
            eo.defId = existing != null ? existing.Id : null;
            result.add(eo);
        }
        return result;
    }

    @AuraEnabled
    public static String enableDcrObject(String objectName) {
        List<LifeSciDataChangeDef> existing = [
            SELECT Id, IsActive FROM LifeSciDataChangeDef WHERE ObjectName = :objectName LIMIT 1
        ];
        if (!existing.isEmpty()) {
            LifeSciDataChangeDef def = existing[0];
            if (!def.IsActive) {
                def.IsActive = true;
                update def;
            }
            return def.Id;
        }
        LifeSciDataChangeDef def = new LifeSciDataChangeDef();
        def.DeveloperName = objectName.replaceAll('[^a-zA-Z0-9]', '_') + '_DCR';
        def.MasterLabel = objectName + ' DCR';
        def.ObjectName = objectName;
        def.IsActive = true;
        try {
            insert def;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return def.Id;
    }

    @AuraEnabled
    public static void disableDcrObject(String defId) {
        LifeSciDataChangeDef def = [SELECT Id, IsActive FROM LifeSciDataChangeDef WHERE Id = :defId];
        def.IsActive = false;
        update def;
    }

    private class FieldInfoComparator implements System.Comparator<FieldInfo> {
        public Integer compare(FieldInfo a, FieldInfo b) {
            if (a.label == null && b.label == null) return 0;
            if (a.label == null) return 1;
            if (b.label == null) return -1;
            return a.label.compareTo(b.label);
        }
    }
}
