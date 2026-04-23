# DCR Compound Fields

## What Are Compound Fields?

Salesforce stores certain groups of related fields as a single **compound field** internally. When the DCR engine evaluates changes, it operates on the compound field — not the individual components. This means you manage one compound field in your DCR definition, and it automatically covers all of its component fields.

## Account: Name

The `Name` field on Account (for Person Accounts) is a compound field that covers:

| Component Field | Example Value |
|---|---|
| `FirstName` | Jane |
| `LastName` | Smith |
| `MiddleName` | Marie |
| `Suffix` | Jr. |
| `Salutation` | Dr. |

### How to configure

- Add `Name` as a managed field under the Account data change definition
- Do **not** add `FirstName`, `LastName`, `MiddleName`, `Suffix`, or `Salutation` individually — the platform will reject them with "Selected field is not in the list"
- When a user edits any component (e.g., changes `FirstName` from "Jane" to "Janet"), the DCR engine detects the change through the `Name` compound field and generates a DCR

### What the DCR record looks like

The `DataChangeInformation` JSON will contain the full name components in old and new data:

```json
{
  "newdata": {
    "firstname": "Janet",
    "lastname": "Smith"
  },
  "olddata": {
    "firstname": "Jane",
    "lastname": "Smith"
  }
}
```

## ContactPointAddress: Address

The `Address` field on ContactPointAddress is a compound field that covers:

| Component Field | Example Value |
|---|---|
| `Street` | 123 Main St |
| `City` | San Francisco |
| `State` | CA |
| `PostalCode` | 94105 |
| `Country` | US |
| `StateCode` | CA |
| `CountryCode` | US |

### How to configure

- Add `Address` as a managed field under the ContactPointAddress data change definition
- Do **not** add `City`, `Street`, `PostalCode`, `State`, `Country`, `StateCode`, or `CountryCode` individually — the platform will reject them
- When a user edits any component (e.g., changes `City` from "San Francisco" to "Los Angeles"), the DCR engine detects the change through the `Address` compound field

### Why Address doesn't appear as a normal field

The `Address` compound field has a special Salesforce field type (`ADDRESS`) that is neither updateable nor createable in the schema describe. This means it won't appear alongside regular fields in standard field pickers. The DCR Field Manager admin LWC includes special handling to display ADDRESS-type fields so they can be toggled on and off.

## Admin LWC Behavior

The DCR Field Manager handles compound fields as follows:

| Field | Behavior in UI |
|---|---|
| `Name` (Account) | Appears in field list, can be toggled normally |
| `FirstName`, `LastName`, etc. | Greyed out, checkbox disabled, hint: "Covered by Name field" |
| `Address` (ContactPointAddress) | Appears in field list (special handling for ADDRESS type), can be toggled normally |
| `City`, `Street`, `PostalCode`, etc. | Greyed out, checkbox disabled, hint: "Covered by Address field" |

When an admin tries to check a component field, a toast message explains which compound field to enable instead.

## Summary

| Object | Compound Field | Components Covered | Notes |
|---|---|---|---|
| Account | `Name` | FirstName, LastName, MiddleName, Suffix, Salutation | Person Accounts only |
| ContactPointAddress | `Address` | Street, City, State, PostalCode, Country, StateCode, CountryCode | ADDRESS field type requires special handling in admin tools |
