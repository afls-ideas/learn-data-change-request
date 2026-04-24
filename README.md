# Data Change Request (DCR) Setup Guide

## Overview

Data Change Request (DCR) governs how data changes are submitted, validated, and implemented across LSC for Customer Engagement. It prevents unapproved changes from being applied and ensures data consistency across web and mobile apps.

**Supported Objects:** Account, HealthcareProvider, HealthcareProviderSpecialty, HealthcareProviderNpi, ContactPointAddress, ContactPointPhone, ContactPointSocial, ContactPointEmail, BusinessLicense, ProviderAffiliation.

## Data Model

```mermaid
erDiagram
    Account ||--o{ HealthcareProvider : "AccountId"
    Account ||--o{ ContactPointAddress : "ParentId"
    Account ||--o{ ContactPointPhone : "ParentId"
    Account ||--o{ ContactPointEmail : "ParentId"
    Account ||--o{ ContactPointSocial : "ParentReferenceRecordId"
    Account ||--o{ BusinessLicense : "AccountId"
    Account ||--o{ ProviderAffiliation : "AccountId / RelatedAccountId"
    HealthcareProvider ||--o{ HealthcareProviderNpi : "PractitionerId"
    HealthcareProvider ||--o{ HealthcareProviderSpecialty : "PractitionerId"

    LifeSciDataChangeDef ||--o{ LifeSciDataChgDefMngFld : "LifeSciDataChgDefId"
    LifeSciDataChangeDef ||--o{ LifeSciDataChgDefRecType : "LifeSciDataChgDefId"
    LifeSciDataChangeDef ||--o{ LifeSciDataChgPersonaDef : "LifeSciDataChgDefId"
    LifeSciDataChangeDef ||--o{ LifeSciDataChangeRequest : "LifeSciDataChgDefId"
    LifeSciDataChangeRequest ||--o{ LifeSciDataChangeRequest : "ParentDataChangeRequestId"

    Account {
        Id Id
        string Name
        string RecordTypeId
    }
    HealthcareProvider {
        Id Id
        Id AccountId
        string ProfessionalTitle
        string ProviderType
    }
    ContactPointAddress {
        Id Id
        Id ParentId
        string Address
    }
    ContactPointPhone {
        Id Id
        Id ParentId
    }
    ContactPointEmail {
        Id Id
        Id ParentId
    }
    ContactPointSocial {
        Id Id
        Id ParentReferenceRecordId
    }
    BusinessLicense {
        Id Id
        Id AccountId
    }
    ProviderAffiliation {
        Id Id
        Id AccountId
        Id RelatedAccountId
        string Role
    }
    HealthcareProviderNpi {
        Id Id
        Id PractitionerId
    }
    HealthcareProviderSpecialty {
        Id Id
        Id PractitionerId
        Id SpecialtyId
    }
    LifeSciDataChangeDef {
        Id Id
        string DeveloperName
        string ObjectName
        boolean IsActive
    }
    LifeSciDataChgDefMngFld {
        Id Id
        Id LifeSciDataChgDefId
        string FieldApiName
        boolean ApplyChangeImmediately
        string ValidationType
        Id CountryId
    }
    LifeSciDataChgDefRecType {
        Id Id
        Id LifeSciDataChgDefId
        Id RecordTypeId
        string ValidationType
        boolean NewRecApprovalRequired
        Id CountryId
        string ExternalValidationSysName
    }
    LifeSciDataChgPersonaDef {
        Id Id
        Id LifeSciDataChgDefId
        Id ProfileId
        string ChangeUpdateType
        boolean IsActive
    }
    LifeSciDataChangeRequest {
        Id Id
        string Name
        Id LifeSciDataChgDefId
        Id ParentDataChangeRequestId
        string Status
        string OperationType
        string ValidationType
        string DataChangeRecordIdentifier
        text DataChangeInformation
    }
```

The `LifeSciDataChangeRequest` has **no direct Account lookup**. The account relationship is indirect -- `DataChangeRecordIdentifier` stores the ID of the changed record (e.g., a HealthcareProvider), and the `DataChangeInformation` JSON contains the `accountid` field within the old/new data payloads.

