---
name: ADR-0011 FIFO Per-Wallet Chain Without Hold
date: 2026-11-16T14:35:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - adr
  - architecture
  - sqs
---

# ADR-0011 FIFO Per-Wallet Chain Without Hold

> [!info] Active SQS FIFO direction
> This ADR belongs to the active SQS direction ([SQS FIFO Approach](../wiki/SQS%20FIFO%20Approach.md), [Holding The Start Message](../wiki/Holding%20The%20Start%20Message.md)), not the on-hold Postgres bucket line (ADR-0001…ADR-0010).

- **Status**: Accepted
- **Date**: 2026-11-16
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [Holding The Start Message](../wiki/Holding%20The%20Start%20Message.md), [SQS FIFO Approach](../wiki/SQS%20FIFO%20Approach.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [ADR-0010 Hub Advisory Lock Scope Registry](ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md), [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0012 Durable Workflows Engine](ADR-0012%20Durable%20Workflows%20Engine.md), [ADR-0013 Hybrid Workflows Over Hub Queue](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md)

> [!note] Interim serialiser
> Under the hybrid direction ([ADR-0013](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md)), this FIFO design is the per-wallet serialiser that ships on NestJS 8. Durable workflows ([ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md)) may later serialise via `concurrency.key` as an **addition** — the FIFO group can be retired or kept for ordering/backpressure, that is a cutover choice, not a mandated removal. THE HUB `wallet_tx_jobs` queue stays the nonce-safe writer either way.

## Context

Hub republishes file starts onto the hub SQS FIFO queue ([SQS FIFO Approach](../wiki/SQS%20FIFO%20Approach.md)). The question this ADR settles: serialise a signing wallet by **holding** a message until the file finishes, or by **re-grouping** the whole per-file chain under the wallet and letting it flow without a hold.

What the broker does today (source: `shared-modules/NestAwsCqrs/src/broker/aws/SnsProducer.ts`):

```
MessageGroupId = eventBody.context?.messageGroupId || eventBody.meta.aggregateId
```

`ClientDLTTransaction` sets no `messageGroupId` and its `aggregateId = taxonomyId`, and data room makes a new taxonomy per file. So ten files of one portfolio are ten `taxonomyId`s, ten FIFO groups, and nothing serialises them. A multi-file upload runs up to ten chains at once per portfolio, bounded only by consumer capacity, not by the wallet.

The per-file chain is not one synchronous handler (source: `File Start Today`, `transactions.model.ts`):

1. `ClientDLTTransaction` → `ClientDltProvisioningSaga` → `RunPortfolioProvisioningCommand`, run inside the handler. Prep and `RegisterSymbol`, then the run **ends** (parks the document) before the write.
2. Register webhook → `HubSymbolRegisteringSucceededEvent` (its group is `aggregateId = hub tx id`) → `StoreDealAnchorRegistrySaga` → `RunDocumentProvisioningCommand` → `SyncDocument`.
3. Document webhook → `HubDocumentSyncingSucceededEvent`/`FailedEvent` (terminal). Hub's terminal handler only logs.

Routing of the entry events (source: `shared-modules/Events/EventsConstants.ts`, `EventToMSMap`): `ClientDLTTransaction` is **hub-only**; `HubDocumentSyncingRequestedEvent` goes to **hub and metachain**; `HubSymbolRegisteringSucceededEvent` goes to **deals** and others. So two of the three entry points are consumed outside hub and cannot be re-grouped on the shared topic without reordering those consumers. The `io_hub_organisation_map` guard lives only in the `client_dlt` chain (`ResolveHubOrganisationStep`); the `regular` path signs with org HubKeys and needs no mapping row.

The org-scoped shared state is already guarded (source: `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`): `OrganisationProvisioningLock` serialises a read-modify-write against the parent wallet nonce (`42559`, `1001` in [ADR-0010](ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md)) and the identity HD counter (`42560`, `1002`), keyed by `organisationId`. The parent wallet is shared across all portfolios of one organisation.

## Finding: THE HUB already serialises writes per signing wallet

Verified in the hub backend (`hub/apps/backend`, provider NVNM write path, 2026-11-16). Nonce-safety does **not** depend on the IO Hub event layer — THE HUB owns it in a durable DB-backed per-wallet queue (`wallet_tx_jobs`, module `wallet-transaction-queue`). A write is not a direct `provider.write()`; it is enqueued and then claimed one-at-a-time per wallet:

- **Enqueue depth guard under advisory lock** (source: `wallet-tx-job.repository.ts`, `createQueuedJobIfUnderDepth`): `SELECT pg_advisory_xact_lock(hashtext(walletId))` then a per-wallet active-job count against `maxDepth`; over depth → `BLOCKCHAIN_WALLET_TX_QUEUE_FULL` (the 503). The overflow is **per signing wallet**, not global. Only non-terminal jobs count toward depth (`WALLET_TX_DEPTH_STATUSES` = `Queued, Processing, Signing, SignedPendingSubmit`); `Completed`/`Failed` drop out, so the queue drains as jobs finish. `maxDepth` default is **50000** per wallet (config `walletTxQueue.maxDepth`, `wallet-transaction-queue.config.ts`). The same gate guards the failed-job requeue path (`countActiveForWallet`). This is a safety ceiling for an abnormal single-wallet pile-up, not routine per-file backpressure: a normal bulk upload never approaches 50000 unfinished writes on one wallet. Distinct from `maxInFlight` (default 16, hub-wide worker concurrency) and `ledgerRpcMaxInFlight` (NVNM 4), which bound throughput, not the 503.
- **Single in-flight per wallet** (source: `wallet-tx-job.repository.ts`, `claimNextRunnableJob`): claims a `Queued`/`SignedPendingSubmit` job only when `NOT EXISTS` another job for the same `wallet_id` in a blocking status, `LIMIT 1 FOR UPDATE SKIP LOCKED`. Blocking statuses = `Processing, Signing, SignedPendingSubmit` (`wallet-tx-active-statuses.util.ts`). So one wallet = at most one active transaction, even across concurrent worker lanes.
- **Nonce ordering, two models**: the **sequential** path (`DefaultWalletTxLedgerWriteHandler` → `LedgerWriteExecutionService.executeWrite` → `provider.write()`) takes a per-wallet `TransactionLockService` mutex and reads `getTransactionCount(address, 'latest')` (confirmed nonce), marking the job `Completed` on broadcast (`onBroadcast`), i.e. before the block — so back-to-back writes can hit a transient `nonce too low` that self-heals via `handleProcessError`→`requeueForRetry`. The **batch** path assigns explicit sequential nonces (`signWriteAtNonce`/`assignedNonce`) and waits `waitUntilPendingNonceAtLeast`/receipt, correct by construction and tolerant of unconfirmed in-flight.

Consequence for this ADR: the IO Hub-side FIFO re-grouping provides **backpressure, ordering, and avoidance of `BLOCKCHAIN_WALLET_TX_QUEUE_FULL`** — **not** nonce-safety, which already lives in THE HUB's wallet-tx queue. This also settles the `regular` "fly-through" concern: a `regular` internal event has no per-wallet delaying action (no top-up) and acks fast, but that is fine — its write still serialises per wallet inside THE HUB exactly like any other. The `client_dlt` vs `regular` asymmetry (top-up only on `client_dlt`) is irrelevant to nonce-safety because neither relies on the event layer for it.

## Decision

Serialise per signing wallet with SQS FIFO by re-grouping the whole per-file chain, with **no hold**.

- **Public events stay untouched** for their external consumers. Hub re-publishes **new internal events**, suffixed `Internal`, with the same payload and `MessageGroupId` = the signing wallet (`anchoring:identity:{portfolioId}` for `client_dlt`, `anchoring:org:{organisationId}` for `regular`). The chain sagas are retargeted to the `Internal` events. A distinct event name removes the double-run without any "suppress the copy" logic — the earlier suppression blocker dissolves.
- Per source, a thin translator consumes the public entry event and publishes its `Internal` counterpart (per-source adapters, [ADR-0007](ADR-0007%20Pluggable%20Bucket%20Sources.md)):
  - `client_dlt`: `ClientDLTTransaction` (hub-only) → `ClientDLTTransactionInternal`. Translator resolves `portfolioId = resolveProvisioningPortfolioId(dealId)` from `deal_anchors` and applies the `io_hub_organisation_map` intake guard ([ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)). `ClientDltProvisioningSaga` listens to `ClientDLTTransactionInternal`.
  - `regular`: `HubDocumentSyncingRequestedEvent` (hub **and** metachain) → `HubDocumentSyncingRequestedInternal`, group `anchoring:org:{organisationId}` straight from the payload. **No** `io_hub_organisation_map` / `deal_anchors` lookup — regular organisations sign with org HubKeys and need no mapping row. The public event still reaches metachain.
  - continuation: `HubSymbolRegisteringSucceededEvent` (fanned to `deals` and others) → a hub-internal continuation event grouped by wallet that drives `RunDocumentProvisioning`. The public event still reaches deals.
- **Only broker hops need an `Internal` twin; in-process steps need nothing.** Verified in the sagas (`apps/hub-service/.../sagas/`): each chain step is `broker event → @Saga → in-process CQRS command`. The commands (`RunPortfolioProvisioningCommand`, `StoreDealAnchorRegistryCommand`, `RunDocumentProvisioningCommand`, `RegisterSymbolCommand`, `SyncDocumentCommand`, `UpdateTxStatusCommand`) ride the in-process command bus on one pod — they carry **no** `MessageGroupId`, are already private to hub-service, and need **no** rename and **no** `Internal` variant. Only the events a saga subscribes to cross pods and need the wallet group. The chain parks at the registry and resumes on THE HUB's webhook as a **new** broker message (possibly another pod), so the group must be re-established at **each** broker hop, not just the entry. For `client_dlt` those hops are: `ClientDLTTransaction` (entry; `['hub']` but externally published), `HubSymbolRegisteringSucceededEvent` (register-continuation; `['deals','hub',…]`), `HubDocumentSyncingRequestedEvent` (document; `['hub','metachain']`). All three are public/fanned, so each gets its own `Internal` twin — it is **not** only `ClientDLTTransaction`. (Routing source: `shared-modules/Events/EventsConstants.ts`, `EventToMSMap`.)
- Only the `client_dlt` start is hub-only and could in theory be re-grouped in place; the `regular` start and the register continuation are fanned out, so the internal-event split is **mandatory** there, not a style choice.
- No message is held: handlers ack normally. FIFO then runs **one handler at a time per wallet**. Files of one wallet never run their synchronous steps concurrently; different wallets run in parallel.
- `OrganisationProvisioningLock` stays (`1001` parent nonce, `1002` HD leaf). It is org-scoped, so it still guards the cross-wallet parent-wallet RMW that the per-wallet FIFO group cannot. [ADR-0010](ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md) scope `2001` (bucket queue lock) is **not needed**: the FIFO group does that wallet-scoped serialisation.
- Backpressure to THE HUB is THE HUB's own per-wallet write queue (`wallet_tx_jobs`, see Finding) plus a 503 (`Hub wallet transaction queue is full`) → requeue to the tail ([Open Questions](../wiki/Open%20Questions.md) #6). The 503 is a per-wallet safety ceiling (`maxDepth` 50000 non-terminal jobs per wallet), not a routine per-file signal — in normal bulk uploads it is never hit. The funding wait already built into the chain (`pollUntilFunded`, 90 s) spaces writes per wallet. Nonce-safety is THE HUB's responsibility, not this layer's; the IO Hub FIFO group is for ordering and backpressure only.

No Postgres waiting room and no claim/finish (unlike [ADR-0001](ADR-0001%20Hub%20Postgres%20Bucket.md)). Waiting files sit in the FIFO queue and advance on **ack**, not on the terminal event. The gap between a handler's ack and the terminal is accepted (see Consequences).

## Alternatives considered

- **Hold the start until finish** ([Holding The Start Message](../wiki/Holding%20The%20Start%20Message.md)). Throw-until-finished needs the global error handler and re-runs the chain on every redelivery (repeated top-ups); wait-in-handler busies the pod's single consumer and deadlocks the inner events on one pod; a dedicated queue needs new infra. This ADR avoids all three by not holding.
- **Postgres bucket** ([ADR-0001](ADR-0001%20Hub%20Postgres%20Bucket.md)). A table, a module, and an atomic claim/finish. Gives one file end-to-end per wallet. This ADR trades that strict guarantee for no new storage.
- **Re-group only the start, or only the terminal.** Insufficient: the start acks early (parks at registry), and the terminal is sent after the later starts, so FIFO send-order does not gate them. The work must ride the wallet group across the whole chain.
- **Re-group the public events in place (set `messageGroupId` on the shared publish).** Reorders the external consumers: `HubDocumentSyncingRequestedEvent` feeds metachain, `HubSymbolRegisteringSucceededEvent` feeds deals. Hence the internal-event split instead.

## Consequences

- **Positive**: Ten parallel chains per portfolio collapse to one handler at a time per wallet. No retry-driven repeated top-ups (no throw). No new table or module. Reuses the existing events and the existing org lock. The 90 s funding wait gives natural spacing toward THE HUB.
- **Negative / trade-offs**: FIFO serialises handler **execution**, not the async THE HUB round-trip. "One handler at a time" is not "one file end-to-end"; the start acks early, so the serialisation is shallow and the async tails of several files overlap. This is acceptable precisely because nonce-safety is enforced downstream by THE HUB's `wallet_tx_jobs` queue (see Finding), not by this group. Adds a parallel set of `Internal` events and per-source translators to maintain. The parent-wallet confirmation-gap double top-up stays (`NvnmNativeTransfer.send` returns unconfirmed on a 60 s timeout and releases the lock) — org-scoped and pre-existing, untouched by this design. Correctness leans on the 503→requeue path and on `ensure*` idempotency.
- **Follow-ups / open threads**:
  - `ensure*` idempotency under requeue: verified check-then-act on the real balance (`IdentityWalletFunds.ensureRequired`/`ensureQuoted` skip when funded), so a requeue does not re-fund a confirmed wallet. Residual: the 60 s confirmation gap above.
  - Publish mechanics for the `Internal` events: `context.messageGroupId` on the normal path (simple, but `SnsProducer` swallows publish errors → a lost internal start is silent) versus a dedicated `SendMessage` producer (surfaces the error, new code). The start signal must not be lost silently.
  - 503→requeue-to-tail policy ([Open Questions](../wiki/Open%20Questions.md) #6). **Blocker: the retryable status does not survive the boundary.** THE HUB returns a genuine `503 SERVICE_UNAVAILABLE` for queue-full (`errorCodes.BLOCKCHAIN_WALLET_TX_QUEUE_FULL` = `1298`, `hub/apps/backend/src/errors/utils.ts`), but IO Hub's `HubTokenizationProvider.write` catches **every** write error and rethrows it as `UnprocessableEntityException` (**HTTP 422**), regardless of the upstream status (`inveniam.io/apps/hub-service/src/tokenization/hub-tokenization.provider.ts`, confirmed by test `hub-tokenization.provider.test.ts` "should map a 503 queue-full response to a write failure"). Collapsing 503→422 destroys the retry semantics: 503 is transient/retryable (backpressure, "retry later"), 422 says the request is permanently invalid. So the ADR's "503→requeue-to-tail" path **cannot fire end-to-end today** — the requeue trigger keyed on 503 never sees a 503; the file looks like a permanent client failure. Fix (code, left to the team): propagate a retryable status (503 or 429 Retry-After) and/or a queue-full marker through `HubTokenizationProvider.write` to `HubDocumentSyncingFailedEvent` / `HubSymbolRegisteringFailedEvent`, and reserve 422 for genuinely invalid payloads.
  - Explicit acceptance of the ack-vs-terminal async gap, or a later gate if it proves too loose.
  - Production `maxReceiveCount`, visibility timeout, retention for the hub queue.

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `shared-modules/Events/` (new `*Internal` events) + `EventsConstants.ts` `EventToMSMap` | `ClientDLTTransactionInternal`, `HubDocumentSyncingRequestedInternal`, a register→document continuation event; each mapped to `['hub']` |
| `shared-modules/NestAwsCqrs/src/broker/aws/` (publish of the internal events) | `MessageGroupId` = signing wallet, via `context.messageGroupId` or a dedicated `SendMessage` producer (see open threads) |
| `apps/hub-service/src/organisation-provisioning/application/sagas/client-dlt-provisioning.saga.ts` | Translator: `ClientDLTTransaction` → resolve wallet + intake guard → publish `ClientDLTTransactionInternal`. Saga listens to the `Internal` event |
| `apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts` | `regular` translator: `HubDocumentSyncingRequestedEvent` → `HubDocumentSyncingRequestedInternal`, group by `organisationId`, no mapping lookup |
| `apps/hub-service/src/organisation-provisioning/application/sagas/store-deal-anchor-registry.saga.ts` | Drive `RunDocumentProvisioning` off the internal continuation event |
| `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts` | Unchanged. Stays as the org-scoped guard |
| `apps/hub-service/src/tokenization/hub-tokenization.provider.ts` (`write`) | **Stop masking upstream 503 as 422.** Propagate a retryable status (503 / 429 Retry-After) or a queue-full marker so the 503→requeue-to-tail path can trigger; keep 422 only for genuinely invalid payloads |

## Related

- [Decision register](INDEX.md)
- [Holding The Start Message](../wiki/Holding%20The%20Start%20Message.md)
- [SQS FIFO Approach](../wiki/SQS%20FIFO%20Approach.md)
- [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
- [ADR-0010 Hub Advisory Lock Scope Registry](ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md)
- [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md)
