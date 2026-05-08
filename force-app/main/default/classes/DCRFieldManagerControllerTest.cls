@isTest
private class DCRFieldManagerControllerTest {

    @TestSetup
    static void setup() {
        LifeSciDataChangeDef def = new LifeSciDataChangeDef();
        def.DeveloperName = 'Account_DCR_Test';
        def.MasterLabel = 'Account DCR Test';
        def.ObjectName = 'Account';
        def.IsActive = true;
        insert def;

        LifeSciDataChangeDef defHcp = new LifeSciDataChangeDef();
        defHcp.DeveloperName = 'HCP_DCR_Test';
        defHcp.MasterLabel = 'HCP DCR Test';
        defHcp.ObjectName = 'HealthcareProvider';
        defHcp.IsActive = true;
        insert defHcp;

        // Pre-create a RecType mapping for validation mismatch test
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' LIMIT 1];
        if (!rts.isEmpty()) {
            LifeSciDataChgDefRecType rtMapping = new LifeSciDataChgDefRecType();
            rtMapping.LifeSciDataChgDefId = defHcp.Id;
            rtMapping.RecordTypeId = rts[0].Id;
            rtMapping.ValidationType = 'Internal';
            rtMapping.IsNewRecApprovalRequired = true;
            insert rtMapping;
        }
    }

    @isTest
    static void testGetCountries() {
        Test.startTest();
        List<DCRFieldManagerController.CountryOption> countries = DCRFieldManagerController.getCountries();
        Test.stopTest();
        System.assert(countries.size() >= 1, 'Should return at least the All Countries option');
        System.assertEquals('', countries[0].id, 'First option should be All Countries with empty id');
    }

    @isTest
    static void testGetProfiles() {
        Test.startTest();
        List<DCRFieldManagerController.ProfileOption> profiles = DCRFieldManagerController.getProfiles();
        Test.stopTest();
        System.assert(profiles.size() > 0, 'Should return at least one profile');
    }

    @isTest
    static void testGetObjectDefinitions() {
        Test.startTest();
        List<DCRFieldManagerController.ObjectDefinition> defs = DCRFieldManagerController.getObjectDefinitions('');
        Test.stopTest();
        System.assert(defs.size() >= 2, 'Should return at least Account and HCP definitions');
        Boolean foundAccount = false;
        for (DCRFieldManagerController.ObjectDefinition od : defs) {
            if (od.objectName == 'Account') {
                foundAccount = true;
                System.assert(od.fields.size() > 0, 'Account should have fields');
            }
        }
        System.assert(foundAccount, 'Should include Account object');
    }

    @isTest
    static void testGetObjectDefinitionsWithCountryFilter() {
        List<LifeSciCountry> countries = [SELECT Id FROM LifeSciCountry LIMIT 1];
        if (countries.isEmpty()) return;
        String countryId = countries[0].Id;

        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        LifeSciDataChgDefMngFld mf = new LifeSciDataChgDefMngFld();
        mf.Name = 'Test Field';
        mf.LifeSciDataChgDefId = def.Id;
        mf.FieldApiName = 'Name';
        mf.ValidationType = 'Internal';
        mf.ShouldApplyChngImmediately = false;
        mf.CountryId = countryId;
        insert mf;

        Test.startTest();
        List<DCRFieldManagerController.ObjectDefinition> defs = DCRFieldManagerController.getObjectDefinitions(countryId);
        Test.stopTest();
        System.assert(defs.size() >= 1, 'Should return definitions');
    }