## DCR Object Reference

| Object | UI Location | Storage Type |
|---|---|---|
| `LifeSciDataChangeDef` | Admin Console > Data Change Request — Source Object dropdown and Object Status toggle. Only Account is shown; dropdown is greyed out. All 10 object definitions exist in the database but are not individually selectable from this page. | Salesforce data record |
| `LifeSciDataChgDefRecType` | Admin Console > Data Change Request Validation Types — configure record type mappings, validation type, and external system per object. See [LifeSciDataChgDefRecType.md](LifeSciDataChgDefRecType.md). Also available via App Launcher > Life Science Data Change Definition Record Types. | Salesforce data record |
| `LifeSciDataChgDefMngFld` | App Launcher > Life Science Data Change Definition Managed Fields | Salesforce data record |
| `LifeSciDataChgPersonaDef` | Admin Console > Data Change Request > Profile Settings section (Account only); or App Launcher > Life Science Data Change Persona Definitions | Salesforce data record |
| `LifeSciDataChangeRequest` | DCR Approval tab (`lsc4ce:dataChangeListWithApproveReject`); or directly on Account record page via `lscMobileInline_DCR_Overview` LWC | Salesforce data record (transactional) |

All five objects are standard Salesforce data records (not metadata/custom metadata types). They are queried via SOQL and can be created, updated, and deleted through standard DML. The `LifeSciDataChangeDef` records are pre-seeded (10 records, one per supported object) and toggled active/inactive — they are not created manually. The Admin Console Data Change Request page only surfaces Account; other objects are managed via App Launcher object tabs or SOQL.

## How DCR Works (Trigger Flow)

When a user saves a record change, the DCR engine runs in this order:

1. **LifeSciDataChangeDef** — Is there an active definition for this object?
2. **LifeSciDataChgDefRecType** — Which record type mapping applies? Determines Internal vs External validation path.
3. **LifeSciDataChgDefMngFld** — Which fields are governed? Only changes to managed fields generate a DCR.
4. **LifeSciDataChgPersonaDef** — Is there a profile-specific persona? If not, all profiles are included by default.
5. **LifeSciDataChangeRequest** — A DCR record is created with old/new data in JSON format.

**Minimum required to generate DCRs:** An active `LifeSciDataChangeDef`, at least one `LifeSciDataChgDefRecType`, and at least one `LifeSciDataChgDefMngFld`. Persona definitions are optional — when none exist, all profiles generate DCRs.

## Configuration Requirements

For DCR to trigger on any object, you need these child records under each `LifeSciDataChangeDef`:

| Config Record | Purpose | Required? | Country-Scoped? |
|---|---|---|---|
| `LifeSciDataChgDefRecType` | Maps an Account record type to a validation path (Internal/External) | **Yes** | Yes (optional `CountryId`) |
| `LifeSciDataChgDefMngFld` | Defines which specific fields are tracked for changes | **Yes** | Yes (optional `CountryId`) |
| `LifeSciDataChgPersonaDef` | Restricts or customizes DCR behavior per profile | **No** — defaults to all profiles | No |

**Key insight:** `LifeSciDataChgPersonaDef` is optional. When no persona definition exists for an object, the platform treats all profiles as DCR-enabled. You only need persona definitions when you want to **restrict** which profiles trigger DCRs or **customize** the change update behavior (e.g., apply immediately vs. hold for approval) per profile.

## Record Type Routing (Internal vs External)

The `RecordTypeId` on `LifeSciDataChgDefRecType` refers to **Account record types** (e.g., Health Care Provider, Health Care Organization), not record types on the target object itself. This is because the Account record type determines the validation path for all related objects.

You can create **multiple record type mappings** per definition to route different account types through different validation:

| Account Record Type | Validation Type | External System |
|---|---|---|
| Health Care Provider (HCP) | Internal | — |
| Health Care Organization (HCO) | External | OneKey |

When a ContactPointAddress (or any related object) is edited, the DCR engine looks at the **parent Account's record type** to decide which validation path to use. This means the same object definition can produce Internal DCRs for HCP accounts and External DCRs for HCO accounts.

