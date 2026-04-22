public with sharing class DCRFieldManagerController {

    public class ObjectDefinition {
        @AuraEnabled public String defId;
        @AuraEnabled public String objectName;
        @AuraEnabled public String developerName;
        @AuraEnabled public List<FieldInfo> fields;
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
    public static List<ObjectDefinition> getObjectDefinitions(String countryId) {
        Map<Id, LifeSciDataChangeDef> defs = new Map<Id, LifeSciDataChangeDef>([
            SELECT Id, DeveloperName, ObjectName
            FROM LifeSciDataChangeDef
            WHERE IsActive = true
            ORDER BY ObjectName
        ]);

        String query = 'SELECT Id, Name, LifeSciDataChgDefId, FieldApiName, ShouldApplyChngImmediately, ValidationType, CountryId FROM LifeSciDataChgDefMngFld';
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

        List<String> objectNames = new List<String>();
        for (LifeSciDataChangeDef d : defs.values()) {
            objectNames.add(d.ObjectName);
        }

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

    private class FieldInfoComparator implements System.Comparator<FieldInfo> {
        public Integer compare(FieldInfo a, FieldInfo b) {
            if (a.label == null && b.label == null) return 0;
            if (a.label == null) return 1;
            if (b.label == null) return -1;
            return a.label.compareTo(b.label);
        }
    }
}
