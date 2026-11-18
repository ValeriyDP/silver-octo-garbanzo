---
name: ADR-0013 Hybrid Workflows Over Hub Queue
date: 2026-11-16T20:05:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - adr
  - architecture
  - workflows
---

# ADR-0013 Hybrid Workflows Over Hub Queue

> [!info] Active investigation — target architecture
> This ADR builds on [ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md) (the engine) and [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) (the interim serialiser). It is the **hybrid**, not a replacement: durable workflows orchestrate; THE HUB keeps nonce-safety; the existing event contract stays.

- **Status**: Proposed
- **Date**: 2026-11-16
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0012 Durable Workflows Engine](ADR-0012%20Durable%20Workflows%20Engine.md), [ADR-0011 FIFO Per-Wallet Chain Without Hold](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [Open Questions](../wiki/Open%20Questions.md)

## Context

Three facts, each established elsewhere, define the seams of this design:

1. **Nonce-safety is already owned by THE HUB.** Writes go through the durable per-wallet `wallet_tx_jobs` queue: single in-flight per wallet, depth guard, nonce ordering ([ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) Finding). The IO Hub layer does **not** need to make the ledger write safe.
2. **Durable workflows are the right engine but blocked on a version upgrade.** `@nestjs/workflows` needs NestJS 10/11 + `@nestjs/cqrs` 12.1; we are on NestJS 8 + cqrs 8.0.5 ([ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md)).
3. **FIFO per-wallet ships on the current stack today** ([ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)), but leaves the restart/park durability gaps open ([Open Questions](../wiki/Open%20Questions.md) #7/#8).

A pure-workflows rewrite throws away (1) and is blocked by (2). A pure-FIFO design keeps the #7/#8 gaps forever. The hybrid takes the best of each: let each layer own the thing it is already good at.

## Decision

Split the problem across two layers and keep the existing event contract between them.

### Layer split

- **THE HUB (`hub/apps/backend`) owns nonce-safety and the on-chain write.** Unchanged. The `wallet_tx_jobs` queue stays the single serialiser of ledger writes per wallet. No per-wallet logic is rebuilt above it.
- **IO Hub (`apps/hub-service`) owns orchestration + durability of the per-file chain**, with a durable workflow per file:
  - **Per-wallet serialisation** via `concurrency: { limit: 1, key: walletKey }` on the workflow, where `walletKey` is the [ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md) key (`anchoring:identity:{portfolioId}` for `client_dlt`, `anchoring:org:{organisationId}` for `regular`). This replaces the SQS FIFO group as the serialiser — one engine, one place.
  - **Durable parking** via `ctx.waitForSignal` on the register and document webhooks, with a `timeout`. This closes [Open Questions](../wiki/Open%20Questions.md) #7/#8 without the hand-built lease+drain.
  - **Idempotent writes** via `ctx.step(..., { idempotencyKey })`, the key handed to THE HUB write API so a replay cannot double-submit; `compensate` for undo.
- **The public event contract is unchanged.** `ClientDLTTransaction`, `HubSymbolRegisteringSucceededEvent`, `HubDocumentSyncingRequestedEvent` et al. keep flowing to deals / metachain / dataroom. The workflow is **started and signalled** by these events (`@StartOn`/`@SignalOn`), or by direct `WorkflowClient.start()/signal()` calls from the existing command handlers and webhook controllers if the CQRS mapping is blocked by the fork.

### What each ADR becomes under the hybrid

- [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) (FIFO) is the serialiser that ships now, on NestJS 8. Its `*Internal` events and per-wallet group do the serialising until workflows land — and may **stay** afterwards (see below).
- When workflows land, `concurrency.key` can serialise per wallet. Retiring the FIFO group is then **one option, not a requirement**: the workflow is an **addition**, and the two can coexist deliberately. The FIFO group keeps real value independent of workflow concurrency — broker-level **ordering** of a portfolio's files and **backpressure** (the 503→requeue path) before work is even picked up, which `concurrency.key` (an in-engine wait on already-admitted instances) does not give. Options at cutover: (a) retire the FIFO group and let `concurrency.key` serialise; (b) keep FIFO for ordering/backpressure and set `concurrency` higher (or off) so it does not double-gate; (c) keep both with `concurrency: { limit: 1 }` as a safety belt. The choice is per source / per environment and does not have to be the same everywhere.
- The `wallet_tx_jobs` queue (THE HUB) stays the nonce-safe writer in every option.
- The Postgres bucket line (ADR-0001…ADR-0010) stays superseded: the workflow store is the durable state, not a hand-rolled bucket table.

### Migration path (hybrid over time, not only over layers)

1. **Now**: ship [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) FIFO for serialisation; THE HUB queue already in place for nonce-safety. Fix the 503→422 masking ([ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) open thread) so backpressure works.
2. **Spike** ([ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md) gate): prove the NestJS/cqrs upgrade path and the `@inveniam/nest-aws-cqrs` ↔ `WorkflowsCqrsModule` reconciliation (or the direct-client fallback).
3. **Later**: introduce the per-file workflow with `waitForSignal` parking and (optionally) `concurrency.key` serialisation. The FIFO group may be retired or kept for ordering/backpressure — the workflow is an addition, not a mandated replacement. Keep the event contract and THE HUB queue.

## Alternatives considered

- **Pure workflows (workflow owns serialisation, parking, and the write).** Cleanest on paper, but discards THE HUB's existing nonce-safe queue and is blocked by the version wall. Rejected: don't rebuild (1), don't wait on (2) for everything.
- **Pure FIFO (no workflows ever).** Ships now, but the restart/park durability ([Open Questions](../wiki/Open%20Questions.md) #7/#8) stays hand-built forever. Rejected as the destination; accepted as step 1.
- **Workflow does the ledger write directly, bypassing THE HUB queue.** Would duplicate nonce management in two places. Rejected: THE HUB stays the single writer.

## Consequences

- **Positive**: Each layer owns what it is already best at — THE HUB nonce-safety, workflows durability + per-wallet serialisation. No double serialisation. The event contract and external consumers are untouched. A clear, incremental path: FIFO now, workflows later, no big-bang rewrite.
- **Negative / trade-offs**: If both the FIFO group and `concurrency.key` serialise the same wallet, they double-gate — harmless to safety but redundant, so the cutover must pick a lane (retire FIFO, raise/disable `concurrency`, or keep both as a deliberate safety belt). Still carries the [ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md) upgrade cost. Per-wallet concurrency is "one running step at a time", not "one file end-to-end" — fine, because THE HUB queue is the real write serialiser.
- **Follow-ups / open threads**:
  - Cutover plan: whether to retire the FIFO group, keep it for ordering/backpressure, or keep both as a safety belt — decided per source / environment (feature flag?). FIFO and `concurrency.key` may coexist deliberately; the open point is only avoiding redundant double-gating, not a forced removal.
  - Where `walletKey` is resolved for the workflow start (same resolver as the [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) translator: `client_dlt` needs `deal_anchors` + `io_hub_organisation_map`; `regular` keys on `organisationId`).
  - Whether the workflow is started by `@StartOn` (needs the fork reconciliation) or by a direct `WorkflowClient.start()` from the existing saga/handler.
  - THE HUB 503 must reach the workflow as retryable so `ctx.step` retry/backoff can requeue — same 503→422 blocker as [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md).

## Affected code

Nothing is changed yet. Depends on the [ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md) spike.

| Path | What would change |
| ---- | ----------------- |
| `hub/apps/backend/src/wallet-transaction-queue/**` | Unchanged. Stays the nonce-safe writer |
| `apps/hub-service/src/**` per-file workflow (proposed) | `@Workflow({ concurrency: { limit: 1, key: walletKey } })`, `ctx.step` for THE HUB writes, `ctx.waitForSignal` for register/document webhooks |
| `apps/hub-service/.../sagas/**` | Start/signal the workflow (via `@StartOn`/`@SignalOn` or direct `WorkflowClient`); the in-process commands stay as the step bodies |
| `apps/hub-service/src/tokenization/hub-tokenization.provider.ts` (`write`) | Propagate THE HUB 503 as retryable so `ctx.step` retry can requeue (shared with [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)) |
| `package.json` + `shared-modules/NestAwsCqrs/` | Per [ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md): upgrade + fork reconciliation — gated on the spike and a platform decision |

## Related

- [Decision register](INDEX.md)
- [ADR-0012 Durable Workflows Engine](ADR-0012%20Durable%20Workflows%20Engine.md)
- [ADR-0011 FIFO Per-Wallet Chain Without Hold](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)
- [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
- [Open Questions](../wiki/Open%20Questions.md)
