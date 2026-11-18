---
name: Anchoring Bucket
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - wiki
  - architecture
---

# Anchoring Bucket

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

**Summary**: Proposed standalone hub module. A Postgres table holds file starts and runs one file at a time per THE HUB signing wallet, because THE HUB queues writes per wallet and handles them one by one. A source-agnostic core plus one adapter per source: `client_dlt` (known organisations, `ClientDLTTransaction`) is wired, `regular` (`HubDocumentSyncingRequestedEvent`) is a stub. Finished rows stay. No code has been added.

**Sources**: [ADR-0001](../decisions/ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0003](../decisions/ADR-0003%20Keep%20Terminal%20Rows.md), [ADR-0004](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md), [ADR-0005](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md), [ADR-0006](../decisions/ADR-0006%20Read%20Failures%20In%20Postgres.md), [ADR-0007](../decisions/ADR-0007%20Pluggable%20Bucket%20Sources.md), [ADR-0009](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md). Current start path: [File Start Today](File%20Start%20Today.md). Diagrams: [Anchoring Bucket Diagrams](Anchoring%20Bucket%20Diagrams.md), [Anchoring Bucket Board](Anchoring%20Bucket%20Board.excalidraw.md).

**Last updated**: 2026-11-11

---

The module lives in hub (`inv-hub-ms`), proposed at `apps/hub-service/src/anchoring-bucket/`. Data room, THE HUB, the broker, and the provisioning chains are unchanged. The bucket only decides when a file's start command may run, and records how the file ended.

Hub already uses Postgres, TypeORM `SnakeNamingStrategy`, and `migrationsRun: true` (source: `apps/hub-service/src/config/database.ts`). Column names below are what that strategy would store.

## Why

THE HUB is a one-by-one consumer: request/response plus webhook, with a write queue per signing wallet. A 503 on write is surfaced as `Hub wallet transaction queue is full` (source: `hub-tokenization.provider.ts`). Regular organisations sign with organisation-level HubKeys; known organisations sign with an Identity wallet per portfolio. Each file needs preparation and blockchain calls before `addRecord`. Today every `ClientDLTTransaction` starts its chain at once, and the only guard is `OrganisationProvisioningLock` around the wallet nonce and the HD counter, whose waiters throw after 150 s (source: `organisation-provisioning.lock.ts`). See [File Start Today](File%20Start%20Today.md).

## Module shape

| Part | Knows | This slice |
| --- | --- | --- |
| Core | Table, per-key lock, intake transaction, finish transaction | Built |
| `client_dlt` adapter | `ClientDLTTransaction`, `io_hub_organisation_map` check, `RunPortfolioProvisioningCommand`, its finish exits | Wired |
| `regular` adapter | `HubDocumentSyncingRequestedEvent`, `SyncDocumentCommand`, document events | Stub, not registered |

The source is chosen by the **entry event**. An organisation is either known or regular, never both. A manual sync from the data room UI arrives as `HubDocumentSyncingRequestedEvent` (source: `apps/data-room-service/src/data-room/taxonomy/domain/entity.ts`), so it is `regular` even for a known organisation. The `client_dlt` chain sends `addRecord` through `SyncDocumentStep` → `SyncDocumentCommand` and never emits that event (source: `sync-document.step.ts`). Until the `regular` adapter is registered, `TransactionsSagas.syncDocument` runs as today. [ADR-0007](../decisions/ADR-0007%20Pluggable%20Bucket%20Sources.md).

## Row

| Column | Role |
| --- | --- |
| `id` | Row id. FIFO tiebreak |
| `source` | `client_dlt` now. `regular` when that adapter is wired |
| `queue_key` | Signing wallet: `identity:{portfolioId}` or `org:{organisationId}` |
| `taxonomy_id` | From the entry payload. Document events match this |
| `payload` | Entry payload, enough for the adapter to build the start command |
| `status` | `waiting`, `in_flight`, `sync_success`, `sync_failed` |
| `reason` | Set on `sync_failed` |
| `received_at` | Database `now()` at insert. FIFO inside one `queue_key` |

## Queue key

The THE HUB wallet the file is signed with. [ADR-0009](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md).

| Source | Signing wallet | `queue_key` |
| --- | --- | --- |
| `client_dlt` | Portfolio Identity `{portfolioId}@measurabl.com` | `identity:{portfolioId}` |
| `regular` (stub) | Organisation HubKeys | `org:{organisationId}` |

`portfolioId` is `resolveProvisioningPortfolioId` over the `deal_anchors` row for `dealId`. The NVNM credentials lookup uses the same function through `dealAnchor.rootPortfolioId()` (source: `deal-anchor.model.ts`, `ledger-factory.provider.ts`), so the key is the signer.

One `in_flight` row per key. Portfolios and organisations run in parallel. Organisation-wide spots inside the chain (parent wallet nonce, HD counter) stay under `OrganisationProvisioningLock`.

## Who may enter (`client_dlt`)

`ClientDltProvisioningSaga` hands `ClientDLTTransaction` to intake instead of running the command.

Known organisation = a row in `io_hub_organisation_map` for `organisationId` (lookup: `IoHubOrganisationMapRepository.findByIoOrganisationId`, already used by `resolve-hub-organisation.step.ts`). No row: log and stop. Then the deal must resolve a portfolio; no `deal_anchors` row or no portfolio: log and stop. In both cases no bucket row, no chain, THE HUB is not called.

