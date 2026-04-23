@isTest(SeeAllData=true)
public class DCRIntegrationTest {

    @isTest
    static void testAccountLastNameDCR() {
        Id evanUserId = '005Hs00000ILguaIAD';
        Id hcpRecordTypeId = '012Hs000001xJ49IAE';

        List<Account> accts = [
            SELECT Id, FirstName, LastName
            FROM Account
            WHERE RecordTypeId = :hcpRecordTypeId AND IsPersonAccount = true
            LIMIT 1
        ];
        System.assert(!accts.isEmpty(), 'No HCP Person Account found');
        Account acct = accts[0];
        System.debug('Account: ' + acct.Id + ' — ' + acct.FirstName + ' ' + acct.LastName);

        Integer dcrBefore = [
            SELECT COUNT() FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(acct.Id)
        ];

        Test.startTest();
        System.runAs(new User(Id = evanUserId)) {
            update new Account(Id = acct.Id, LastName = acct.LastName + '-DCR');
        }
        Test.stopTest();

        List<LifeSciDataChangeRequest> dcrs = [
            SELECT Id, Name, Status, OperationType, ValidationType, DataChangeInformation
            FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(acct.Id)
            ORDER BY CreatedDate DESC
        ];
        System.debug('DCRs before: ' + dcrBefore + ', after: ' + dcrs.size());
        for (LifeSciDataChangeRequest d : dcrs) {
            System.debug('DCR: ' + d.Id + ' Status=' + d.Status + ' Op=' + d.OperationType);
            System.debug('  Data: ' + d.DataChangeInformation);
        }
        System.assert(dcrs.size() > dcrBefore, 'Expected a new DCR for LastName change');
    }

    @isTest
    static void testAccountGenderDCR() {
        Id evanUserId = '005Hs00000ILguaIAD';
        Id hcpRecordTypeId = '012Hs000001xJ49IAE';

        List<Account> accts = [
            SELECT Id, PersonGender
            FROM Account
            WHERE RecordTypeId = :hcpRecordTypeId AND IsPersonAccount = true
            LIMIT 1 OFFSET 3
        ];
        System.assert(!accts.isEmpty(), 'No HCP Person Account found');
        Account acct = accts[0];
        System.debug('Account: ' + acct.Id + ' Gender=' + acct.PersonGender);

        Integer dcrBefore = [
            SELECT COUNT() FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(acct.Id)
        ];

        Test.startTest();
        System.runAs(new User(Id = evanUserId)) {
            String newGender = (acct.PersonGender == 'Male') ? 'Female' : 'Male';
            update new Account(Id = acct.Id, PersonGender = newGender);
        }
        Test.stopTest();

        List<LifeSciDataChangeRequest> dcrs = [
            SELECT Id, Name, Status, OperationType, DataChangeInformation
            FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(acct.Id)
            ORDER BY CreatedDate DESC
        ];
        System.debug('DCRs before: ' + dcrBefore + ', after: ' + dcrs.size());
        for (LifeSciDataChangeRequest d : dcrs) {
            System.debug('DCR: ' + d.Id + ' Op=' + d.OperationType);
            System.debug('  Data: ' + d.DataChangeInformation);
        }
        System.assert(dcrs.size() > dcrBefore, 'Expected a new DCR for Gender change');
    }

    @isTest
    static void testBusinessLicenseDCR() {
        Id evanUserId = '005Hs00000ILguaIAD';
        Id hcpRecordTypeId = '012Hs000001xJ49IAE';

        List<BusinessLicense> bls = [
            SELECT Id, Name, LicenseNumber, AccountId
            FROM BusinessLicense
            WHERE AccountId != null AND Account.RecordTypeId = :hcpRecordTypeId
            LIMIT 1
        ];
        System.assert(!bls.isEmpty(), 'No BusinessLicense with HCP Account found');
        BusinessLicense bl = bls[0];
        System.debug('BusinessLicense: ' + bl.Id + ' — ' + bl.Name);

        Integer dcrBefore = [
            SELECT COUNT() FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(bl.Id)
        ];

        Test.startTest();
        System.runAs(new User(Id = evanUserId)) {
            update new BusinessLicense(Id = bl.Id, LicenseNumber = 'TEST-' + String.valueOf(Datetime.now().getTime()).right(6));
        }
        Test.stopTest();

        List<LifeSciDataChangeRequest> dcrs = [
            SELECT Id, Name, Status, OperationType, DataChangeInformation
            FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(bl.Id)
            ORDER BY CreatedDate DESC
        ];
        System.debug('DCRs before: ' + dcrBefore + ', after: ' + dcrs.size());
        for (LifeSciDataChangeRequest d : dcrs) {
            System.debug('DCR: ' + d.Id + ' Op=' + d.OperationType);
            System.debug('  Data: ' + d.DataChangeInformation);
        }
        System.assert(dcrs.size() > dcrBefore, 'Expected a new DCR for LicenseNumber change');
    }

    @isTest
    static void testHealthcareProviderDCR() {
        Id evanUserId = '005Hs00000ILguaIAD';
        Id hcpRecordTypeId = '012Hs000001xJ49IAE';

        List<HealthcareProvider> hcps = [
            SELECT Id, Name, ProviderType, ProfessionalTitle, AccountId, Account.RecordTypeId
            FROM HealthcareProvider
            WHERE AccountId != null AND Account.RecordTypeId = :hcpRecordTypeId
            LIMIT 1
        ];
        System.assert(!hcps.isEmpty(), 'No HealthcareProvider with HCP Account found');
        HealthcareProvider hcp = hcps[0];
        System.debug('HCP: ' + hcp.Id + ' — ' + hcp.Name);
        System.debug('  ProviderType=' + hcp.ProviderType + ' ProfessionalTitle=' + hcp.ProfessionalTitle);
        System.debug('  AccountId=' + hcp.AccountId + ' Account.RecordTypeId=' + hcp.Account.RecordTypeId);

        Integer dcrBefore = [
            SELECT COUNT() FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(hcp.Id)
        ];

        Test.startTest();
        System.runAs(new User(Id = evanUserId)) {
            String newTitle = (hcp.ProfessionalTitle == 'M.D.') ? 'D.O.' : 'M.D.';
            update new HealthcareProvider(Id = hcp.Id, ProfessionalTitle = newTitle);
        }
        Test.stopTest();

        List<LifeSciDataChangeRequest> dcrs = [
            SELECT Id, Name, Status, OperationType, DataChangeInformation
            FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier = :String.valueOf(hcp.Id)
            ORDER BY CreatedDate DESC
        ];
        System.debug('DCRs before: ' + dcrBefore + ', after: ' + dcrs.size());
        for (LifeSciDataChangeRequest d : dcrs) {
            System.debug('DCR: ' + d.Id + ' Op=' + d.OperationType);
            System.debug('  Data: ' + d.DataChangeInformation);
        }
        System.assert(dcrs.size() > dcrBefore, 'Expected a new DCR for ProfessionalTitle change');
    }
}
