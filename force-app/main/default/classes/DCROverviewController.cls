public with sharing class DCROverviewController {

    @AuraEnabled(cacheable=true)
    public static List<LifeSciDataChangeRequest> getDCRsForAccount(Id accountId) {
        Set<String> relatedRecordIds = new Set<String>();

        for (HealthcareProvider hp : [
            SELECT Id FROM HealthcareProvider WHERE AccountId = :accountId
        ]) {
            relatedRecordIds.add(hp.Id);
        }

        for (ContactPointAddress cpa : [
            SELECT Id FROM ContactPointAddress WHERE ParentId = :accountId
        ]) {
            relatedRecordIds.add(cpa.Id);
        }

        for (ContactPointPhone cpp : [
            SELECT Id FROM ContactPointPhone WHERE ParentId = :accountId
        ]) {
            relatedRecordIds.add(cpp.Id);
        }

        for (ContactPointEmail cpe : [
            SELECT Id FROM ContactPointEmail WHERE ParentId = :accountId
        ]) {
            relatedRecordIds.add(cpe.Id);
        }

        for (ContactPointSocial cps : [
            SELECT Id FROM ContactPointSocial WHERE ParentReferenceRecordId = :accountId
        ]) {
            relatedRecordIds.add(cps.Id);
        }

        for (BusinessLicense bl : [
            SELECT Id FROM BusinessLicense WHERE AccountId = :accountId
        ]) {
            relatedRecordIds.add(bl.Id);
        }

        for (ProviderAffiliation pa : [
            SELECT Id FROM ProviderAffiliation WHERE AccountId = :accountId OR RelatedAccountId = :accountId
        ]) {
            relatedRecordIds.add(pa.Id);
        }

        // HealthcareProviderNpi and HealthcareProviderSpecialty link through HealthcareProvider
        Set<Id> hpIds = new Set<Id>();
        for (String rid : relatedRecordIds) {
            if (((Id) rid).getSObjectType() == HealthcareProvider.SObjectType) {
                hpIds.add((Id) rid);
            }
        }

        if (!hpIds.isEmpty()) {
            for (HealthcareProviderNpi npi : [
                SELECT Id FROM HealthcareProviderNpi WHERE PractitionerId IN :hpIds
            ]) {
                relatedRecordIds.add(npi.Id);
            }

            for (HealthcareProviderSpecialty spec : [
                SELECT Id FROM HealthcareProviderSpecialty WHERE PractitionerId IN :hpIds
            ]) {
                relatedRecordIds.add(spec.Id);
            }
        }

        // Also include the Account itself
        relatedRecordIds.add(accountId);

        if (relatedRecordIds.isEmpty()) {
            return new List<LifeSciDataChangeRequest>();
        }

        return [
            SELECT Id, Name, Status, OperationType, ValidationType,
                   DataChangeInformation, DataChangeRecordIdentifier,
                   CreatedDate, CreatedBy.Name, LastModifiedDate
            FROM LifeSciDataChangeRequest
            WHERE DataChangeRecordIdentifier IN :relatedRecordIds
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }
}
