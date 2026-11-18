---
name: File Start Today
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - wiki
  - architecture
---

# File Start Today

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

**Summary**: Hub starts a known-organisation file as soon as `ClientDLTTransaction` arrives, and a regular file as soon as `HubDocumentSyncingRequestedEvent` arrives. Nothing waits for the previous file to finish. The only overlap guard is an organisation advisory lock around two spots, whose waiters give up after 150 s.

**Sources**: `apps/hub-service/src/organisation-provisioning/application/sagas/client-dlt-provisioning.saga.ts`, `apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts`, `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`, `shared-modules/Events/Hub/Onboarding/client-dlt-transaction.event.ts`, `apps/data-room-service/src/data-room/taxonomy/application/sagas/taxonomy.saga.ts`, `apps/data-room-service/src/data-room/taxonomy/domain/entity.ts`, `apps/data-room-service/src/data-room/taxonomy/domain/services/taxonomy-functional.service.ts`.

**Last updated**: 2026-11-11

---

## Who sends what

| Trigger in data room | Event to hub | Hub path |
| --- | --- | --- |
| Auto-sync (`FDRAutoSyncInitEvent` → `RequestClientDltTransactionCommand`) | `ClientDLTTransaction` | `ClientDltProvisioningSaga` → `RunPortfolioProvisioningCommand` |
| Manual sync from the UI on a hub-connected room (`Taxonomy.requestLedgerSync`) | `HubDocumentSyncingRequestedEvent` | `TransactionsSagas.syncDocument` → `SyncDocumentCommand` |

(source: `taxonomy.saga.ts`, `entity.ts`, `transactions.sagas.ts`)

Data room skips `ClientDLTTransaction` when the room has no `organisationId` or no portfolio. It also skips it when an NVNM taxonomy already exists for the same file and checksum, even if that attempt failed. Otherwise it creates a new taxonomy and sends its id as `taxonomyId` (source: `taxonomy-functional.service.ts`). `uri` is the taxonomy's `documentShortLink` (source: `entity.ts`).

## Known-organisation file

`ClientDltProvisioningSaga` maps the payload straight onto `RunPortfolioProvisioningCommand`. Payload: `dealId`, `taxonomyId`, `organisationId`, `uri`, `checksum`, `checksumAlgo` (source: `client-dlt-transaction.event.ts`).

The chain:

1. Portfolio chain. `ResolveHubOrganisationStep` needs a row in `io_hub_organisation_map`, else throws `Hub organisation mapping is missing`. `EnsureHubIdentityStep` resolves the portfolio Identity `{portfolioId}@measurabl.com` (source: `resolve-hub-organisation.step.ts`, `ensure-hub-identity.step.ts`, `measurabl-identity.ts`).
2. `CompletePortfolioProvisioningStep` awaits `RunRegistryProvisioningCommand`.
3. Registry exists in `deal_anchors.registry`: `CompleteRegistryProvisioningStep` awaits `RunDocumentProvisioningCommand`. No registry: `EnsureRegistryStep` parks the document in `pending_document` and sends `RegisterSymbolCommand`. The run then ends. `HubSymbolRegisteringSucceededEvent` → `StoreDealAnchorRegistryCommand` takes the pending document and runs `RunDocumentProvisioningCommand` later (source: `ensure-registry.step.ts`, `complete-registry-provisioning.step.ts`, `store-deal-anchor-registry.command.ts`).
4. `SyncDocumentStep` sends `addRecord` via `SyncDocumentCommand`. The result is `HubDocumentSyncingSucceededEvent` or `HubDocumentSyncingFailedEvent` (source: `sync-document.step.ts`, `transactions.model.ts`).

A registry failure emits `HubSymbolRegisteringFailedEvent`, which carries no `taxonomyId`. In hub only a log-only handler listens, and the parked document stays parked (source: `transactions.model.ts`, `hub-symbol-registering-failed.event.handler.ts`).

## Regular file

`TransactionsSagas.syncDocument` maps `HubDocumentSyncingRequestedEvent` onto `SyncDocumentCommand`. It also starts on arrival.

## Writes to THE HUB

Ledger writes (`addRegistry`, `addRecord`) go through `HubTokenizationProvider.write`: `POST /ledgers/write` (v1, returns a transaction id) or `POST /ledgers/v3/write` (v3, returns a `jobId`, polled at `GET /ledgers/v3/jobs/:id`), picked by `HUB_WRITE_API_VERSION` (source: `hub-tokenization.provider.ts`, `config/environment.ts`). A new provider is created and logged in per call (source: `tokenization.service.ts`). A 503 becomes `Hub wallet transaction queue is full`, a 422 with no retry; for `addRecord` that ends as `HubDocumentSyncingFailedEvent` (source: `hub-tokenization.provider.ts`, `transactions.model.ts`).

THE HUB queues writes per signing wallet. Regular organisations sign with organisation-level HubKeys. Known organisations sign with an Identity wallet per portfolio, user `{portfolioId}@measurabl.com` (source: `measurabl-tx-payload.ts`). For NVNM, credentials are looked up deal → portfolio → organisation with `dealAnchor.rootPortfolioId()`, which is `resolveProvisioningPortfolioId` (source: `ledger-factory.provider.ts`, `nvnm-scoped-candidates.ts`, `deal-anchor.model.ts`).

Provisioning admin calls (organisation, webhook, scoped keys, identity, wallets, network profile) go through `HubAdminClient` with one admin account for every organisation (`hub.adminEmail`). No retry, no 429 handling (source: `hub-admin.client.ts`, `hub-admin.session.ts`).

## Overlap today

`OrganisationProvisioningLock` takes `pg_try_advisory_lock(scope, hashtext(organisationId))` around the parent wallet nonce (`42559`) and the identity HD counter (`42560`). A waiter retries every 500 ms and throws `Timed out waiting for the organisation provisioning lock` after 150 s (source: `organisation-provisioning.lock.ts`). Several files of one organisation therefore queue on that lock, and the late ones fail. The rest of the chain is not guarded. A hub-wide scope registry that renumbers these to `1001` and `1002` is proposed in [ADR-0010](../decisions/ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md). A hub-wide scope registry that renumbers these to `1001` and `1002` is proposed in [ADR-0010](../decisions/ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md). A hub-wide scope registry that renumbers these to `1001` and `1002` is proposed in [ADR-0010](../decisions/ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md).

## Where this slice stops

The chains, THE HUB write, and the data room publisher stay as they are. The gap is the missing gate in hub in front of the start. See [Anchoring Bucket](Anchoring%20Bucket.md).

## Related pages

- [Anchoring Bucket](Anchoring%20Bucket.md)
- [ADR-0001 Hub Postgres Bucket](../decisions/ADR-0001%20Hub%20Postgres%20Bucket.md)
- [ADR-0007 Pluggable Bucket Sources](../decisions/ADR-0007%20Pluggable%20Bucket%20Sources.md)
- [ADR-0009 One In Flight Per Signing Wallet](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
- [Open Questions](Open%20Questions.md)
- [Wiki Index](index.md)