### Validation Type Alignment (Critical)

The `ValidationType` on managed fields must align with the `ValidationType` on the record type mapping. If the record type mapping is `Internal` but a managed field is `External`, the DCR engine silently skips the field — no DCR is generated and no error is raised.

| RecType Mapping ValidationType | Managed Field ValidationType | Result |
|---|---|---|
| Internal | Internal | DCR generated |
| External | External | DCR generated |
| Internal | External | **No DCR — silent skip** |
| External | Internal | **No DCR — silent skip** |

**This is the most common reason DCRs fail silently.** When troubleshooting, always verify that managed field validation types match the record type mapping.

### Each Object Needs Its Own Record Type Mapping

Despite the UI showing "Inherits from Account" for related objects, **each object definition needs its own `LifeSciDataChgDefRecType` record** for the DCR trigger to fire. The "inheritance" displayed in the admin LWC is a visual convenience — the underlying engine requires an explicit mapping per definition.

Objects that need their own RecType mapping:
- Account
- HealthcareProvider
- ContactPointAddress
- ContactPointEmail
- ContactPointPhone
- ContactPointSocial
- BusinessLicense
- ProviderAffiliation
- HealthcareProviderNpi
- HealthcareProviderSpecialty

All of these map to **Account record types** (e.g., Health Care Provider, Health Care Organization), not record types on the target object.

For a detailed guide on Internal vs. External validation paths, external data providers (IQVIA OneKey), and mixed validation setups, see [VALIDATION_TYPES.md](VALIDATION_TYPES.md).

## Setup Checklist

### 1. Data Change Definitions

Activate Data Change Definitions for each object you want DCR to govern:

**Admin Console > Data Change Request** (left nav) — toggle Object Status on. Note: this page only shows Account; other objects are managed via the DCR Field Manager LWC or directly via SOQL.

### 2. Record Type Definitions (REQUIRED)

Create `LifeSciDataChgDefRecType` records to map each definition to an Account record type. This tells the platform which validation path to use (Internal vs External) based on the Account's record type.

**Steps:**
1. App Launcher > **Life Science Data Change Definition Record Types** > New
2. Select the parent Data Change Definition (e.g., ContactPointAddress)
3. Select the Account Record Type (e.g., Health Care Provider or Health Care Organization)
4. Set Validation Type: `Internal` or `External`
5. If External, set the External Validation System Name (e.g., "OneKey")
6. Optionally set Country (only DCRs for records in that country will use this mapping)
7. Set "Is New Record Approval Required" as needed
8. Repeat for each Account record type that needs a different validation path

**Or use the DCR Field Manager admin LWC** (see below) — click an object tile and use the "Add Record Type" button.

### 3. Persona Definitions (OPTIONAL)

Create `LifeSciDataChgPersonaDef` records to customize which user profiles trigger DCR processing and how their changes are handled. **When no persona definition exists, all profiles generate DCRs.**

**Steps:**
1. App Launcher > **Life Science Data Change Persona Definitions** > New
2. Select the parent Data Change Definition
3. Select a Profile (or leave blank for "All Profiles")
4. Set Change Update Type:
   - `DoNotApplyChangesImmediately` — Changes are held pending approval
   - `ApplyChangesImmediately` — Changes are applied immediately; DCR created for review
   - `ApplyChangesByField` — Per-field control using each managed field's "Apply Immediately" setting
5. Set IsActive = true

**Or use the DCR Field Manager admin LWC** — click an object tile and use the "Add Profile" button.

### 4. Managed Fields (REQUIRED)

Create `LifeSciDataChgDefMngFld` records to define which fields are tracked for changes. Only changes to managed fields generate a DCR.

**Steps:**
1. App Launcher > **Life Science Data Change Definition Managed Fields** > New
2. Select the parent Data Change Definition (e.g., ContactPointAddress)
3. Enter the Field API Name from the picklist
4. Set Validation Type (Internal or External — should align with your record type definition)
5. Optionally set "Apply Change Immediately" per field
6. Optionally set Country to scope the field governance to a specific country
7. Repeat for all governed fields