A redelivered event hits the unique `(source, taxonomy_id)` and inserts nothing. Data room never reuses a `client_dlt` `taxonomyId`: it skips the event when a taxonomy for the same file and checksum exists (source: `taxonomy-functional.service.ts`).

## Statuses

| Status | Meaning | Selected as the next file |
| --- | --- | --- |
| `waiting` | Stored, not started | Yes, oldest `received_at`, then `id` |
| `in_flight` | Start command issued, result not stored yet | No. The one running file of that wallet |
| `sync_success` | Document succeeded | No |
| `sync_failed` | Document failed, registry failed, or the chain threw | No |

Status values are snake_case, like the column names. PascalCase is not used in the table.

## Finish exits (`client_dlt`)

| Exit | Status | Match |
| --- | --- | --- |
| `HubDocumentSyncingSucceededEvent` | `sync_success` | `taxonomy_id` |
| `HubDocumentSyncingFailedEvent` (HTTP error, webhook failed or cancelled) | `sync_failed` | `taxonomy_id` |
| Throw in `RunPortfolioProvisioningCommand` (covers the synchronous portfolio → registry → document run) | `sync_failed` | `taxonomy_id` |
| `HubSymbolRegisteringFailedEvent` (no `taxonomyId` on it) | `sync_failed` | `in_flight` row of `identity:{portfolioId of dealId}` with that `dealId`, when `userId = MEASURABL_TRANSACTIONS_USER_ID` |
| Throw in `StoreDealAnchorRegistryCommand` or the `RunDocumentProvisioningCommand` it awaits | `sync_failed` | `taxonomy_id`, else as the registry row |

A 503 queue-full arrives as `HubDocumentSyncingFailedEvent` and becomes `sync_failed`, although it is a busy signal ([Open Questions](Open%20Questions.md) #6).

`HubSymbolRegisteringSucceededEvent` does not finish the row. A webhook dropped by `StoreDealAnchorRegistrySaga` (no `dealId` or `symbol`) finishes nothing. Detail and sources: [ADR-0003](../decisions/ADR-0003%20Keep%20Terminal%20Rows.md).

Rows are not deleted. Not synced = `status <> 'sync_success'`.

## Indexes

| Index | Serves |
| --- | --- |
| unique `(source, taxonomy_id)` | Redelivery is a no-op |
| `(queue_key, received_at, id)` where `status = 'waiting'` | Oldest waiting row for a wallet |
| unique `(queue_key)` where `status = 'in_flight'` | Backstop: one running file per wallet |
| `(taxonomy_id)` where `status = 'in_flight'` | Document-event match |
| `(received_at)` where `status = 'sync_failed'` | Reading failed files |

## Atomic handoff

Intake and finish each run in one transaction under `pg_advisory_xact_lock(AdvisoryLockScope.AnchoringBucketQueue, hashtext(queue_key))`. Scope `2001` comes from one hub-wide registry: `1xxx` organisation provisioning (`ParentWalletNonce = 1001`, `IdentityHdLeaf = 1002`), `2xxx` anchoring bucket ([ADR-0010](../decisions/ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md)). No `SKIP LOCKED`.

- **Intake**: lock, insert `waiting` (`ON CONFLICT DO NOTHING`), claim the oldest `waiting` row if the key has no `in_flight` row, commit, start the claimed row.
- **Finish**: find the `in_flight` row, lock its key, set the terminal status guarded by `status = 'in_flight'`, claim the oldest `waiting` row, commit, start it.

Because both take the same lock, a file inserted while another finishes is never left waiting with nothing in flight. The transaction is not held across THE HUB. [ADR-0004](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md).

## Unmarked in_flight

A row with no finish exit stays `in_flight` and holds that wallet's queue. No timeout and no reaper. [ADR-0005](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md).

## Finding sync_failed

No list event and no screen. Connect to hub Postgres and read `anchoring_bucket`. [ADR-0006](../decisions/ADR-0006%20Read%20Failures%20In%20Postgres.md).

## Related pages

- [Anchoring Bucket Diagrams](Anchoring%20Bucket%20Diagrams.md)
- [Anchoring Bucket Board](Anchoring%20Bucket%20Board.excalidraw.md)
- [File Start Today](File%20Start%20Today.md)
- [Bucket Pattern And Alternatives](Bucket%20Pattern%20And%20Alternatives.md)
- [Open Questions](Open%20Questions.md)
- [ADR-0001 Hub Postgres Bucket](../decisions/ADR-0001%20Hub%20Postgres%20Bucket.md)
- [ADR-0003 Keep Terminal Rows](../decisions/ADR-0003%20Keep%20Terminal%20Rows.md)
- [ADR-0004 Atomic Finish and Claim](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md)
- [ADR-0005 Unmarked In Flight Holds](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
- [ADR-0006 Read Failures In Postgres](../decisions/ADR-0006%20Read%20Failures%20In%20Postgres.md)
- [ADR-0007 Pluggable Bucket Sources](../decisions/ADR-0007%20Pluggable%20Bucket%20Sources.md)
- [ADR-0009 One In Flight Per Signing Wallet](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
- [Wiki Index](index.md)
