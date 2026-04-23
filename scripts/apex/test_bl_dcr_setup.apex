// Step 1: Ensure BusinessLicense has a RecType mapping for DCR
// Run: sf apex run --file scripts/apex/test_bl_dcr_setup.apex --target-org 260-pm

Id blDefId = '1MuHs000000Cab7KAC';
Id hcpRecordTypeId = '012Hs000001xJ49IAE'; // Health Care Provider

List<LifeSciDataChgDefRecType> existingRt = [
    SELECT Id FROM LifeSciDataChgDefRecType
    WHERE LifeSciDataChgDefId = :blDefId
];
if (existingRt.isEmpty()) {
    LifeSciDataChgDefRecType rt = new LifeSciDataChgDefRecType();
    rt.LifeSciDataChgDefId = blDefId;
    rt.RecordTypeId = hcpRecordTypeId;
    rt.ValidationType = 'Internal';
    rt.IsNewRecApprovalRequired = true;
    insert rt;
    System.debug('Created RecType mapping: ' + rt.Id);
} else {
    System.debug('RecType mapping already exists: ' + existingRt[0].Id);
}

System.debug('Setup complete. Now run test_bl_dcr_run.apex');
