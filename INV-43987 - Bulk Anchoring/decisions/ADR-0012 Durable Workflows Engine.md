---
name: ADR-0012 Durable Workflows Engine
date: 2026-11-16T19:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - adr
  - architecture
  - workflows
---

# ADR-0012 Durable Workflows Engine

> [!info] Active investigation — side track
> This ADR explores `@nestjs/workflows` as a durable-execution engine for the anchoring chain. It is part of the active line (with [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)), not the on-hold Postgres bucket (ADR-0001…ADR-0010). The concrete hybrid design built on top of it is [ADR-0013](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md).

- **Status**: Proposed
- **Date**: 2026-11-16
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0011 FIFO Per-Wallet Chain Without Hold](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md), [ADR-0013 Hybrid Workflows Over Hub Queue](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md), [Open Questions](../wiki/Open%20Questions.md), [SQS FIFO Approach](../wiki/SQS%20FIFO%20Approach.md)
- **Sources**: NestJS docs — [Durable workflows](https://docs.nestjs.com/reliability/workflows), [CQRS → Durable sagas](https://docs.nestjs.com/recipes/cqrs#durable-sagas)

## Context

The anchoring chain is a long-running, multi-event process: it signs on a wallet, **parks** at the register and document steps, and resumes on THE HUB's webhook (possibly on another pod), hours later. Every design so far ([ADR-0001](ADR-0001%20Hub%20Postgres%20Bucket.md) bucket, [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) FIFO) hand-builds three things: per-wallet serialisation, durable parking across restarts, and idempotent retry. The open threads in [Open Questions](../wiki/Open%20Questions.md) #7 and #8 (a pod dies mid-run; graceful shutdown) are exactly the "survive a restart" problem a durable engine exists to solve.

NestJS ships a durable-execution engine, `@nestjs/workflows` (a Temporal-style engine backed by your own Postgres/MySQL). It offers, natively, the three capabilities we keep rebuilding:

- **Per-key serialisation** — `@Workflow('…', { concurrency: { limit: 1, key: (input) => input.walletKey } })`. One running execution per key across every worker and host. Critically, an instance **holds the slot only while it runs steps, not while it sleeps or waits**: a file parked for days on a webhook holds up nobody, and a crashed process frees its slots when its lease expires. This is per-wallet serialisation as a declaration.
- **Durable parking** — `ctx.waitForSignal(name, signal, { key, timeout: '3d' })` / `ctx.waitForAny(...)` with a timer. State lives in the store, so the wait survives restarts and deploys. `leaseDuration` hands a dead process's instances to another.
- **Idempotent steps + compensation** — `ctx.step('name', ({ idempotencyKey }) => …, { retry, compensate })`. A completed step never re-runs; a step the process died in re-runs with the **same** `idempotencyKey`; `compensate` undoes completed steps on failure or cancel.

CQRS integration (`@nestjs/workflows/cqrs`): `@StartOn(Event, { id, concurrencyKey })` and `@SignalOn(Event, { signal, key })` map existing events onto workflows. Events publish in the business transaction (`eventBus.publish(event, { transaction })`), so the instance exists **iff** the business write committed. Existing event handlers and sagas still receive every event, after the workflows.

### The version blocker (verified)

`@nestjs/workflows/cqrs` requires `@nestjs/cqrs` **11+**; the transactional `commit({ transaction })` guarantee requires **12.1+**. Our stack is far behind (verified 2026-11-16):

| Package | Our version | Needed for Workflows CQRS |
| ------- | ----------- | ------------------------- |
| `@nestjs/core` | `8.4.7` (`apps/hub-service/package.json`, `shared-modules/NestAwsCqrs/package.json`) | 10/11-era |
| `@nestjs/cqrs` | `8.0.5` (`shared-modules/NestAwsCqrs/package.json`) | `11+`, `12.1+` for transactional publish |
| `@inveniam/nest-aws-cqrs` | `1.0.0` fork wrapping cqrs `8.0.5`, SNS/SQS broker (`apps/hub-service/package.json`) | must forward the dispatcher-context `transaction` and keep the broker publisher in the chain |
| `@nestjs/workflows` | not installed | — |

So the clean `@StartOn`/`@SignalOn` path is **not available on the current stack**. Two things stand between us and it: a NestJS 8 → 10/11 and cqrs 8 → 12.1 upgrade, and reconciling the `@inveniam/nest-aws-cqrs` fork (our events come off SNS/SQS, not the in-memory `EventBus`) with `WorkflowsCqrsModule`.

## Decision

Record `@nestjs/workflows` as the **preferred long-term orchestration engine** for the anchoring chain, and **do not adopt it yet**. It is blocked on a framework upgrade, not on design.

- The engine, once available, replaces the hand-built serialisation + durability + idempotency of the bucket and FIFO lines with declarations: `concurrency.key` = per-wallet serialisation, `waitForSignal` = durable parking, `ctx.step` = idempotent retry + compensation.
- It is **not** required to own nonce-safety: that already lives in THE HUB's `wallet_tx_jobs` queue (see [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) Finding). Workflows orchestrate; THE HUB serialises the ledger write. The concrete split is [ADR-0013](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md).
- Near term, serialisation ships via [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) (SQS FIFO). Workflows are a later migration target once the upgrade lands.
- A **compatibility spike** is the gate: confirm a NestJS/cqrs upgrade path, whether `@inveniam/nest-aws-cqrs` can forward the dispatcher-context transaction (or whether `WorkflowClient.start()/signal()` is driven directly from command handlers / webhook controllers, bypassing `WorkflowsCqrsModule`), and the store/migration/pool cost on our Postgres.

## Alternatives considered

- **Adopt Workflows now.** Blocked: needs `@nestjs/cqrs` 11+/12.1+ and NestJS 10/11; we are on 8. Not a design choice, a version wall.
- **Use `WorkflowsModule` without the CQRS mapping** (drive `WorkflowClient.start()/signal()` from our own handlers). Avoids `@StartOn`/`@SignalOn` and the cqrs-11 requirement for the mapping, but the `@nestjs/workflows` package itself is a NestJS 10/11-era dependency with its own peer requirements, so it almost certainly still needs the core upgrade. To be settled by the spike.
- **Keep hand-building** (bucket / FIFO only, no engine). Ships on the current stack, but we re-implement lease+drain, idempotent resume, and compensation ourselves — exactly [Open Questions](../wiki/Open%20Questions.md) #7/#8. Acceptable as the interim, not as the destination.

## Consequences

- **Positive**: Names the destination so the FIFO work ([ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)) is understood as interim, not the end state. Collapses three hand-built mechanisms into framework declarations. Durable parking solves #7/#8 by construction.
- **Negative / trade-offs**: Requires a major framework upgrade (NestJS 8 → 10/11, cqrs 8 → 12.1) and fork reconciliation before any of it is usable. New dependency, new store tables (`nest_workflows_*`), migrations, connection-pool sizing (each live instance renews its lease and writes its journal through the pool). `run()` must stay deterministic (all I/O in steps; `ctx.now()/random()/uuid()`), and a non-deterministic deploy breaks replay.
- **Follow-ups / open threads**:
  - Compatibility spike (the gate above). Until it passes, this ADR stays Proposed.
  - Whether the upgrade is in scope for this feature or a separate platform track.
  - Per-wallet `concurrency.key` gives "one running step at a time per wallet", not "one file end-to-end" — same depth as [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md); still leans on THE HUB nonce-safety and top-up idempotency.

## Affected code

Nothing is changed yet. Nothing is adoptable until the spike and the upgrade.

| Path | What would change |
| ---- | ----------------- |
| `package.json` (root, `apps/hub-service`, `shared-modules/NestAwsCqrs`) | NestJS 8 → 10/11, `@nestjs/cqrs` 8 → 12.1, add `@nestjs/workflows` — **not without an explicit platform decision** |
| `shared-modules/NestAwsCqrs/` | Reconcile the fork with `WorkflowsCqrsModule`: forward the dispatcher-context `transaction`, keep the SNS/SQS publisher in the chain |
| `apps/hub-service/src/**` workflow classes (proposed) | `@Workflow` + `@StartOn`/`@SignalOn` on the anchoring chain; a `PostgresWorkflowStore` on the existing datasource |

## Related

- [Decision register](INDEX.md)
- [ADR-0011 FIFO Per-Wallet Chain Without Hold](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)
- [ADR-0013 Hybrid Workflows Over Hub Queue](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md)
- [Open Questions](../wiki/Open%20Questions.md)
- [SQS FIFO Approach](../wiki/SQS%20FIFO%20Approach.md)
