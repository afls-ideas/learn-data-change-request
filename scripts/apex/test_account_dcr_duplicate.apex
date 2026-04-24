// Test: Does Account generate a 2nd DCR if one already exists?
// Run: sf apex run --file scripts/apex/test_account_dcr_duplicate.apex --target-org 260-pm

Id hcpRecordTypeId = '012Hs000001xJ49IAE';

// Pick an Account that does NOT already have a DCR today
// DCR uses DataChangeRecordIdentifier (text) to store the record Id
Set<String> acctIdsWithDcr = new Set<String>();
for (LifeSciDataChangeRequest dcr : [
    SELECT DataChangeRecordIdentifier FROM LifeSciDataChangeRequest
    WHERE CreatedDate = TODAY AND DataChangeRecordIdentifier != null
]) {
    acctIdsWithDcr.add(dcr.DataChangeRecordIdentifier);
}

List<Account> candidates = [
    SELECT Id, Name, LastName, MiddleName
    FROM Account
    WHERE RecordTypeId = :hcpRecordTypeId
    LIMIT 50
];

Account acct;
for (Account a : candidates) {
    if (!acctIdsWithDcr.contains(a.Id)) {
        acct = a;
        break;
    }
}

if (acct == null) {
    System.debug('ERROR: No HCP Account without an existing DCR today.');
    return;
}

System.debug('Using Account: ' + acct.Name + ' (' + acct.Id + ')');
System.debug('Current MiddleName: ' + acct.MiddleName);
System.debug('Current LastName: ' + acct.LastName);

// --- Round 1: Update to generate first DCR ---
Integer dcrBefore1 = [SELECT COUNT() FROM LifeSciDataChangeRequest WHERE DataChangeRecordIdentifier = :acct.Id];
System.debug('');
System.debug('=== ROUND 1: First update ===');
System.debug('DCRs on this Account before: ' + dcrBefore1);

String suffix1 = String.valueOf(Datetime.now().getTime()).right(4);
Account upd1 = new Account(Id = acct.Id, MiddleName = 'Test-R1-' + suffix1);
update upd1;
System.debug('Updated MiddleName → ' + upd1.MiddleName);

Integer dcrAfter1 = [SELECT COUNT() FROM LifeSciDataChangeRequest WHERE DataChangeRecordIdentifier = :acct.Id];
System.debug('DCRs on this Account after: ' + dcrAfter1);
System.debug('New DCRs from Round 1: ' + (dcrAfter1 - dcrBefore1));

if (dcrAfter1 == dcrBefore1) {
    System.debug('FAIL — Round 1 did not generate a DCR. Cannot proceed to Round 2.');
    return;
}

// Show the DCR
List<LifeSciDataChangeRequest> round1Dcrs = [
    SELECT Id, Name, Status, ValidationType, DataChangeInformation
    FROM LifeSciDataChangeRequest
    WHERE DataChangeRecordIdentifier = :acct.Id
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('Round 1 DCR: ' + round1Dcrs[0].Name + ' | Status: ' + round1Dcrs[0].Status);

// --- Round 2: Update again while DCR exists ---
System.debug('');
System.debug('=== ROUND 2: Second update (DCR already exists) ===');
Integer dcrBefore2 = [SELECT COUNT() FROM LifeSciDataChangeRequest WHERE DataChangeRecordIdentifier = :acct.Id];
System.debug('DCRs on this Account before: ' + dcrBefore2);

String suffix2 = String.valueOf(Datetime.now().getTime()).right(4);
Account upd2 = new Account(Id = acct.Id, LastName = 'TestR2-' + suffix2);
update upd2;
System.debug('Updated LastName → ' + upd2.LastName);

Integer dcrAfter2 = [SELECT COUNT() FROM LifeSciDataChangeRequest WHERE DataChangeRecordIdentifier = :acct.Id];
System.debug('DCRs on this Account after: ' + dcrAfter2);
System.debug('New DCRs from Round 2: ' + (dcrAfter2 - dcrBefore2));

if (dcrAfter2 > dcrBefore2) {
    System.debug('SUCCESS — 2nd DCR generated even with existing DCR.');
    List<LifeSciDataChangeRequest> allDcrs = [
        SELECT Id, Name, Status, ValidationType, CreatedDate
        FROM LifeSciDataChangeRequest
        WHERE DataChangeRecordIdentifier = :acct.Id
        ORDER BY CreatedDate DESC
    ];
    for (LifeSciDataChangeRequest d : allDcrs) {
        System.debug('  ' + d.Name + ' | Status: ' + d.Status + ' | Val: ' + d.ValidationType + ' | Created: ' + d.CreatedDate);
    }
} else {
    System.debug('FAIL — 2nd DCR NOT generated. Existing DCR may block new ones.');
    System.debug('Existing DCR status: ' + round1Dcrs[0].Status);
    System.debug('This suggests the DCR engine skips records that already have a pending/qualified DCR.');
}
