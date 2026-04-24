// Generate multiple BusinessLicense DCRs by updating records as Evan via the UI
//
// IMPORTANT: This script must be run as Evan Casto (or another non-admin user)
// to generate DCRs. Admin users have SkipLifeSciencesTriggerHandlers.
//
// To run as Evan: Log in as Evan, then open Developer Console > Execute Anonymous
// Or use the UI to edit BusinessLicense records directly.
//
// Run: sf apex run --file scripts/apex/generate_bl_dcrs.apex --target-org 260-pm

Id hcpRecordTypeId = '012Hs000001xJ49IAE';

// Find up to 5 BusinessLicense records linked to HCP accounts
List<BusinessLicense> bls = [
    SELECT Id, Name, LicenseNumber, AccountId, Account.Name
    FROM BusinessLicense
    WHERE AccountId != null
    AND Account.RecordTypeId = :hcpRecordTypeId
    LIMIT 5
];

System.debug('Found ' + bls.size() + ' BusinessLicense records');
System.debug('Running as: ' + UserInfo.getName() + ' (' + UserInfo.getUserId() + ')');

if (bls.isEmpty()) {
    System.debug('ERROR: No BusinessLicense records found with HCP accounts');
    return;
}

String suffix = String.valueOf(Datetime.now().getTime()).right(4);
List<BusinessLicense> toUpdate = new List<BusinessLicense>();

for (Integer i = 0; i < bls.size(); i++) {
    BusinessLicense bl = bls[i];
    System.debug('[' + (i+1) + '] ' + bl.Name + ' (Account: ' + bl.Account.Name + ') LicenseNumber: ' + bl.LicenseNumber);
    toUpdate.add(new BusinessLicense(
        Id = bl.Id,
        LicenseNumber = 'GEN-' + suffix + '-' + (i+1)
    ));
}

update toUpdate;
System.debug('Updated ' + toUpdate.size() + ' BusinessLicense records');

// Check for new DCRs (may not appear immediately if async)
Set<String> blIds = new Set<String>();
for (BusinessLicense bl : bls) blIds.add(String.valueOf(bl.Id));

List<LifeSciDataChangeRequest> dcrs = [
    SELECT Id, Name, Status, OperationType, ValidationType, DataChangeRecordIdentifier, CreatedDate
    FROM LifeSciDataChangeRequest
    WHERE DataChangeRecordIdentifier IN :blIds
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
];

System.debug('DCRs found for these BusinessLicense records today: ' + dcrs.size());
for (LifeSciDataChangeRequest d : dcrs) {
    System.debug('  ' + d.Name + ' | ' + d.Status + ' | Record: ' + d.DataChangeRecordIdentifier);
}

if (dcrs.isEmpty()) {
    System.debug('No DCRs yet — if running as admin, DCRs will not be generated.');
    System.debug('Log in as a non-admin user (e.g., Evan Casto) and run from Developer Console.');
}
