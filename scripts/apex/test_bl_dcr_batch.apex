// Generate multiple DCRs for BusinessLicense by updating different records
// Run: sf apex run --file scripts/apex/test_bl_dcr_batch.apex --target-org 260-pm
//
// Note: Running as admin may not generate DCRs if SkipLifeSciencesTriggerHandlers
// is enabled. Use the DCRIntegrationTest class for reliable testing.

Id hcpRecordTypeId = '012Hs000001xJ49IAE';

List<BusinessLicense> bls = [
    SELECT Id, Name, LicenseNumber, AccountId, Account.Name
    FROM BusinessLicense
    WHERE AccountId != null
    AND Account.RecordTypeId = :hcpRecordTypeId
    LIMIT 5
];

if (bls.isEmpty()) {
    System.debug('ERROR: No BusinessLicense records found with HCP Accounts.');
    return;
}

System.debug('Found ' + bls.size() + ' BusinessLicense records to update.');

Integer dcrCountBefore = [
    SELECT COUNT() FROM LifeSciDataChangeRequest
    WHERE CreatedDate = TODAY
];
System.debug('Total DCRs created today (before): ' + dcrCountBefore);

String suffix = String.valueOf(Datetime.now().getTime()).right(4);
List<BusinessLicense> toUpdate = new List<BusinessLicense>();
for (Integer i = 0; i < bls.size(); i++) {
    BusinessLicense bl = bls[i];
    System.debug('  [' + (i+1) + '] ' + bl.Name + ' (Account: ' + bl.Account.Name + ')');
    BusinessLicense upd = new BusinessLicense(Id = bl.Id);
    upd.LicenseNumber = 'BATCH-' + suffix + '-' + (i+1);
    toUpdate.add(upd);
}

update toUpdate;
System.debug('Updated ' + toUpdate.size() + ' BusinessLicense records.');

Integer dcrCountAfter = [
    SELECT COUNT() FROM LifeSciDataChangeRequest
    WHERE CreatedDate = TODAY
];
System.debug('Total DCRs created today (after): ' + dcrCountAfter);
Integer newDcrs = dcrCountAfter - dcrCountBefore;
System.debug('New DCRs generated: ' + newDcrs);

if (newDcrs > 0) {
    List<LifeSciDataChangeRequest> latestDcrs = [
        SELECT Id, Name, Status, OperationType, ValidationType,
               DataChangeRecordIdentifier, DataChangeInformation
        FROM LifeSciDataChangeRequest
        WHERE CreatedDate = TODAY
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];
    for (LifeSciDataChangeRequest dcr : latestDcrs) {
        System.debug('  DCR: ' + dcr.Name + ' | Status: ' + dcr.Status +
                     ' | Op: ' + dcr.OperationType + ' | Val: ' + dcr.ValidationType +
                     ' | Record: ' + dcr.DataChangeRecordIdentifier);
    }
} else {
    System.debug('FAIL — No DCRs generated. Check:');
    System.debug('  1. Admin may have SkipLifeSciencesTriggerHandlers — run as non-admin');
    System.debug('  2. RecType mapping exists? Run test_bl_dcr_setup.apex first');
    System.debug('  3. LicenseNumber is a managed field with matching ValidationType');
}
