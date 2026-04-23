public with sharing class DCRFieldManagerController {

    public class ObjectDefinition {
        @AuraEnabled public String defId;
        @AuraEnabled public String objectName;
        @AuraEnabled public String developerName;
        @AuraEnabled public List<FieldInfo> fields;
        @AuraEnabled public Boolean hasRecordType;
        @AuraEnabled public String recTypeId;
        @AuraEnabled public String recTypeValidation;
        @AuraEnabled public Boolean hasPersonaDef;
        @AuraEnabled public String personaDefId;
        @AuraEnabled public String personaChangeUpdateType;
        @AuraEnabled public List<PersonaInfo> personas;
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
            query += ' WHERE CountryId = :countryId';
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
            SELECT Id, LifeSciDataChgDefId, RecordTypeId, ValidationType, CountryId
            FROM LifeSciDataChgDefRecType
        ];
        Map<Id, LifeSciDataChgDefRecType> recTypeByDef = new Map<Id, LifeSciDataChgDefRecType>();
        for (LifeSciDataChgDefRecType rt : recTypes) {
            recTypeByDef.put(rt.LifeSciDataChgDefId, rt);
        }

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

            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                if (!dfr.isUpdateable() && !dfr.isCreateable()) continue;
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
    public static String addRecordTypeMapping(String defId, String recordTypeId, String validationType) {
        LifeSciDataChgDefRecType rt = new LifeSciDataChgDefRecType();
        rt.LifeSciDataChgDefId = defId;
        rt.RecordTypeId = recordTypeId;
        rt.ValidationType = validationType;
        rt.IsNewRecApprovalRequired = true;
        try {
            insert rt;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return rt.Id;
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

    private class FieldInfoComparator implements System.Comparator<FieldInfo> {
        public Integer compare(FieldInfo a, FieldInfo b) {
            if (a.label == null && b.label == null) return 0;
            if (a.label == null) return 1;
            if (b.label == null) return -1;
            return a.label.compareTo(b.label);
        }
    }
}
