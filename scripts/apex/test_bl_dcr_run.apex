// Step 2: Modify a BusinessLicense and check for DCR generation
// Run: sf apex run --file scripts/apex/test_bl_dcr_run.apex --target-org 260-pm
//
// If running as admin and no DCR is generated, the admin user may have
// SkipLifeSciencesTriggerHandlers permission. Re-run via Evan's session or
// use the UI as Evan to test.

Id hcpRecordTypeId = '012Hs000001xJ49IAE';

// Find a BusinessLicense linked to an HCP Account
List<BusinessLicense> bls = [
    SELECT Id, Name, LicenseNumber, AccountId, Account.Name, Account.RecordTypeId
    FROM BusinessLicense
    WHERE AccountId != null
    AND Account.RecordTypeId = :hcpRecordTypeId
    LIMIT 1
];
if (bls.isEmpty()) {
    System.debug('ERROR: No BusinessLicense with an HCP Account found.');
    return;
}
BusinessLicense bl = bls[0];
System.debug('BusinessLicense: ' + bl.Id + ' — ' + bl.Name);
System.debug('Account: ' + bl.Account.Name + ' (' + bl.AccountId + ')');
System.debug('Original LicenseNumber: ' + bl.LicenseNumber);

// Count DCRs before
Integer dcrBefore = [
    SELECT COUNT() FROM LifeSciDataChangeRequest
    WHERE DataChangeRecordIdentifier = :String.valueOf(bl.Id)
];
System.debug('DCRs before: ' + dcrBefore);

// Update the LicenseNumber
String newLicenseNumber = 'TEST-' + String.valueOf(Datetime.now().getTime()).right(6);
System.debug('Setting LicenseNumber to: ' + newLicenseNumber);

BusinessLicense toUpdate = new BusinessLicense(Id = bl.Id);
toUpdate.LicenseNumber = newLicenseNumber;
update toUpdate;
System.debug('Update complete.');

// Check for DCR
List<LifeSciDataChangeRequest> dcrs = [
    SELECT Id, Name, Status, OperationType, ValidationType,
           DataChangeRecordIdentifier, DataChangeInformation
    FROM LifeSciDataChangeRequest
    WHERE DataChangeRecordIdentifier = :String.valueOf(bl.Id)
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('DCRs after: ' + dcrs.size());

if (dcrs.size() > dcrBefore) {
    LifeSciDataChangeRequest dcr = dcrs[0];
    System.debug('SUCCESS — DCR generated for BusinessLicense');
    System.debug('  DCR Id:      ' + dcr.Id);
    System.debug('  DCR Name:    ' + dcr.Name);
    System.debug('  Status:      ' + dcr.Status);
    System.debug('  Operation:   ' + dcr.OperationType);
    System.debug('  Validation:  ' + dcr.ValidationType);
    System.debug('  DataChange:  ' + dcr.DataChangeInformation);
} else {
    System.debug('FAIL — No DCR generated. Troubleshooting:');
    System.debug('  1. Is LifeSciDataChangeDef active for BusinessLicense?');
    System.debug('  2. Does LifeSciDataChgDefRecType exist? Run test_bl_dcr_setup.apex first');
    System.debug('  3. Are Name and LicenseNumber managed fields?');
    System.debug('  4. Does current user have UserAdditionalInfo.PreferredCountry matching a LifeSciCountry?');
    System.debug('  5. Does current user have SkipLifeSciencesTriggerHandlers? Try as non-admin user');
    System.debug('  6. Is DCRHandler trigger active?');
}
