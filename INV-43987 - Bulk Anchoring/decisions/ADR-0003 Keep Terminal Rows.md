---
name: ADR-0003 Keep Terminal Rows
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0003 Keep Terminal Rows

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Proposed)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md), [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

## Context

The file is done when hub emits `HubDocumentSyncingSucceededEvent` or `HubDocumentSyncingFailedEvent`. Both payloads extend `DLTResponseInterface`, which has `taxonomyId`, `status`, and `reason` (source: `shared-modules/Events/DataRoom/Interfaces/data-room.interfaces.ts`). `TransactionsModel` emits the failed event both when the `addRecord` call throws and when the webhook or status poll reports failed or cancelled, with `taxonomyId` set (source: `apps/hub-service/src/transactions/domain/models/transactions.model.ts`, `syncDocument` and `documentSyncingEventPublisher`).

The `client_dlt` chain has other exits that never reach a document event:

- **Synchronous run.** `RunPortfolioProvisioningCommand` → `CompletePortfolioProvisioningStep` awaits `RunRegistryProvisioningCommand` → `CompleteRegistryProvisioningStep` awaits `RunDocumentProvisioningCommand` when a registry exists. A throw anywhere in that run reaches `RunPortfolioProvisioningCommandHandler`, which logs and rethrows (source: `run-portfolio-provisioning.command.ts`, `complete-portfolio-provisioning.step.ts`, `complete-registry-provisioning.step.ts`). No event.
- **Registry request failed.** With no registry, `EnsureRegistryStep` parks the document in `deal_anchors.pending_document` and sends `RegisterSymbolCommand` (source: `ensure-registry.step.ts`). `TransactionsModel.registerSymbol` emits `HubSymbolRegisteringFailedEvent` with `dealId` and `organisationId`, and **without** `taxonomyId` (source: `transactions.model.ts`). The webhook failure path emits the same event from `symbolRegisterEventPublisher`. In hub only a log-only handler listens (source: `hub-symbol-registering-failed.event.handler.ts`). The parked document stays parked.
- **After the registry webhook.** `StoreDealAnchorRegistrySaga` → `StoreDealAnchorRegistryCommand`, which verifies the signer, stores the registry, takes the pending document, and awaits `RunDocumentProvisioningCommand`. A throw there is logged and rethrown in that handler (source: `store-deal-anchor-registry.command.ts`). The saga also drops a webhook with no `dealId` or `symbol` (source: `store-deal-anchor-registry.saga.ts`). No event in either case.

Hub has no UI. The table is the place to see which files did not reach a successful sync. The worker still has to pick the next file quickly after many terminal rows exist. SQS delivers at least once, so the same `ClientDLTTransaction` can arrive twice.

Data room creates one taxonomy per file, checksum, and ledger type. `taxonomyId` is that row's id. `resolveClientDltTaxonomy` skips the event when one already exists for the same file and checksum, including after a failed attempt (source: `apps/data-room-service/src/data-room/taxonomy/domain/services/taxonomy-functional.service.ts`). A `client_dlt` `taxonomyId` is therefore never reused; a second arrival is a redelivery.

## Decision

Do not delete the row. Finish the `in_flight` row of the source and set a terminal status. For `client_dlt`:

| Exit | Status | Match | `reason` |
| --- | --- | --- | --- |
| `HubDocumentSyncingSucceededEvent` | `sync_success` | `taxonomy_id` | empty |
| `HubDocumentSyncingFailedEvent` | `sync_failed` | `taxonomy_id` | event `reason` |
| Throw in `RunPortfolioProvisioningCommand` | `sync_failed` | `taxonomy_id` of the command payload | error message |
| `HubSymbolRegisteringFailedEvent` | `sync_failed` | `source = client_dlt`, `queue_key = identity:{portfolioId of dealId}`, `payload.dealId = dealId`, and `userId = MEASURABL_TRANSACTIONS_USER_ID` | event `reason` |
| Throw in `StoreDealAnchorRegistryCommand`, including the awaited `RunDocumentProvisioningCommand` and the signer check before its `try` | `sync_failed` | `taxonomy_id` when the payload has it, else as the registry row above | error message |

Registry failures match by deal because the event has no `taxonomyId`. The deal resolves to one portfolio through `resolveProvisioningPortfolioId`, and that key has one `in_flight` row ([ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)), so the match is unique. `MEASURABL_TRANSACTIONS_USER_ID` is the sentinel user on every `client_dlt` register payload (source: `measurabl-identity.ts`, `measurabl-tx-payload.ts`), so a regular register failure on the same deal does not finish a `client_dlt` row.

A webhook that `StoreDealAnchorRegistrySaga` drops finishes nothing and holds the queue ([ADR-0005](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)).

Selection ignores `sync_success` and `sync_failed`. The next file is the oldest `waiting` row for that `queue_key`, and only when that key has no `in_flight` row.

Indexes:

- unique `(source, taxonomy_id)`. Intake inserts with `ON CONFLICT DO NOTHING`, so a redelivered event is a no-op
- `(queue_key, received_at, id) WHERE status = 'waiting'`
- unique `(queue_key) WHERE status = 'in_flight'`
- `(taxonomy_id) WHERE status = 'in_flight'`
- `(received_at) WHERE status = 'sync_failed'`

Not synced, for a read of this table, means every row whose status is not `sync_success`.

## Alternatives considered

- **Delete the row when the document event arrives.** The queue moves, and the record of a failed or unmoved file is gone. Finding files that did not sync would need another store.
- **A second dead-letter table.** Same facts would live twice. Terminal statuses on the same table, excluded from the worker indexes, keep one row per file start.
- **Scan the whole table and filter statuses in the application.** Terminal rows grow for the life of the table. The claim must use the partial indexes above.
- **Finish only on document events.** Every registry failure and every throw after the webhook would leave the organisation blocked.
- **Add `taxonomyId` to `HubSymbolRegisteringFailedEvent`.** A change in the transactions model for every register caller. The deal match is enough while one file per signing wallet runs.

## Consequences

- **Positive**: `sync_failed` stays queryable with a reason. The claim index stays limited to `waiting` rows. Redelivery cannot anchor a file twice. Every known exit of the `client_dlt` chain finishes the row.
- **Negative / trade-offs**: The table grows. A caught infrastructure error is `sync_failed` and the next file may start. The bucket does not retry. A manual resync from the data room UI is a regular sync (`HubDocumentSyncingRequestedEvent`), not a new `client_dlt` row ([ADR-0007](ADR-0007%20Pluggable%20Bucket%20Sources.md)). A parked `pending_document` left by a registry failure is not cleared by the bucket.
- **Follow-ups / open threads**: Whether the webhook path of `HubSymbolRegisteringFailedEvent` carries `organisationId` and `userId` ([Open Questions](../wiki/Open%20Questions.md) #5). A 503 `Hub wallet transaction queue is full` reaches the bucket as `HubDocumentSyncingFailedEvent` and becomes `sync_failed`, although it is a busy signal (#6). An unmarked `in_flight` row holds the queue ([ADR-0005](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)). `sync_failed` is read in Postgres ([ADR-0006](ADR-0006%20Read%20Failures%20In%20Postgres.md)).

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | Status values, indexes, `client_dlt` completion adapter |
| `apps/hub-service/src/organisation-provisioning/application/sagas/log-document-sync-finished.saga.ts` | Still logs success. Bucket completion is a separate listener on the same events |
| `apps/hub-service/src/organisation-provisioning/domain/commands/run-portfolio-provisioning.command.ts` | A throw finishes the `in_flight` row. The chain steps stay |
| `apps/hub-service/src/organisation-provisioning/domain/commands/store-deal-anchor-registry.command.ts` | A throw, including from the signer check, finishes the `in_flight` row |
| `apps/hub-service/src/transactions/domain/events/handlers/hub-symbol-registering-failed.event.handler.ts` | Unchanged. The bucket adds its own listener |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [Anchoring Bucket Diagrams](../wiki/Anchoring%20Bucket%20Diagrams.md)
- [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md)
- [ADR-0005 Unmarked In Flight Holds](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
- [ADR-0006 Read Failures In Postgres](ADR-0006%20Read%20Failures%20In%20Postgres.md)
- [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md)
