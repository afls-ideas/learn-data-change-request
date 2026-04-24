# DeviceSyncTransactionRecord and DCR Blocking

## Summary

The DCR trigger in the `lsc4ce` managed package checks the `DeviceSyncTransactionRecord` table before generating a DCR. If a matching record exists for the Account being modified, the trigger **skips DCR creation entirely** — no error, no warning, just a silent skip.

## How It Works

When the Account trigger fires, the managed package runs this query:

```sql
SELECT LastModifiedDate, ProcessedRecordIdentifier
FROM DeviceSyncTransactionRecord
WHERE ProcessedRecordIdentifier IN ('<AccountId>')
ORDER BY LastModifiedDate DESC
```

If rows are returned, the trigger assumes the change originated from a **mobile device sync** and skips DCR generation. The logic is that the mobile app (CRM for Life Sciences iPad app) handles DCR creation on-device during offline sync — creating a server-side DCR would be a duplicate.

## The Problem

`DeviceSyncTransactionRecord` entries are **persistent**. Once an Account is edited via the mobile app, the record stays in the table indefinitely. This means:

- Any Account ever edited from the mobile app will **never generate a DCR from the desktop UI or Apex** going forward
- The blocking is per-Account — other Accounts without mobile sync records work fine
- There is no error message — the change saves immediately and the field value updates, but no DCR is created

## How to Identify Blocked Accounts

Query the `DeviceSyncTransactionRecord` table:

```sql
SELECT ProcessedRecordIdentifier, COUNT(Id) cnt
FROM DeviceSyncTransactionRecord
GROUP BY ProcessedRecordIdentifier
```

Any Account ID returned will be blocked from DCR generation via non-mobile channels.

## Evidence

Tested in org `260-pm` with three HCP Accounts (same record type, same managed fields, same validation type mappings):

| Account | DeviceSyncTransactionRecord Rows | DCR Generated? |
|---|---|---|
| Rachael Shell (`001Hs00005uBkN0IAK`) | 0 | Yes |
| Abraham Sinha (`001Hs00005uBkMnIAK`) | 4 | No |
| Sheela Reddy (`001Hs00005uBkN3IAK`) | 2 | No |

## SOQL Log Trace

The trigger runs 10-12 SOQLs for blocked accounts vs 22+ for accounts that generate DCRs. The key queries in order:

1. `SELECT PermissionsSkipLifeSciencesTriggerHandlers FROM UserPermissionAccess` — checks if user should skip triggers entirely
2. `SELECT ... FROM ApexClass WHERE Name = 'ClassUtilities'` — loads utility class
3. `SELECT ... FROM LifeSciDataChangeDef WHERE IsActive = true` — gets active DCR definitions
4. `SELECT ... FROM LifeSciDataChgDefRecType` — gets record type mappings
5. `SELECT ... FROM LifeSciDataChgDefMngFld` — gets managed fields
6. `SELECT ... FROM LifeSciDataChgPersonaDef` — gets persona definitions
7. `SELECT ... FROM LifeSciStageObject` — checks stage path objects
8. `SELECT ... FROM User WHERE Id = '<userId>'` — checks user license
9. `SELECT ... FROM DeviceSyncTransactionRecord WHERE ProcessedRecordIdentifier IN (...)` — **this is where blocking happens**
10. Same DeviceSyncTransactionRecord query again (duplicate)

For blocked accounts, the trigger stops here (0 DML). For unblocked accounts, the trigger continues with 10+ more queries and creates the DCR (1 DML).

## Workaround (Tested)

Deleting the `DeviceSyncTransactionRecord` entries for an Account unblocks DCR generation. Tested on Sheela Reddy (`001Hs00005uBkN3IAK`) — after deleting 2 records, modifying LastName immediately generated a DCR.

```apex
List<DeviceSyncTransactionRecord> records = [
    SELECT Id FROM DeviceSyncTransactionRecord
    WHERE ProcessedRecordIdentifier = '<AccountId>'
];
delete records;
```

**Note:** This may affect mobile sync behavior for the Account. The record will be recreated the next time the Account is edited from the mobile app.

## Related

- [VALIDATE_CONFIG.md](VALIDATE_CONFIG.md) — validation type alignment checks
- [LifeSciDataChgDefRecType.md](LifeSciDataChgDefRecType.md) — record type routing and Internal/External validation
