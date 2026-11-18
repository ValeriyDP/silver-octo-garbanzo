---
name: How File Shows As Synced
date: 2026-10-02T12:26:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
  - how-to
---

# How File Shows As Synced

**Summary**: A file is shown as synced to Metachain when its **taxonomy** row for `ledgerType = Metachain` has `status = Succeed` and the taxonomy checksum still matches the file. That is the document-sync path, not the per-event Immudb hash path.

**Sources**: `taxonomy.entity.ts` (`isFileSynced`, `requestLedgerSync`), `taxonomy-functional.service.ts` (`getFileDLTStatuses`), `taxonomy.saga.ts`, `file.saga.ts`, `metachain-sync-document-transactions.model.ts`, `event-presentation-templates.ts`

**Last updated**: 2026-10-02

---

## What “synced” is (and is not)

| Surface | What you see | Driven by |
| ------- | ------------ | --------- |
| Data room file / ledger chip | `ledgersStatuses[].name === 'Metachain'`, `status === 'Synced'` | Taxonomy read model (`getFileDLTStatuses`) |
| Deal logs | `{user} synced {file} to {ledger}` | `FDRFileSyncActivitySucceededEvent` + presentation template |
| Tokenization toast / progress | Metachain (`metachainv2`) sync finished | Frontend listens to `MetaChainDocumentSyncingSucceededEvent` |

Lane A (hash every `BaseEvent` into Immudb) does **not** flip this badge. A file downloaded or moved will get an event hash; it will not show as synced to Metachain until a **taxonomy** write succeeds. (source: taxonomy-functional.service.ts, How File Shows As Synced vs [Metachain Write Path](Metachain%20Write%20Path.md))

## When the write starts

Two entry points, same pipeline after that.

1. **Manual.** UI/API asks data-room to sync the file with `ledgerType: Metachain` and `isHubConnected: false`. Controller → `RequestDataRoomFileTaxonomyDLTCommand`.
2. **Auto.** After a file is linked, `File.triggerAutoSyncWithMetachain()` fires `FDRAutoSyncInitEvent` (skipped for version 1 to avoid a race with `FDRFileResourceAddedEvent`). Taxonomy saga maps that to the same DLT command with `ledgerType: Metachain`, `isHubConnected: false`, `autoSync: true`. There is also `initAutoSyncWithoutVersionCheck()`. (source: file.model.ts, taxonomy.saga.ts)

`QLDB` is in `ExcludedLedgerTypes`, so the old QLDB chip is hidden. The visible “Metachain” ledger is `LedgerTypes.Metachain`. Frontend label for `ProviderTypeEnum.metachainv2` is `'Metachain'`. (source: data-room.enums.ts, tokenization-common.constants.ts)

## Write pipeline (document, not event hash)

```text
RequestDataRoomFileTaxonomyDLT
  → create/reuse taxonomy (checksum = current file checksum)
  → if sync needed: file.requestChecksumVerification
  → VerifyFileChecksumCommand
      ESP checksum still matches?
        yes → taxonomy.requestLedgerSync(..., isHubConnected=false)
              ledgerType Metachain → MetaChainDocumentSyncingRequestedEvent
        no  → failureLedgerSync
  → metachain-service MetachainSyncDocumentCommand
      write(documentTaxonomy) to Immudb (or QLDB if SYNC_DOCUMENT_DEFAULT_LEDGER_TYPE=QLDB)
  → MetaChainDocumentSyncingSucceededEvent
```

`isHubConnected: true` would go to Hub (`HubDocumentSyncingRequestedEvent`) — that is NVNM/ETH/etc., not this badge. (source: taxonomy/domain/entity.ts, verify-file-checksum.command.ts, metachain-sync-document-transactions.model.ts)

## How the badge becomes Synced

On success, two consumers run in data-room:

1. **Taxonomy saga** → `UpdateDataRoomFileTaxonomyCommand` → `completeLedgerSync` → taxonomy `status` + `transactionPointer` stored.
2. **File saga** → `FDRFileSyncActivitySucceededCommand` → `FDRFileSyncActivitySucceededEvent` (`isSynced`, `blockchainName: taxonomy.ledgerType`). That updates the file activity / VM and is what deal logs render as “synced”.

When the UI later asks for DLT status, `getFileDLTStatuses` recomputes per ledger:

```text
Synced     = taxonomy exists
             AND status is Succeed (not Failed / empty-pointer Pending)
             AND taxonomy.documentChecksum === current file checksum
             AND verificationStatus is null or Verified

Pending    = status Pending and a transactionPointer exists
Outdated   = Succeed (or in-flight with pointer) but checksum no longer matches the file
NotSynced  = no taxonomy, or Failed, or Pending with no pointer
```

Overall file DLT status is Synced if any ledger is Synced; Outdated wins if any ledger is Outdated. (source: taxonomy-functional.service.ts `getFileDLTStatuses`, `isFileSynced`)

If the file is replaced and the checksum changes, the Metachain chip flips to **Outdated** even though Immudb still has the old taxonomy. A new sync creates a new taxonomy write.

## Deal log wording

Template for `FDRFileSyncActivitySucceededEvent`: User + “synced” + File + “to” + Ledger (`blockchainName`). Failure uses the same “synced” word plus a failure chip. (source: event-presentation-templates.ts)

## Related pages

- [Event Hash vs File Taxonomy](Event%20Hash%20vs%20File%20Taxonomy.md)
- [Metachain Write Path](Metachain%20Write%20Path.md) — event-hash lane (does not set this badge)
- [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md) — taxonomy payload written on success
- [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md)
- [Wiki Index](INV-42833%20-%20Metachain/wiki/index.md)