**Important notes on Field API Name:**
- Compound fields (like `Address` on ContactPointAddress and `Name` on Account) must be managed as the compound field, not individual components (City, Street, PostalCode are not valid — use `Address` instead; FirstName, LastName are not valid — use `Name` instead). See [COMPOUND_FIELDS.md](COMPOUND_FIELDS.md) for full details.
- The picklist only shows fields that belong to the definition's object
- Not all fields are eligible — only updateable/createable, non-calculated fields appear (exception: compound fields like `Address` are included by the admin LWC despite not being updateable)

**Or use the DCR Field Manager admin LWC** — click an object tile and toggle checkboxes for each field.

### 5. Country Scoping

Country scoping is optional but affects multiple levels:

| Level | Field | Effect |
|---|---|---|
| `LifeSciDataChgDefRecType` | `CountryId` | Only applies this record type mapping when the user's country matches |
| `LifeSciDataChgDefMngFld` | `CountryId` | Only governs this field when the user's country matches |
| `LifeSciDataChgPersonaDef` | *(none)* | Persona definitions are NOT country-scoped — they apply globally per profile |

**If a managed field has a country set, it will only trigger DCR for users whose `UserAdditionalInfo.PreferredCountry` matches that country's ISO code.** To make a field universally governed, leave the Country field blank.

**Important:** Even when managed fields and record type mappings have no country set, the user's `PreferredCountry` must still resolve to a valid `LifeSciCountry` record. If the user's `PreferredCountry` is "IN" but no `LifeSciCountry` exists for India, the DCR engine silently skips the record — no DCR is generated and no error is raised.

For a detailed guide on global vs. country-scoped fields, multi-country setup examples, and common pitfalls, see [COUNTRY_SCOPING.md](COUNTRY_SCOPING.md).

### 6. DCRHandler Trigger Verification

Confirm the DCRHandler trigger handler is active:

**Admin Console > Trigger Handler Administration**

DCRHandler should be active by default.

### 7. UserAdditionalInfo Records

Create `UserAdditionalInfo` records for authenticated users with:
- Preferred country (`PreferredCountry` picklist — e.g., "US")
- The `PreferredCountry` value **must match** an existing `LifeSciCountry` ISO code. If no matching `LifeSciCountry` record exists, DCRs will not be generated for that user — even when managed fields have no country restriction.

This is required for country-specific validation routing and is validated by the DCR engine at runtime.

### 8. DCR Approval Tab

Create a Lightning Component Tab for approving/rejecting DCRs:

1. Setup > Tabs > Lightning Component Tabs > New
2. Select component: `lsc4ce:dataChangeListWithApproveReject`
3. Set label, name, and assign to appropriate profiles

### 9. Mobile DB Schema Records

Ensure these DB Schema records exist and are active:

| DB Schema Record | Type |
|---|---|
| DbSchema_LifeSciDataChangeDef | Configuration |
| DbSchema_LifeSciDataChgDefRecType | Configuration |
| DbSchema_LifeSciDataChgPersonaDef | Configuration |
| DbSchema_LifeSciDataChangeRequest | Data |
| DbSchema_LifeSciDataChgDefMngFld | Data |
| DbSchema_UserAdditionalInfo | Data |
| DbSchema_LifeSciCountry | Data |

After creating/verifying, **regenerate the metadata cache**.

## How to Trigger a DCR

Once setup is complete:

1. **Log in as a user** with any profile (or a profile specified in a Persona Definition)
2. **Edit a record** on a DCR-enabled object — change a field that has a managed field definition
3. **Save** — the system creates a `LifeSciDataChangeRequest` record automatically
4. **On mobile**: Update records via Account Details, Related tab, or Bulk Updates — changes sync and create DCRs
5. **Admin approves/rejects** via the DCR approval tab or directly on the record

## Troubleshooting: DCR Not Generated

If editing a managed field doesn't create a DCR record, check in this order:

