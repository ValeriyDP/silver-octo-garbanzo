---
name: Second Write
date: 2026-11-09T14:35:00.000Z
tags:
  - autosync
  - inv-43944
  - wiki
---

# Second Write

**Summary**: `hubJobId` arrives after THE HUB accepts the write. A second request is a second chain write. The later success event does not replace the first chain write.

**Sources**: `apps/hub-service/src/tokenization/hub-tokenization.provider.ts`; `apps/hub-service/src/transactions/application/providers/ledger-io.provider.ts`; `apps/hub-service/src/transactions/domain/models/transactions.model.ts` (`documentSyncingEventPublisher`); `apps/hub-service/src/transactions/application/services/codec/nvnm/nvnm-payload-codec.service.ts` (`encodeSetDocument`); `apps/data-room-service/.../update-data-room-file-taxonomy.command.ts`.

**Last updated**: 2026-11-09

---

IO Hub Service and THE HUB are different systems. IO Hub Service (`apps/hub-service`) receives the sync event, encodes it, and posts `write()`. THE HUB is the third-party signer. It assigns `jobId` in the response to that post.

IO Hub Service stores `transactions.hub_job_id` and emits `hubJobId` on `HubDocumentSyncingPendingEvent`, `HubDocumentSyncingSucceededEvent`, and `HubDocumentSyncingFailedEvent`. While the job is queued, `transactionPointer` is empty. Data-room's `UpdateDataRoomFileTaxonomyCommand` keeps `taxonomyId`, `transactionPointer`, `status`, and `reason`. It drops `hubJobId`. The taxonomy row has no column for it.

`hubJobId` is not known when data-room emits the request. It cannot guard the manual click.

IO Hub Service collapses a write only when THE HUB returns the same `hubJobId`. The unique index on `transactions.hub_job_id` turns that into a replay. `encodeSetDocument` puts `taxonomyId` and a new timestamp on `addRecord`, so a second request is a new payload. THE HUB issues a new job. The v3 `idempotentReplay` flag is not used to skip that payload.

Both jobs run. The later success event replaces `transactionPointer` on the taxonomy row only when both events use the same `taxonomyId`. The first chain write stays.

The taxonomy row created before the emit is the marker that exists in time. With the `Pending` lock in place, the manual click never reaches `write()`. Relaxing that lock allows the second `write()`.

The taxonomy for an automatic write is created by data-room. The shape of that row is still open. It must not block a manual Anchor. See [Open Questions](Open%20Questions.md).

## Related pages

- [Pending Taxonomy Concurrency Lock](Pending%20Taxonomy%20Concurrency%20Lock.md)
- [Two Auto Anchor Paths](Two%20Auto%20Anchor%20Paths.md)
- [Wiki Index](index.md)
