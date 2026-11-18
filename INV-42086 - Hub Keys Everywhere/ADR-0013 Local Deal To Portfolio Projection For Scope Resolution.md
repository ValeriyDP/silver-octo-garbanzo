---
name: ADR-0013 Local Deal To Portfolio Projection For Scope Resolution
date: 2026-08-24T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - scoped-keys
  - vault
  - ledger
  - architecture
  - adr
---

# ADR-0013 Local Deal → Portfolio Projection For Scope Resolution

- **Status**: **Accepted (implemented)** (2026-08-24). Refines [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md): makes a local `deal → portfolio` lookup the **primary** scope reconstruction. **Shipped in hub-service** as a dedicated `deal_scope` projection (see "Decision"). Relocation upkeep remains out of PoC scope; a projection miss degrades to org-level.
- **Date**: 2026-08-24
- **Area**: hub-service (self-contained)
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0012 Path Seeker Reconstruct Scope Then Closest](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md), [ADR-0009 In-App NVNM Register Symbol Flow](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md), [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md), [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md), [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

## Context

[ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md) resolves signing scope inside hub-service from `org + deal` by **walking Vault** (`LIST Credentials/{org}/*/{deal}/`) to recover the portfolio, then runs the ADR-0007 closest climb. That works at both read sites (send + `onComplete`) but has three costs: it needs a Vault **`list`** policy, it is `O(#portfolios)`, and it is **blind to portfolio-only keys** (the deal must be materialized in Vault to reverse-map its portfolio).

While looking for a cheaper portfolio source, we found hub-service **already maintains a local deal projection** — and the events feeding it already carry the portfolio.

### hub-service already listens to deal lifecycle

The `inveniam-data` domain consumes `DealCreatedEvent` + `DealUpdatedEvent` and persists a local `deals` row, but today stores only `{ id, title }`:

```16:19:inveniam.io/apps/hub-service/src/inveniam-data/application/sagas/deals.sagas.ts
          return new SaveDealCommand({
            id: payload.id,
            title: payload.title
          });
```

```8:16:inveniam.io/apps/hub-service/src/inveniam-data/domain/entities/deals.entity.ts
@Entity('deals')
export class DealsEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column('varchar')
  title: string;
}
```

### The portfolio is already in those payloads

Both create and update payloads carry portfolio + parent chain:

```103:104:inveniam.io/shared-modules/Events/Deals/Deals/deal.interfaces.ts
  portfolioId?: string;
  parentPortfolioIds?: string[];
```

(`DealCreatePayloadDTO` and `DealUpdatePayloadDTO`.)

### There is a dedicated relocation event

When a deal changes location (moved to another portfolio), a dedicated event carries the new portfolio + chain:

```3:9:inveniam.io/shared-modules/Events/DataRoom/Room/data-room-deal-moved.event.ts
export interface DataRoomDealMovedEventPayload {
  aggregateId: string;
  dealId: string;
  resourcePath: string;
  portfolioId: string;
  parentPortfolioIds: string[];
}
```

(There is also an IAM `deal-resource-moved` family; the authoritative one for the portfolio a key is written under must be confirmed at implementation.)

## Decision

Introduce a **new, dedicated `deal_scope` projection table** (`deal_id → portfolio`) rather than extending the existing `deals` entity. Feed it from the same deal-lifecycle events, keep it fresh on relocation, and make **Path Seeker resolve the portfolio via a local O(1) lookup by `dealId`**, falling back to the ADR-0012 Vault walk on a miss.

> **Why a separate table (not extend `deals`)**: the existing `deals` projection is a general-purpose `{ id, title }` cache; scope resolution is a distinct concern for INV-42086. A dedicated table keeps the two decoupled — the scoped-keys feature owns its own entity/saga/repository and can be added or removed without touching the deal cache, its `SaveDealCommand`, or its silent-error handler. It also lets the scope projection subscribe to the relocation event(s) independently.

### 1. New `deal_scope` projection

- New `DealScopeEntity` (`deal_id` PK uuid, `portfolio_id` uuid nullable, `parent_portfolio_ids` uuid[] nullable) + migration.
- New model / DTO / repository (`get(dealId)`) and a `SaveDealScopeCommand` (+ handler) — all in a small self-contained module (or under `inveniam-data`), independent of `DealsEntity`/`SaveDealCommand`.

### 2. Populate + keep fresh

- New saga subscribing to `DealCreatedEvent` + `DealUpdatedEvent` → `SaveDealScopeCommand`, mapping `portfolioId` + `parentPortfolioIds` from the payloads (already present). **Partial `DealUpdatedEvent` payloads often omit `portfolioId`** (title/image/type-only updates). `DealScopeModel.save` **merges**: omitted portfolio fields keep the existing row. The saga also takes `context.portfolioId` when the payload omits it (HTTP-originated updates still have it on `BaseEvent.context`). Do **not** treat a missing payload field as “clear the portfolio”.
- Relocation upkeep (subscribing to `DataRoomDealMovedEvent` / IAM `deal-resource-moved`) is **out of scope for this PoC** — see "Out of scope" below.

### Out of scope (PoC)

We are **not** implementing **deal relocation handling** in this PoC: a **deal moving across portfolios**, or a **portfolio/deal being re-rooted under a different root**. The `deal_scope` projection is populated at create/update time and is assumed **stable** for the demo. This must be **taken into consideration** for the durable solution — a relocation without a corresponding projection update would leave a stale `portfolio`, and scope resolution would fall back to the Vault walk (and, failing that, org). When relocation is brought into scope, add the relocation saga (step 2) and pick the authoritative event that matches the write-time (root) portfolio.

### 3. Resolve scope from the projection (primary), walk as fallback

In `ledger-factory.provider.ts` (NVNM branch), reconstruct scope as:

```
portfolio = DealScopeRepository.get(dealId)?.rootPortfolio(parentPortfolioIds)
if portfolio present:  scope = { org, portfolio, deal }          // local, O(1)
else:                  scope = ADR-0012 Vault walk (org + deal)  // fallback
findClosestByScopeAndLedger(scope, NVNM)                          // ADR-0007, unchanged
```

Because the **data-room rung is redundant** (deal ↔ data room is 1:1 — see the ADR-0012 observation and `UQ__deal_id`), the projection's `portfolio` + payload's `org`/`deal` are enough: **no Vault `LIST` is needed on the primary path**, so no `list` policy is required unless the walk fallback is exercised.

Layering: **projection → walk → org** (org remains the last rung of closest).

## Alternatives considered

- **[ADR-0012] Vault walk as the primary** — kept, but demoted to fallback: it needs a `list` policy, is `O(#portfolios)`, and cannot resolve portfolio-only keys. The projection removes all three on the hot path.
- **Extend the existing `deals` entity** (add two columns) — rejected: couples an unrelated general-purpose cache to the scoped-keys feature, entangles its `SaveDealCommand` + silent-error handler, and makes the feature harder to remove cleanly. A dedicated `deal_scope` table keeps the concern self-contained.
- **Read portfolio from ambient request-context** — send-only (no context at `onComplete`); the projection works at both sites.
- **Cross-service call to deals-service on the send path** — rejected (synchronous coupling on the hot path); the projection is the async, already-subscribed equivalent.
- **Store `dataRoomId` on the projection too** — unnecessary given the redundant data-room rung; deal-level precedence suffices. Revisit only if per-provider scoping is ever introduced.

## Consequences

- **Positive**: O(1) local lookup; **no Vault `list` policy** on the primary path; works at **both** read sites (send + `onComplete`, both have `dealId`); **eliminates the portfolio-only blind spot** (portfolio is known independently of Vault); reuses an existing, wired projection; still degrades to org-only in the worst case.
- **Negative / trade-offs**:
  - **Eventual consistency**: the projection must be populated before a sync. New deals are covered by `DealCreated`; a sync racing a just-created deal, or a **pre-existing deal** (created before this table existed), would miss → relies on the **walk fallback** (and/or a one-time **backfill**).
  - **Relocation upkeep**: correctness after a move depends on subscribing to the right relocation event(s); pick the one that matches the write-time portfolio (root).
  - **New handler**: `SaveDealScopeCommandHandler` is new, so it can choose its own error policy (unlike the existing `SaveDealCommandHandler` which swallows). A persist failure should still leave the walk fallback able to resolve — do **not** let a projection miss silently sign at org.
  - **Root vs direct**: store `parentPortfolioIds` and derive root to match the write path.
- **Boundary condition**: same as ADR-0012 — holds while scoped keys are room-id-/deal-keyed; per-provider scoping would need the provider/room id threaded in.

## Affected code (planned)

| Path | What changes |
| ---- | ------------ |
| `inveniam.io/apps/hub-service/.../domain/entities/deal-scope.entity.ts` | **new** `deal_scope` entity: `deal_id` PK, `portfolio_id`, `parent_portfolio_ids` |
| `inveniam.io/apps/hub-service/.../domain/models/deal-scope.model.ts` + DTO | **new** model / `DealScopeDTO` with `save()` + `rootPortfolio()` |
| `inveniam.io/apps/hub-service/.../domain/commands/save-deal-scope.command.ts` (+ handler) | **new** command to upsert the projection |
| `inveniam.io/apps/hub-service/.../application/sagas/deal-scope.sagas.ts` | **new** saga: `DealCreated`/`DealUpdated` + relocation (`DataRoomDealMoved`/IAM `deal-resource-moved`) → `SaveDealScopeCommand` |
| `inveniam.io/apps/hub-service/.../infrastructure/repositories/deal-scope.repository.ts` | **new** read-by-id used by the resolver |
| module wiring (e.g. `inveniam-data.module.ts` or a new small module) | register entity, command handler, saga, repository |
| `inveniam.io/apps/hub-service/.../transactions/application/providers/ledger-factory.provider.ts` | NVNM resolver: `DealScopeRepository` lookup → (miss) ADR-0012 walk → closest; both call sites pass `dealId` |
| `inveniam.io/apps/hub-service/src/migrations/<ts>-add-deal-scope-table.ts` | **new** TypeORM migration (create/drop `deal_scope`, mirror the `add-deals-table` migration); creates the table on fresh envs too — no structure-dump edit needed |
| backfill | optional one-time backfill of existing deals' portfolio |
| tests | projection persist (create/update/move), resolver projection-hit + walk-fallback + org-last, `onComplete` path |

## Related

- [ADR-0012 Path Seeker Reconstruct Scope Then Closest](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md)
- [ADR-0009 In-App NVNM Register Symbol Flow](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)
- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