    @isTest
    static void testAddAndRemoveManagedField() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];

        Test.startTest();
        String mfId = DCRFieldManagerController.addManagedField(
            def.Id, 'Phone', 'Phone', 'Internal', false, null
        );
        Test.stopTest();

        System.assertNotEquals(null, mfId, 'Should return managed field id');
        List<LifeSciDataChgDefMngFld> fields = [SELECT Id FROM LifeSciDataChgDefMngFld WHERE Id = :mfId];
        System.assertEquals(1, fields.size(), 'Managed field should exist');

        DCRFieldManagerController.removeManagedField(mfId);
        fields = [SELECT Id FROM LifeSciDataChgDefMngFld WHERE Id = :mfId];
        System.assertEquals(0, fields.size(), 'Managed field should be deleted');
    }

    @isTest
    static void testAddManagedFieldWithCountry() {
        List<LifeSciCountry> countries = [SELECT Id FROM LifeSciCountry LIMIT 1];
        if (countries.isEmpty()) return;
        String countryId = countries[0].Id;

        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];

        Test.startTest();
        String mfId = DCRFieldManagerController.addManagedField(
            def.Id, 'Fax', 'Fax', 'External', true, countryId
        );
        Test.stopTest();

        LifeSciDataChgDefMngFld mf = [SELECT CountryId, ValidationType, ShouldApplyChngImmediately FROM LifeSciDataChgDefMngFld WHERE Id = :mfId];
        System.assertEquals(countryId, mf.CountryId);
        System.assertEquals('External', mf.ValidationType);
        System.assertEquals(true, mf.ShouldApplyChngImmediately);
    }

    @isTest
    static void testUpdateManagedField() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        String mfId = DCRFieldManagerController.addManagedField(def.Id, 'Website', 'Website', 'Internal', false, null);

        Test.startTest();
        DCRFieldManagerController.updateManagedField(mfId, 'External', true);
        Test.stopTest();

        LifeSciDataChgDefMngFld mf = [SELECT ValidationType, ShouldApplyChngImmediately FROM LifeSciDataChgDefMngFld WHERE Id = :mfId];
        System.assertEquals('External', mf.ValidationType);
        System.assertEquals(true, mf.ShouldApplyChngImmediately);
    }

    @isTest
    static void testAddAndRemoveRecordTypeMapping() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' LIMIT 1];
        if (rts.isEmpty()) return;

        Test.startTest();
        String rtmId = DCRFieldManagerController.addRecordTypeMapping(
            def.Id, rts[0].Id, 'Internal', null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, rtmId);
        List<LifeSciDataChgDefRecType> mappings = [SELECT Id FROM LifeSciDataChgDefRecType WHERE Id = :rtmId];
        System.assertEquals(1, mappings.size());

        DCRFieldManagerController.removeRecordTypeMapping(rtmId);
        mappings = [SELECT Id FROM LifeSciDataChgDefRecType WHERE Id = :rtmId];
        System.assertEquals(0, mappings.size());
    }

    @isTest
    static void testAddRecordTypeMappingWithCountryAndExternal() {
        List<LifeSciCountry> countries = [SELECT Id FROM LifeSciCountry LIMIT 1];
        if (countries.isEmpty()) return;
        String countryId = countries[0].Id;

        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'HealthcareProvider' LIMIT 1];
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' LIMIT 1];
        if (rts.isEmpty()) return;

        Test.startTest();
        String rtmId = DCRFieldManagerController.addRecordTypeMapping(
            def.Id, rts[0].Id, 'External', countryId, 'OneKey'
        );
        Test.stopTest();

        LifeSciDataChgDefRecType rtm = [SELECT ValidationType, CountryId, ExternalValidationSysName FROM LifeSciDataChgDefRecType WHERE Id = :rtmId];
        System.assertEquals('External', rtm.ValidationType);
        System.assertEquals(countryId, rtm.CountryId);
        System.assertEquals('OneKey', rtm.ExternalValidationSysName);
    }

    @isTest
    static void testUpdateRecordTypeMapping() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' LIMIT 1];
        if (rts.isEmpty()) return;

        String rtmId = DCRFieldManagerController.addRecordTypeMapping(def.Id, rts[0].Id, 'Internal', null, null);

        Test.startTest();
        DCRFieldManagerController.updateRecordTypeMapping(rtmId, 'External');
        Test.stopTest();

        LifeSciDataChgDefRecType rtm = [SELECT ValidationType FROM LifeSciDataChgDefRecType WHERE Id = :rtmId];
        System.assertEquals('External', rtm.ValidationType);
    }

    @isTest
    static void testAddAndRemovePersonaDef() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        Profile p = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];

        Test.startTest();
        String pdId = DCRFieldManagerController.addPersonaDef(def.Id, p.Id, 'DoNotApplyChangesImmediately');
        Test.stopTest();

        System.assertNotEquals(null, pdId);
        List<LifeSciDataChgPersonaDef> pds = [SELECT Id, ProfileId, ChangeUpdateType FROM LifeSciDataChgPersonaDef WHERE Id = :pdId];
        System.assertEquals(1, pds.size());
        System.assertEquals(p.Id, pds[0].ProfileId);
        System.assertEquals('DoNotApplyChangesImmediately', pds[0].ChangeUpdateType);

        DCRFieldManagerController.removePersonaDef(pdId);
        pds = [SELECT Id FROM LifeSciDataChgPersonaDef WHERE Id = :pdId];
        System.assertEquals(0, pds.size());
    }

    @isTest
    static void testAddPersonaDefAllProfiles() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'HealthcareProvider' LIMIT 1];

        Test.startTest();
        String pdId = DCRFieldManagerController.addPersonaDef(def.Id, null, 'ApplyChangesImmediately');
        Test.stopTest();

        LifeSciDataChgPersonaDef pd = [SELECT ProfileId, ChangeUpdateType, IsActive FROM LifeSciDataChgPersonaDef WHERE Id = :pdId];
        System.assertEquals(null, pd.ProfileId);
        System.assertEquals('ApplyChangesImmediately', pd.ChangeUpdateType);
        System.assertEquals(true, pd.IsActive);
    }

    @isTest
    static void testGetDcrRecordTypes() {
        Test.startTest();
        List<Map<String, String>> rts = DCRFieldManagerController.getDcrRecordTypes();
        Test.stopTest();
        System.assertNotEquals(null, rts);
    }

    @isTest
    static void testValidateConfig() {
        Test.startTest();
        List<DCRFieldManagerController.ValidationResult> results = DCRFieldManagerController.validateConfig();
        Test.stopTest();
        System.assert(results.size() > 0, 'Should return at least one result');
    }

    @isTest
    static void testValidateConfigWithMismatch() {
        // RecType mapping was created in @TestSetup for HCP def with ValidationType=Internal
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'HealthcareProvider' LIMIT 1];

        // Verify the RecType mapping exists from TestSetup
        List<LifeSciDataChgDefRecType> existingRts = [
            SELECT Id, ValidationType FROM LifeSciDataChgDefRecType WHERE LifeSciDataChgDefId = :def.Id
        ];
        System.assert(!existingRts.isEmpty(), 'RecType mapping should exist from TestSetup');

        // Insert managed field with mismatched External validation (RecType is Internal)
        LifeSciDataChgDefMngFld mf = new LifeSciDataChgDefMngFld();
        mf.Name = 'Test Mismatch';
        mf.LifeSciDataChgDefId = def.Id;
        mf.FieldApiName = 'ProfessionalTitle';
        mf.ValidationType = 'External';
        mf.ShouldApplyChngImmediately = false;
        insert mf;

        Test.startTest();
        List<DCRFieldManagerController.ValidationResult> results = DCRFieldManagerController.validateConfig();
        Test.stopTest();

        Boolean foundError = false;
        for (DCRFieldManagerController.ValidationResult vr : results) {
            if (vr.severity == 'error') {
                foundError = true;
            }
        }
        System.assert(foundError, 'Should detect validation type mismatch');
    }

    @isTest
    static void testGetEligibleObjects() {
        Test.startTest();
        List<DCRFieldManagerController.DcrEligibleObject> objects = DCRFieldManagerController.getEligibleObjects();
        Test.stopTest();

        System.assert(objects.size() > 0, 'Should return eligible objects');
        Boolean foundAccount = false;
        for (DCRFieldManagerController.DcrEligibleObject eo : objects) {
            if (eo.objectName == 'Account') {
                foundAccount = true;
                System.assertEquals(true, eo.isEnabled, 'Account should be enabled');
                System.assertNotEquals(null, eo.defId);
            }
        }
        System.assert(foundAccount, 'Should include Account');
    }

    @isTest
    static void testEnableDcrObject() {
        // Use an object that likely doesn't have a def yet; if it does, enableDcrObject still succeeds
        Test.startTest();
        String defId = DCRFieldManagerController.enableDcrObject('ContactPointPhone');
        Test.stopTest();

        System.assertNotEquals(null, defId);
        LifeSciDataChangeDef def = [SELECT ObjectName, IsActive FROM LifeSciDataChangeDef WHERE Id = :defId];
        System.assertEquals('ContactPointPhone', def.ObjectName);
        System.assertEquals(true, def.IsActive);
    }

    @isTest
    static void testEnableDcrObjectReactivatesExisting() {
        LifeSciDataChangeDef def = [SELECT Id FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        def.IsActive = false;
        update def;

        Test.startTest();
        String resultId = DCRFieldManagerController.enableDcrObject('Account');
        Test.stopTest();

        System.assertEquals(def.Id, resultId);
        LifeSciDataChangeDef updated = [SELECT IsActive FROM LifeSciDataChangeDef WHERE Id = :def.Id];
        System.assertEquals(true, updated.IsActive);
    }

    @isTest
    static void testDisableDcrObject() {
        LifeSciDataChangeDef def = [SELECT Id, IsActive FROM LifeSciDataChangeDef WHERE ObjectName = 'Account' LIMIT 1];
        System.assertEquals(true, def.IsActive);

        Test.startTest();
        DCRFieldManagerController.disableDcrObject(def.Id);
        Test.stopTest();

        LifeSciDataChangeDef updated = [SELECT IsActive FROM LifeSciDataChangeDef WHERE Id = :def.Id];
        System.assertEquals(false, updated.IsActive);
    }
}
