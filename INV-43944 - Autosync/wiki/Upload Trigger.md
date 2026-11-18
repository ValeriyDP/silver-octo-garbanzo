---
name: Upload Trigger
date: 2026-11-09T14:35:00.000Z
tags:
  - autosync
  - inv-43944
  - wiki
---

# Upload Trigger

**Summary**: `initiateAutoSync` emits one event. Two sagas listen. Automatic anchoring for a non-map organisation needs its own event, emitted only when the toggle is on.

**Sources**: `apps/data-room-service/src/data-room/file/domain/models/file.model.ts` (`initiateAutoSync`); `apps/data-room-service/src/data-room/taxonomy/application/sagas/taxonomy.saga.ts`.

**Last updated**: 2026-11-09

---

`File.initiateAutoSync` emits `FDRAutoSyncInitEvent`. It runs from `triggerAutoSyncWithMetachain` after version 1, and from `initAutoSyncWithoutVersionCheck`.

Two sagas listen to that event:

- `autoSyncTaxonomyPayloads` sends `RequestDataRoomFileTaxonomyDLTCommand` with `ledgerType: Metachain`, `isHubConnected: false`, `autoSync: true`.
- `requestClientDltTransaction` sends `RequestClientDltTransactionCommand`. It skips when the room has no organisation, or no portfolio and no parent portfolio. Otherwise it creates an NVNM taxonomy, sets `transactionPointer` to `''`, and emits `ClientDLTTransaction`.

`FDRAutoSyncInitEvent` stays the Metachain trigger. `requestClientDltTransaction` stops listening to it.

The same upload trigger emits a second event only when automatic anchoring is on and the organisation is not in `io_hub_organisation_map`. That event runs the general Inveniam-chain sync. An organisation in the map does not get this event. The Measurabl flow remains the only auto-anchor for that organisation.

Where the toggle is stored is still open. See [Open Questions](Open%20Questions.md).

## Related pages

- [Two Auto Anchor Paths](Two%20Auto%20Anchor%20Paths.md)
- [Pending Taxonomy Concurrency Lock](Pending%20Taxonomy%20Concurrency%20Lock.md)
- [Second Write](Second%20Write.md)
- [Wiki Index](index.md)