1. **LifeSciDataChangeDef active?** — The definition for the object must have `IsActive = true`
2. **LifeSciDataChgDefRecType exists for this object?** — Each object definition needs its own record type mapping. Without this, the trigger skips the object entirely. The `RecordTypeId` must be an **Account record type** (e.g., Health Care Provider), not a record type on the target object. Related objects do NOT inherit the Account mapping — they need their own.
3. **Validation type mismatch?** — The `ValidationType` on the managed field must match the `ValidationType` on the record type mapping. If the RecType mapping is `Internal` but the managed field is `External` (or vice versa), the DCR engine silently skips the field. **This is the most common silent failure.**
4. **LifeSciDataChgDefMngFld exists for the field?** — The specific field being changed must have a managed field record under the correct definition.
5. **Country mismatch on managed field?** — If the managed field has a `CountryId`, the user's `UserAdditionalInfo.PreferredCountry` must match. Remove the country from the managed field to make it universal.
6. **No matching LifeSciCountry?** — The user's `PreferredCountry` must resolve to a valid `LifeSciCountry` record. If the user's country is "IN" but no `LifeSciCountry` exists for India, DCRs are silently skipped — even when managed fields have no country restriction. Check: `SELECT Id, IsoCode FROM LifeSciCountry` and compare against the user's `UserAdditionalInfo.PreferredCountry`.
7. **Compound field?** — For ContactPointAddress, you must manage the `Address` compound field, not individual components like `City` or `Street`. For Account, manage `Name` — not `FirstName` or `LastName`.
8. **Restricted picklist values?** — Some fields like `HealthcareProvider.ProfessionalTitle` are restricted picklists. Valid values are `M.D.`, `D.O.`, `D.D.S`, `Ph.D`, `D.M.V`. Setting an invalid value throws a DML error, not a silent skip.
9. **DCRHandler active?** — Check Admin Console > Trigger Handler Administration
10. **User has SkipLifeSciencesTriggerHandlers permission?** — The trigger checks this first. Admin users may have this permission enabled, which bypasses all DCR processing. Test with a non-admin user to confirm.

## DCR Behavior by Profile Setting

| Setting | Web Behavior | Mobile Behavior |
|---|---|---|
| No persona definition | All profiles generate DCRs with default behavior | All profiles generate DCRs with default behavior |
| Don't apply changes immediately | DCR sent for approval first | Changes appear after approval + next sync |
| Apply changes immediately | Changes applied; DCR created for review | Changes applied immediately; reverted on next sync if rejected |
| Apply changes to each field individually | Per-field control via managed field config | Per-field control via managed field config |

## Validation Types

| Type | Managed By | Notes |
|---|---|---|
| Internal | Your organization | Supports "Requires Approval" toggle for record creation |
| External | External validation system (e.g., OneKey) | Only Create and Update operations supported; Delete is rejected |

## Mandatory Fields for External Validation

| Object | Required Fields |
|---|---|
| Account | Name, Phone, Fax, PersonGender, PersonMobilePhone, PersonBirthdate |
| ContactPointAddress | Name, Address |
| HealthcareProvider | Name, Status, ProfessionalTitle, TotalLicensedBeds, ProviderType, ProviderClass |
| HealthcareProviderSpecialty | Name, SpecialtyId |
| ProviderAffiliation | Role, EffectiveStartDate, EffectiveEndDate |

## External Validation Requirements

- **Create HCO**: Must include Account, ContactPointAddress, HealthcareProvider, HealthcareProviderSpecialty
- **Create HCP**: Must include all HCO objects + ProviderAffiliation
- **Person Account**: Requires at least one primary Provider Affiliation and one primary Healthcare Provider Specialty
- **Business Account**: Requires at least one primary Healthcare Provider Specialty
- **Picklist Alignment**: Every Salesforce picklist value must have a corresponding mapping in your integration layer or the DCR will fail with "Missing Fields" error

## DCR Status Flow

`NotProcessed` > `Qualified` / `NotQualified` > `Processed` / `Failed` > `Approved` / `Rejected` / `Retry`

## LWC Components

### lscMobileInline_DCR_Overview

