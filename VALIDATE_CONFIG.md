# DCR Validate Config

## Overview

The **Validate Config** tab in the DCR Field Manager runs automated checks against your org's DCR configuration to detect mismatches that cause DCRs to silently fail. These are the most common reasons a field rep edits a record and no DCR is generated — no error, no warning, just nothing.

**Access:** DCR Field Manager tab > Step 3: Validate Config > Run Validation

## Validation Checks

### Check 1: Managed Field vs Record Type Mapping Validation Type

**What it checks:** For each object, every managed field's `ValidationType` must match at least one `LifeSciDataChgDefRecType` mapping's `ValidationType` on the same object.

**Why it matters:** The DCR engine uses the managed field's `ValidationType` to find a matching record type mapping. If the field says Internal but all record type mappings say External (or vice versa), the engine finds no matching path and silently skips — no DCR is created.

**Example failure:**

| Object | Record Type Mapping | Managed Field | Result |
|---|---|---|---|
| Account | HCP → External | `PersonGender` → Internal | **Silent skip** — no Internal mapping exists |
| Account | HCP → External | `Name` → External | OK — matches |

**Fix:** Either change the managed field's `ValidationType` to match a record type mapping, or add a second record type mapping with the missing validation type. For example, if you need both Internal and External fields on Account for the HCP record type, create two mappings: `HCP → Internal` and `HCP → External`.

### Check 2: Parent-Child Validation Type Alignment

**What it checks:** For each child object (HealthcareProvider, BusinessLicense, ContactPointAddress, etc.), its `LifeSciDataChgDefRecType` validation type must match Account's mapping for the **same Account record type**.

**Why it matters:** All record type mappings reference Account record types (e.g., Health Care Provider, Health Care Organization). When the DCR engine processes a child object, it cross-references the parent Account's record type mapping. If Account maps HCP → External but BusinessLicense maps HCP → Internal, the engine sees a parent-child conflict and silently skips the child object.

**Example failure:**

| Object | Record Type | Validation Type | Result |
|---|---|---|---|
| Account | Health Care Provider | External | — |
| BusinessLicense | Health Care Provider | Internal | **Silent skip** — doesn't match Account |
| HealthcareProvider | Health Care Provider | Internal | **Silent skip** — doesn't match Account |
| ContactPointAddress | Health Care Provider | Internal | **Silent skip** — doesn't match Account |

**Fix:** Align all child objects to match Account's validation type for the same record type. If Account uses External for HCP, the children must also use External. Alternatively, add an Internal mapping to Account for HCP so both paths are available.

**Correctly aligned example:**

| Object | Record Type | Validation Type |
|---|---|---|
| Account | Health Care Provider | External |
| BusinessLicense | Health Care Provider | External |
| HealthcareProvider | Health Care Provider | External |
| ContactPointAddress | Health Care Provider | External |

Or, with mixed validation on Account:

| Object | Record Type | Validation Type |
|---|---|---|
| Account | Health Care Provider | External |
| Account | Health Care Provider | Internal |
| BusinessLicense | Health Care Provider | Internal |
| HealthcareProvider | Health Care Provider | External |

## Result Severity Levels

| Severity | Meaning |
|---|---|
| Error (red) | Configuration will cause DCRs to silently fail. Must fix. |
| Warning (orange) | Configuration may cause unexpected behavior. Review recommended. |
| Success (green) | All checks passed. |

## When to Run

- After changing any `LifeSciDataChgDefRecType` validation type (especially Account)
- After adding or modifying managed fields
- After switching between Internal and External validation for an Account record type
- Before go-live or after org refresh
- When DCRs stop generating and you can't figure out why

## See Also

- [LifeSciDataChgDefRecType.md](LifeSciDataChgDefRecType.md) — record type routing and why validation types must align
- [VALIDATION_TYPES.md](VALIDATION_TYPES.md) — detailed validation routing logic and complete setup examples
- [README.md](README.md) — DCR Object Reference and troubleshooting checklist
