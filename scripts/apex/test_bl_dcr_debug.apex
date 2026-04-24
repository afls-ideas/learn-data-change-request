// Debug BusinessLicense DCR generation as Evan
// Run: sf apex run --file scripts/apex/test_bl_dcr_debug.apex --target-org 260-pm

Id evanUserId = '005Hs00000ILguaIAD';
Id hcpRecordTypeId = '012Hs000001xJ49IAE';

// Check if Evan has SkipLifeSciencesTriggerHandlers
User evan = [SELECT Id, Name, ProfileId, Profile.Name FROM User WHERE Id = :evanUserId];
System.debug('User: ' + evan.Name + ' | Profile: ' + evan.Profile.Name);

// Check Evan's permissions
List<PermissionSetAssignment> psas = [
    SELECT PermissionSet.Name, PermissionSet.Label
    FROM PermissionSetAssignment
    WHERE AssigneeId = :evanUserId
];
System.debug('Permission Sets (' + psas.size() + '):');
for (PermissionSetAssignment psa : psas) {
    System.debug('  ' + psa.PermissionSet.Name + ' (' + psa.PermissionSet.Label + ')');
}

// Find BusinessLicense
List<BusinessLicense> bls = [
    SELECT Id, Name, LicenseNumber, AccountId, Account.Name, Account.RecordTypeId, Account.RecordType.Name
    FROM BusinessLicense
    WHERE AccountId != null AND Account.RecordTypeId = :hcpRecordTypeId
    LIMIT 1
];
if (bls.isEmpty()) {
    System.debug('ERROR: No BusinessLicense found');
    return;
}
BusinessLicense bl = bls[0];
System.debug('BL: ' + bl.Id + ' | ' + bl.Name);
System.debug('Account: ' + bl.Account.Name + ' | RT: ' + bl.Account.RecordType.Name + ' (' + bl.Account.RecordTypeId + ')');

// Count before
Integer before = [SELECT COUNT() FROM LifeSciDataChangeRequest WHERE DataChangeRecordIdentifier = :String.valueOf(bl.Id)];
System.debug('DCRs before: ' + before);

// Update as Evan
System.runAs(new User(Id = evanUserId)) {
    System.debug('Running as: ' + UserInfo.getUserName() + ' | Profile: ' + UserInfo.getProfileId());
    update new BusinessLicense(Id = bl.Id, LicenseNumber = 'DBG-' + String.valueOf(Datetime.now().getTime()).right(6));
    System.debug('Update done inside runAs');
}

// Count after
List<LifeSciDataChangeRequest> dcrs = [
    SELECT Id, Name, Status, OperationType, ValidationType, DataChangeRecordIdentifier, DataChangeInformation
    FROM LifeSciDataChangeRequest
    WHERE DataChangeRecordIdentifier = :String.valueOf(bl.Id)
    ORDER BY CreatedDate DESC
];
System.debug('DCRs after: ' + dcrs.size());
if (dcrs.size() > before) {
    System.debug('SUCCESS — DCR generated!');
    LifeSciDataChangeRequest d = dcrs[0];
    System.debug('  ' + d.Name + ' | ' + d.Status + ' | ' + d.OperationType + ' | ' + d.ValidationType);
} else {
    System.debug('FAIL — no new DCR');

    // Check all DCR config for BusinessLicense
    List<LifeSciDataChangeDef> defs = [SELECT Id, ObjectName, IsActive FROM LifeSciDataChangeDef WHERE ObjectName = 'BusinessLicense'];
    System.debug('Defs: ' + defs);
    List<LifeSciDataChgDefRecType> rts = [SELECT Id, RecordTypeId, ValidationType FROM LifeSciDataChgDefRecType WHERE LifeSciDataChgDefId IN :defs];
    System.debug('RecType mappings: ' + rts);
    List<LifeSciDataChgDefMngFld> mfs = [SELECT Id, FieldApiName, ValidationType, CountryId FROM LifeSciDataChgDefMngFld WHERE LifeSciDataChgDefId IN :defs];
    System.debug('Managed fields: ' + mfs);
}
