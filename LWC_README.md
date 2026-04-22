# lscMobileInline_DCR_Overview

An LWC component that displays pending Data Change Requests (DCRs) on an Account record page. Designed for the LSC for Customer Engagement iPad app.

## Behavior

- **No pending DCRs**: Component renders nothing — takes up zero space on the page.
- **Pending DCRs exist**: Shows a compact warning banner: "1 pending Data Change Request".
- **User clicks the banner**: Expands to show each DCR with a before/after field comparison table.
- **User clicks again**: Collapses back to the banner.

## How It Works

`LifeSciDataChangeRequest` has no direct Account lookup field. The account relationship is stored inside the `DataChangeInformation` JSON blob, and the `DataChangeRecordIdentifier` field holds the ID of the changed record (e.g., a HealthcareProvider).

The component uses two chained GraphQL queries (no Apex controller required):

1. **Related Records Query** — Fetches IDs of all records related to the account:
   - `HealthcareProvider` (via `AccountId`)
   - `ContactPointAddress` (via `ParentId`)
   - `ContactPointPhone` (via `ParentId`)
   - `ContactPointEmail` (via `ParentId`)
   - `BusinessLicense` (via `AccountId`)

2. **DCR Query** — Finds `LifeSciDataChangeRequest` records where `DataChangeRecordIdentifier` matches any of those IDs (including the Account ID itself).

The `DataChangeInformation` JSON is parsed client-side to extract old/new field values and display the diff.

## Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `recordId` | ID | — | Automatically populated from the record page context |
| `mobileHeight` | Integer | 200 | Height of the component on mobile devices (configurable in App Builder) |

## Supported Targets

| Target | Usage |
|---|---|
| `lightning__RecordPage` | Place on Account record page via App Builder |
| `lightning__RecordAction` | Available as a screen quick action |

## Field Label Mapping

The component maps JSON field keys from `DataChangeInformation` to display labels:

| JSON Key | Display Label |
|---|---|
| `providertype` | Provider Type |
| `professionaltitle` | Professional Title |
| `name` | Name |
| `phone` | Phone |
| `fax` | Fax |
| `persongender` | Gender |
| `personmobilephone` | Mobile Phone |
| `personbirthdate` | Birthdate |
| `address` | Address |
| `status` | Status |
| `totallicensedbeds` | Total Licensed Beds |
| `providerclass` | Provider Class |
| `specialtyid` | Specialty |
| `role` | Role |
| `effectivestartdate` | Start Date |
| `effectiveenddate` | End Date |

Unmapped keys display as-is.

## Object Label Mapping

The component identifies the changed object type from the `DataChangeRecordIdentifier` key prefix:

| Prefix | Object Label |
|---|---|
| `0cm` | Healthcare Provider |
| `0cH` | Contact Point Address |
| `0cG` | Contact Point Phone |
| `0cF` | Contact Point Email |
| `07g` | Business License |
| `0c4` | Provider Affiliation |
| `001` | Account |

## Deployment

```bash
sf project deploy start --source-dir force-app/main/default/lwc/lscMobileInline_DCR_Overview --target-org <your-org-alias>
```

## Quick Action

A quick action `Account.lscMobileInline_DCR_Overview` is included in `force-app/main/default/quickActions/`. Deploy it alongside the LWC:

```bash
sf project deploy start --source-dir force-app/main/default/lwc/lscMobileInline_DCR_Overview force-app/main/default/quickActions --target-org <your-org-alias>
```

Then add the action to the Account page layout.
