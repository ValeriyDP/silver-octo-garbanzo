---
name: ADR-0001 Hub Postgres Bucket
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0001 Hub Postgres Bucket

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Proposed)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md), [File Start Today](../wiki/File%20Start%20Today.md)

## Context

THE HUB is a one-by-one consumer: request/response plus a webhook. It queues ledger writes per signing wallet. Hub writes through `POST /ledgers/write` (v1) or `POST /ledgers/v3/write` (v3 job, polled at `GET /ledgers/v3/jobs/:id`), and a 503 is surfaced as `Hub wallet transaction queue is full` (source: `apps/hub-service/src/tokenization/hub-tokenization.provider.ts`). Regular organisations sign with organisation-level HubKeys. Known organisations sign with an Identity wallet per portfolio. Before the actual `addRecord`, hub runs preparation and blockchain calls for the file (organisation, identity, wallet funding, registry). Those must not overlap with another file on the same wallet. Data room can now send many files in a short time, for example a multi-file upload.

`ClientDltProvisioningSaga` starts `RunPortfolioProvisioningCommand` on every `ClientDLTTransaction` (source: `apps/hub-service/src/organisation-provisioning/application/sagas/client-dlt-provisioning.saga.ts`). The document result comes later, on `HubDocumentSyncingSucceededEvent` or `HubDocumentSyncingFailedEvent`.

The only overlap guard today is `OrganisationProvisioningLock`: a session-scoped advisory lock per organisation around the parent wallet nonce and the identity HD counter. Its waiters throw after 150 s (source: `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`). It covers two spots, not the whole file.

Production delivery is SNS/SQS. The handler returns quickly. The business process then waits on THE HUB. Holding the broker message open does not cover that wait. Local RabbitMQ is not the design target.

Hub already stores its own read models in Postgres. Migrations run on process start (`migrationsRun: true` in `apps/hub-service/src/config/database.ts`). Several hub pods can run at once.

Data room and THE HUB are out of this change. The chains that call THE HUB stay as they are.

## Decision

Add a standalone hub module whose job is a Postgres bucket of file starts (fan-in). Proposed table `anchoring_bucket`. Proposed location `apps/hub-service/src/anchoring-bucket/`, registered from `apps/hub-service/src/app.module.ts` beside `OrganisationProvisioningModule`.

The module is a source-agnostic core plus one adapter per source ([ADR-0007](ADR-0007%20Pluggable%20Bucket%20Sources.md)). This slice wires the `client_dlt` source: `ClientDltProvisioningSaga` hands `ClientDLTTransaction` to bucket intake, and only a claimed row runs `RunPortfolioProvisioningCommand`. The `regular` source (`HubDocumentSyncingRequestedEvent` → `SyncDocumentCommand`) is a stub that a later slice registers.

Queue key, retention, and the atomic claim are [ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [ADR-0003](ADR-0003%20Keep%20Terminal%20Rows.md), and [ADR-0004](ADR-0004%20Atomic%20Finish%20and%20Claim.md).

## Alternatives considered

- **In-memory queue in one hub process.** A second pod, or a restart after SQS has already delivered the message, loses the waiting files or starts two of them.
- **Leave the events on SQS until THE HUB finishes.** The handler is fast on purpose. The business process outlives that handler. Visibility timeout and redelivery are the wrong gate.
- **SQS FIFO queue with `MessageGroupId = queue_key`.** Orders delivery, but releases the group when the handler acks. Gating on the webhook would mean holding the message open, the same problem as above.
- **Widen `OrganisationProvisioningLock` to the whole chain.** The chain parks on the registry webhook and resumes in another handler, so a lock cannot span it. Waiters would still time out at 150 s.
- **Queue inside data room.** This slice does not change data room. The regular-anchoring start already lives in hub.

## Consequences

- **Positive**: Every hub pod sees the same waiting files. A restart does not drop a stored row. A burst of files no longer piles chains onto the 150 s organisation lock.
- **Negative / trade-offs**: A new table and a new module. The saga no longer starts the chain itself.
- **Follow-ups / open threads**: An unmarked `in_flight` row is [ADR-0005](ADR-0005%20Unmarked%20In%20Flight%20Holds.md).

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | New module: core, adapters, entity, migration |
| `apps/hub-service/src/app.module.ts` | Import the module |
| `apps/hub-service/src/organisation-provisioning/application/sagas/client-dlt-provisioning.saga.ts` | Hand the payload to the bucket instead of constructing `RunPortfolioProvisioningCommand` directly |
| `apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts` | Unchanged in this slice. A later slice routes `syncDocument` through the `regular` adapter |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [Anchoring Bucket Diagrams](../wiki/Anchoring%20Bucket%20Diagrams.md)
- [File Start Today](../wiki/File%20Start%20Today.md)
- [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md)
- [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
