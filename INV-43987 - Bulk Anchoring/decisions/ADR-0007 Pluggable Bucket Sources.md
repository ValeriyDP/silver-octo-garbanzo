---
name: ADR-0007 Pluggable Bucket Sources
date: 2026-11-11T15:10:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0007 Pluggable Bucket Sources

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Proposed)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [ADR-0003 Keep Terminal Rows](ADR-0003%20Keep%20Terminal%20Rows.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

## Context

Two kinds of organisation anchor files through hub. An organisation is one or the other, never both:

- **Known organisation**: has a row in `io_hub_organisation_map`. Files arrive as `ClientDLTTransaction` and run the provisioning chain from `RunPortfolioProvisioningCommand`. `ResolveHubOrganisationStep` already reads that map with `IoHubOrganisationMapRepository.findByIoOrganisationId` (source: `apps/hub-service/src/organisation-provisioning/domain/chain/portfolio/resolve-hub-organisation.step.ts`).
- **Regular organisation**: files arrive as `HubDocumentSyncingRequestedEvent`, which `TransactionsSagas.syncDocument` maps straight to `SyncDocumentCommand` (source: `apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts`).

A manual sync from the data room UI is a regular sync, also for a known organisation. Data room emits it as `HubDocumentSyncingRequestedEvent` from `Taxonomy.requestLedgerSync` when the room is hub-connected (source: `apps/data-room-service/src/data-room/taxonomy/domain/entity.ts`). Auto-sync is the only producer of `ClientDLTTransaction`: `FDRAutoSyncInitEvent` → `RequestClientDltTransactionCommand` (source: `apps/data-room-service/src/data-room/taxonomy/application/sagas/taxonomy.saga.ts`).

The known-organisation chain never emits `HubDocumentSyncingRequestedEvent`. Its `addRecord` goes `SyncDocumentStep` → `SyncDocumentCommand` on the command bus (source: `apps/hub-service/src/organisation-provisioning/domain/chain/document/sync-document.step.ts`).

Only the known-organisation intake is built now. Bulk anchoring and autosync for regular organisations are later, and must reuse the bucket without rewriting it.

## Decision

The bucket is a standalone module with a source-agnostic core and one adapter per source.

**Core** (`apps/hub-service/src/anchoring-bucket/`): the `anchoring_bucket` table, the per-key lock, the intake transaction, and the finish transaction ([ADR-0004](ADR-0004%20Atomic%20Finish%20and%20Claim.md)). It stores `source`, `queue_key`, `taxonomy_id`, and the opaque `payload`. It does not know which events or commands a source uses.

**Source adapter** supplies three things:

1. **Intake**: which event enters, whether it is allowed, its `queue_key`, `taxonomy_id`, and `payload`.
2. **Start**: the command to run for a claimed row.
3. **Completion**: which events and caught errors finish the `in_flight` row, and how each is matched.

Sources:

| `source` | Entry event | Allowed when | `queue_key` (signing wallet) | Start | State |
| --- | --- | --- | --- | --- | --- |
| `client_dlt` | `ClientDLTTransaction` | `organisationId` has a row in `io_hub_organisation_map`, and the deal resolves a portfolio | `identity:{portfolioId}` | `RunPortfolioProvisioningCommand` | Wired in this slice |
| `regular` | `HubDocumentSyncingRequestedEvent` | Always | `org:{organisationId}` | `SyncDocumentCommand` | Stub. Not registered. `TransactionsSagas.syncDocument` stays as is |

The key is the THE HUB wallet the source signs with ([ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)).

A source is chosen by the **entry event**, not by looking up the organisation. A manual UI sync on a known organisation is `HubDocumentSyncingRequestedEvent`, so it is `regular`. Nothing on the regular path reads `io_hub_organisation_map`.

`client_dlt` with no map row: log and stop. No row, no chain, THE HUB is not called. Today the same file fails later in `ResolveHubOrganisationStep` with `Hub organisation mapping is missing`.

Wiring the `regular` adapter later means: register the adapter, and route `TransactionsSagas.syncDocument` through bucket intake. The core, the table, and the `client_dlt` adapter stay.

## Alternatives considered

- **One bucket hard-wired to `ClientDLTTransaction`, with an unused `organisation` strategy.** That was [ADR-0002](ADR-0002%20Portfolio%20Identity%20Queue.md). The regular path would still have to change the core: other start command, other completion events.
- **Classify by organisation (look up the map for every event).** A manual UI sync on a known organisation would be pulled into the `client_dlt` chain. The entry event already says which path the file is on.
- **A separate bucket table per source.** Two copies of the same claim and finish logic.

## Consequences

- **Positive**: Regular anchoring plugs in as an adapter. A manual sync is never mistaken for a known-organisation file. The known-organisation check moves to intake, before any THE HUB call.
- **Negative / trade-offs**: An adapter interface to keep stable. The `regular` stub is untested until a slice wires it.
- **Follow-ups / open threads**: Which wallet signs a manual UI sync on a known organisation, and so which queue it would join once `regular` is wired ([Open Questions](../wiki/Open%20Questions.md) #3).

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | Core module, adapter interface, `client_dlt` adapter, `regular` stub |
| `apps/hub-service/src/organisation-provisioning/application/sagas/client-dlt-provisioning.saga.ts` | Hands `ClientDLTTransaction` to bucket intake |
| `apps/hub-service/src/organisation-provisioning/infrastructure/io-hub-organisation-map.repository.ts` | Called by the `client_dlt` intake guard. Unchanged |
| `apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts` | Unchanged in this slice |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [Anchoring Bucket Diagrams](../wiki/Anchoring%20Bucket%20Diagrams.md)
- [File Start Today](../wiki/File%20Start%20Today.md)
- [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md)
- [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