A compact LWC that shows pending Data Change Requests on an Account record page. Renders nothing when there are no pending DCRs; shows an expandable banner with before/after field diffs when there are. Uses GraphQL — no Apex controller required.

See the full component documentation: [LWC_README.md](LWC_README.md)

### dcrFieldManager

An admin LWC for managing DCR field definitions across all objects. Provides a visual tile-based UI showing which objects have DCR enabled and allows toggling individual fields on/off.

**Features:**
- Country filter at the top
- Object tiles showing DCR status: lock icon + "DCR Enabled" with green left border when configured, "DCR Not Enabled" when missing record type mapping
- Grey chips showing Record Type and Profile assignments per object
- Click a tile to see all fields with checkboxes to toggle DCR governance
- Add/remove Record Type mappings (Account record types) directly from the UI
- Add/remove Profile assignments (persona definitions) from the UI
- Inline controls for Validation Type and Apply Immediately per field

**Access:** Custom tab "DCR Field Manager" with permission set `DCR_Field_Manager_Access`.

## Integration Tests

`DCRIntegrationTest` is an Apex test class that verifies DCR generation across four objects using `System.runAs()` to execute as a non-admin user (Evan Casto — Field Sales Representative profile). Uses `@isTest(SeeAllData=true)` because it relies on live DCR definitions, managed fields, record type mappings, and existing Account/HealthcareProvider/BusinessLicense data.

### Test Methods

| Test Method | Object | Field Changed | What It Verifies |
|---|---|---|---|
| `testAccountLastNameDCR` | Account | LastName (via Name compound field) | Compound field DCR generation |
| `testAccountGenderDCR` | Account | PersonGender | Standard picklist field DCR |
| `testBusinessLicenseDCR` | BusinessLicense | LicenseNumber | Related object DCR with own RecType mapping |
| `testHealthcareProviderDCR` | HealthcareProvider | ProfessionalTitle | Restricted picklist field DCR (valid values: M.D., D.O., D.D.S, Ph.D, D.M.V) |

### Running

```bash
sf apex run test --class-names DCRIntegrationTest --result-format human --synchronous --target-org 260-pm
```

### Prerequisites

These tests depend on org configuration. If a test fails, verify:

1. The object's `LifeSciDataChangeDef` is active
2. A `LifeSciDataChgDefRecType` exists for the object (each object needs its own — they don't inherit)
3. Managed field `ValidationType` matches the RecType mapping `ValidationType` (both must be `Internal` or both `External`)
4. The test user (Evan) has a `UserAdditionalInfo` record with `PreferredCountry = US`
5. A `LifeSciCountry` record exists with `IsoCode = US`

### Standalone Test Scripts

For quick ad-hoc testing without the test framework:

| Script | Purpose |
|---|---|
| `scripts/apex/test_bl_dcr_setup.apex` | Creates the RecType mapping for BusinessLicense (run once) |
| `scripts/apex/test_bl_dcr_run.apex` | Updates a BusinessLicense and checks for DCR generation |

Run via: `sf apex run --file scripts/apex/<script> --target-org 260-pm`

**Note:** Anonymous Apex scripts run as the current admin user. If the admin has `SkipLifeSciencesTriggerHandlers` or similar permissions, DCRs won't generate. The `DCRIntegrationTest` class avoids this by using `System.runAs()` with a non-admin user.

## Additional Documentation

| Document | Description |
|---|---|
| [LifeSciDataChgDefRecType.md](LifeSciDataChgDefRecType.md) | Why HCP/HCO use External validation and custom record types use Internal — business rationale and Admin Console setup |
| [COMPOUND_FIELDS.md](COMPOUND_FIELDS.md) | Account Name and ContactPointAddress Address compound field handling |
| [VALIDATION_TYPES.md](VALIDATION_TYPES.md) | Internal vs. External validation, detailed routing logic, IQVIA OneKey integration |
| [COUNTRY_SCOPING.md](COUNTRY_SCOPING.md) | Global vs. country-scoped fields, multi-country setup, common pitfalls |
| [LWC_README.md](LWC_README.md) | lscMobileInline_DCR_Overview component documentation |
