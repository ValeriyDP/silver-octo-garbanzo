---
name: Event Hash vs File Taxonomy
date: 2026-10-02T12:34:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
---

# Event Hash vs File Taxonomy

**Summary**: Same service, two products. Event hashing is an automatic audit of platform `BaseEvent`s. File taxonomy sync is an on-demand (or auto-after-link) write of one file fingerprint. Only the second one makes a file look “Synced”.

**Sources**: [Metachain Write Path](Metachain%20Write%20Path.md), [How File Shows As Synced](How%20File%20Shows%20As%20Synced.md), [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md)

**Last updated**: 2026-10-02

---

| | Event hash (Lane A) | File taxonomy sync |
| - | ------------------- | ------------------ |
| Trigger | Almost every domain event on the broker | User DLT sync, or auto-sync after file link |
| Input | Full `BaseEvent` | `TaxonomyInterface` (uri, checksum, dealName, …) |
| Stored in Immudb | `{ eventId, hash }` | Full `documentTaxonomy` JSON |
| Postgres | `transactions` | `metachain_sync_document_transactions` + data-room taxonomy |
| File “Synced” chip | No | Yes, when taxonomy `status = Succeed` and checksum still matches |
| Deal log “synced file to Metachain” | No | Yes (`FDRFileSyncActivitySucceededEvent`) |
| Code entry | `InveniamEventSaga` → `ProcessInveniamEventCommand` | `MetaChainDocumentSyncingRequestedEvent` → `MetachainSyncDocumentCommand` |

Both run inside `metachain-service` and can land in the same Immudb. They are not the same row, key, or UI state.

INV-42833 (“put Metachain events onto NVNM”) is about the **event-hash** lane unless we explicitly say otherwise. The file-taxonomy lane already has an NVNM cousin via Hub (`addRecord`).

## Related pages

- [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md)
- [Metachain Write Path](Metachain%20Write%20Path.md)
- [How File Shows As Synced](How%20File%20Shows%20As%20Synced.md)
- [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md)
- [Wiki Index](INV-42833%20-%20Metachain/wiki/index.md)
