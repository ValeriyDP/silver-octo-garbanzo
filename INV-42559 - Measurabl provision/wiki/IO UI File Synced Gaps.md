---
name: IO UI File Synced Gaps
date: 2026-09-15T16:22:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# IO UI File Synced Gaps

**Summary**: What `HubSymbolRegisteringSucceededEvent` and `HubDocumentSyncingSucceededEvent` must carry, and what must already exist in IO, for the data-room UI to show a file as Synced on NVNM.

**Sources**: `Taxonomy.isFileSynced` / `completeLedgerSync`; `TaxonomyFunctionalService.updateStatusOnResponseFromLedger` / `getFileDLTStatuses`; `SymbolRegistrationSucceededCommand`; frontend `DataRoomFileTaxonomyUpdatedEvent` effects; `nvnm-ledger.provider` Register `onComplete`; [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md).

**Last updated**: 2026-09-15

---

The file badge is **not** painted from the Hub success events directly. Hub emits → data-room writes the taxonomy → data-room emits `DataRoomFileTaxonomyUpdatedEvent` → UI refetches sync info.

`HubSymbolRegisteringSucceededEvent` does not touch the file badge. It updates deal integration settings.

## What “Synced” means in IO

`getFileDLTStatuses` looks up the file’s taxonomy for `LedgerTypes.NVNM`. Status is `Synced` only when `Taxonomy.isFileSynced(file.checksum)` is true:

- `taxonomy.documentChecksum === file.checksum`
- `verificationStatus` is `null` or `Verified`
- `taxonomy.status === DLTOperationStatuses.Succeed`

Empty `transactionPointer` with `Pending` is treated as `NotSynced`. Failed is `NotSynced`. Checksum mismatch is `Outdated`.

## `HubDocumentSyncingSucceededEvent` — file path

IO saga: event → `UpdateDataRoomFileTaxonomyCommand` → `updateStatusOnResponseFromLedger(taxonomyId, transactionPointer, status, reason)`.

**Used:** `taxonomyId`, `transactionPointer`, `status`, `reason`. The rest (`ledgerType`, `transactionType`, `dealId`, `userId`, `organisationId`) is ignored by that command.

**Must already exist (not on the Hub event):**

| Prerequisite | If missing |
| --- | --- |
| Taxonomy row with that `taxonomyId` | Handler logs and returns. No UI change. |
| File row (`taxonomy.fileId`) | Same no-op. |
| `taxonomy.ledgerType = NVNM` | NVNM column stays `NotSynced`. UI matches by ledger. |
| `taxonomy.documentChecksum` = current file checksum | Badge is `Outdated`, not `Synced`. |
| `verificationStatus` null or Verified | `isFileSynced` is false. |

**Must be on the emit:**

| Field | Gap if wrong |
| --- | --- |
| `taxonomyId` | Must be a real data-room PK. |
| `status` | Must be `Succeed`. Anything else is not Synced. |
| `transactionPointer` | Non-empty chain / Hub tx id. Needed for explorer and to leave Pending. |
| `reason` | Empty on success. Shown on failure toast. |

**UI live update** after the taxonomy write: `DataRoomFileTaxonomyUpdatedEvent` with `fileId`, `roomId`, `ledgerType`, `status ≠ Pending`. Frontend refetches taxonomy + `getFileSyncInfo`. Toast if Succeed and ledger is not Metachain.

The websocket `HubDocumentSyncingSucceededEvent` only clears an in-session spinner if that `taxonomyId` is already in the client progress store. Background Measurabl sync: spinner path may miss; the badge still updates from `DataRoomFileTaxonomyUpdatedEvent` or the next load.

## `HubSymbolRegisteringSucceededEvent` — deal path, not the file

deals-service: persist symbol, `registerSymbolStatus = Active`, NVNM `hubConnectionStatus = Active`, notify frontend settings.

**Must be on the emit (NVNM):**

| Field | Gap if wrong |
| --- | --- |
| `symbol` | NVNM throws if missing. Must be the registry id (NVNM `onComplete` decodes it from the receipt). |
| `ledgerType` | `NVNM` so it maps to the NVNM setting. |
| `dealId`, `organisationId` | Load settings. |
| `userId` | Written onto the setting update. |
| `transactionId` | Logged / required on the type. |

**Must already exist:** an NVNM integration setting on the deal (or the auto-create path). If none, command returns null; UI never gets “connected.”

This event is optional for the file Synced badge. It is required if the deal UI must show NVNM as connected / store the symbol.

## Gaps on the Measurabl one-shot

Relative to [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md):

1. **Taxonomy row before sync.** **Unsolved — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #14.** Inbound `taxonomyId` is useless until data-room has the NVNM row. Upload does not create it. View-file URL is `fileId` + `dealId` only. See [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md).
2. **Copy `taxonomyId` onto `transactions`** so async `onComplete` can emit `HubDocumentSyncingSucceededEvent` with it.
3. **Non-empty `transactionPointer`** on that emit (`transactions.transactionId`).
4. **`status = Succeed`** on the emit (from the row).
5. **Checksum already aligned** on create (event `checksum` = file checksum = `taxonomy.documentChecksum`).
6. **Register emit is a separate write.** If we want deal settings/UI connected, emit `HubSymbolRegisteringSucceededEvent` after `addRegistry` with `symbol` = registry id. Not required for the file badge.
7. **`userId` will not be on these events.** File path ignores it (`UpdateDataRoomFileTaxonomyCommand`; `DataRoomFileTaxonomyUpdatedEvent.userId` is `taxonomy.createdBy`). Register path already falls back to `userId ?? ''` when writing settings.

## Related pages

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Event Payloads](Event%20Payloads.md)
- [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md)
- [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md)
- [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #14
- [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md)
