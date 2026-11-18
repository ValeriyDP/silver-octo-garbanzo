---
name: ADR-0012 Path Seeker Reconstruct Scope Then Closest
date: 2026-08-23T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - data-room-service
  - scoped-keys
  - vault
  - ledger
  - architecture
  - adr
---

# ADR-0012 Path Seeker — Reconstruct Scope Then Closest

- **Status**: **Accepted (implemented)** (2026-08-24). The signing half of the accepted path; pairs with [ADR-0009](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md) (registration, implemented). Replaces the **rejected** [ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md) (cross-service event threading) and [ADR-0011](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md) (org-slot copy). **Shipped in hub-service**: NVNM scope-aware credential resolution in `ledger-factory.provider.ts` (deal → root portfolio via the ADR-0013 `deal_scope` projection → gapless closest climb `deal → portfolio → org`), `dealId` threaded from `syncDocument`/`registerSymbol`/`onComplete`. The original Vault-walk fallback is unused: a projection miss degrades to org-level.
- **Refined by [ADR-0013](ADR-0013%20Local%20Deal%20To%20Portfolio%20Projection%20For%20Scope%20Resolution.md)** (2026-08-24): a local `deal → portfolio` projection becomes the **primary** way to recover the portfolio (O(1), no Vault `list`, no portfolio-only blind spot); the **Vault walk described here is demoted to the fallback** used on a projection miss.
- **Date**: 2026-08-23
- **Area**: hub-service (self-contained)
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0010 Scope-Aware Credentials In Transaction Execution](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md), [ADR-0011 NVNM Org-Slot Key Promotion For Sync (Demo)](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md), [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md), [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md), [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

## Context

Same failure as [ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md)/[ADR-0011](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md): DLT **Sync** signs with an **org-only** credential lookup, so a scoped NVNM key at `…/{org}/{portfolio}/{deal}/{dataRoom}/NVNM/testnet` 404s (`HubDocumentSyncingFailedEvent reason: "Hub credentials were not found"`).

```ts
// hub-service .../transactions/application/providers/ledger-factory.provider.ts
await secureStorageProvider.getHubCredentials(ledgerType, organisationId);
```

[ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md) concluded the scope couldn't be recovered on the send side and therefore had to be **threaded through the events** (shared `@inveniam/events` + data-room-service + deals-service + hub-service). [ADR-0011](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md) sidestepped that with an org-slot copy (with a global-slot concurrency caveat). This ADR records a **third finding** that makes both largely unnecessary: **the scope is already recoverable inside hub-service, with no event-schema change**. It rests on three facts verified against the repo in this session.

### Fact 1 — deal ↔ data room is 1:1, and the scoped `dataRoomId` is the room id (not a provider)

A deal can have **up to ~7 storage providers** (S3, Box, Drive, OneDrive, SFTP, SharePoint…), but those are `deal_data_room_provider` rows that all hang off **one** `data_rooms` row. The `data_rooms` table enforces it:

```sql
-- inveniam.io/apps/data-room-service/src/dumps/structure/invdataroom.sql
CREATE TABLE IF NOT EXISTS "data_rooms" (
    "deal_id" uuid NOT NULL,
    ...
    CONSTRAINT "UQ__deal_id" UNIQUE ("deal_id")
```

The scoped key's `dataRoomId` is `dataRoomBase.value().id` — the **single** `data_rooms.id` (`GET /dataroom/by-deal/:dealId` returns one `RoomEntity`); the 7 providers live under `dataRoomConfig.storageProviders[]` and never become distinct scoped paths. So `…/{org}/{portfolio}/{deal}/` has **at most one** `{dataRoom}` child.

> **Observation (2026-08-24) — the data-room rung is redundant.** Because the deal ↔ data room is 1:1 (`UQ__deal_id`) and keys are keyed by the **room id** (not the provider id), a key at `…/{deal}/{dataRoom}` addresses the *same* documents as one at `…/{deal}`. The data room doesn't subdivide the deal — it **is** the deal's room — so the data-room level buys **zero extra granularity**. The lowest *meaningful* scope is therefore the **deal**, and the practical hierarchy is **org → portfolio → deal** (3 levels, not 4). If keys were written at the deal level, Path Seeker would need **no data-room `LIST`/disambiguation** and closest would climb one fewer rung (`deal → portfolio → org`). Acting on this would change the scoped **write** path (ADR-0001 currently writes at the data-room level) and warrants its own ADR; it is only recorded as an observation here. The data-room rung would regain meaning only if the 1:1 broke (a deal owning multiple rooms) or if scoping moved to **per-provider** keys — neither is true today.

### Fact 2 — the event carries scope in `context`, a sibling of `payload` (the saga drops it)

`BaseEvent` has both `payload` and `context`:

```44:48:inveniam.io/shared-modules/Events/src/BaseEvent/base-event.ts
export abstract class BaseEvent implements IBaseEvent {
  public payload;
  public error;
  public meta: IBaseEventMeta;
  public context: IBaseEventContext = {};
```

`context` includes `organisationId`, `portfolioId`, `parentPortfolioIds`. But the sync saga forwards **only `payload`** (which has `dealId`+`organisationId`, no portfolio/data-room), so the command never sees `context`:

```87:89:inveniam.io/apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts
        map(({ payload }) => {
          return new SyncDocumentCommand(payload);
        })
```

### Fact 3 — the broker consumer rehydrates the ambient request-context store from `event.context`

Even though the saga drops `context`, the CQRS framework copies it into the **ambient request-context store** on every consumed message:

```428:435:inveniam.io/shared-modules/NestAwsCqrs/src/NestAwsService.ts
  protected initRequestContext(event: IBaseEvent): void {
    generateRequestId();

    initTraceContextUsingEventContext(
      event.context,
      this.distributedTracingConfig.correlationIdProvider
    );
```

…and the trace-context config explicitly includes portfolio ids:

```25:31:inveniam.io/shared-modules/DistributedTracing/src/distributed-tracing.ts
const additionalTraceContextConfig = {
  [CONTEXT_TYPE.USER_ID]: CONTEXT_TYPE.USER_ID,
  [CONTEXT_TYPE.ORGANISATION_ID]: CONTEXT_TYPE.ORGANISATION_ID,
  [CONTEXT_TYPE.PORTFOLIO_ID]: CONTEXT_TYPE.PORTFOLIO_ID,
  [CONTEXT_TYPE.PARENT_PORTFOLIO_IDS]: CONTEXT_TYPE.PARENT_PORTFOLIO_IDS,
  ...
```

So during the whole sync handler, `getContextData(CONTEXT_TYPE.PORTFOLIO_ID)` / `PARENT_PORTFOLIO_IDS` / `ORGANISATION_ID` are available — the same pattern the controllers already use (`transactions.controller.ts` reads `getContextData(CONTEXT_TYPE.ORGANISATION_ID)`).

## Decision

Resolve signing credentials with a **best-effort reconstruct, then closest** strategy, entirely inside hub-service, **NVNM-only**. Every other ledger/flow keeps the existing org-only `getHubCredentials`.

### Phase 1 — Reconstruct the scope (uniform base: `org + deal`)

The credential lookup must work at **two** read sites (see "Both read sites" below), and only one of them has request context. So the **uniform base is `org + deal`** — the two ids both sites always have — reconstructed via the Vault walk:

1. `LIST Credentials/{org}/` → portfolios; for each, `LIST …/{portfolio}/{deal}/` until the deal is found → recovers `portfolio` (deal lives under exactly one).
2. That last LIST's child is a **ledger-enum** (deal-level key) or the single **`dataRoomId`** (unique by Fact 1) → recovers the data-room rung.
3. **Send-side optimization (optional):** when the ambient request-context is populated (Fact 3 — proven on the send path), take `portfolioId`/`parentPortfolioIds` from `getContextData` and derive the **root portfolio** to skip the portfolio enumeration in step 1. This is a performance shortcut, **not** load-bearing — `onComplete` has no ambient context and relies purely on the walk.

Filling is **monotonic**: more rungs ⇒ equal-or-more-specific match; fewer rungs ⇒ still works, resolves higher up. Worst case (nothing recovered) === today's org-only lookup, so it is strictly safer than the current behaviour.

### Phase 2 — Closest (reuse ADR-0007, untouched)

Feed the reconstructed gapless scope to `IntegrationKeysModel.findClosestByScopeAndLedger` (candidate order data room → deal → portfolio → org; only `NotFoundException` climbs; org last). It receives a complete-as-possible path and picks the most specific existing key. The credential is then read via `getScopedHubCredentials(matchedScope)` (or `getHubCredentials(org)` at the org rung).

Wire this into `ledger-factory.provider.ts#getSpecificLedgerByLedgerType`, gated on `ledgerType === NVNM`, and pass `dealId` from **both** callers.

### Both read sites: send **and** `onComplete` (resolved 2026-08-24)

`getHubCredentials` is fetched **eagerly** whenever a provider is built (`ledger-factory.provider.ts:48`), and `getSpecificLedgerByLedgerType` is called from **two** places in `TransactionsModel`, so a scoped-only key 404s at **both**:

| Site | Trigger | Scope source | Ambient context? |
| ---- | ------- | ------------ | ---------------- |
| **Send** (`syncDocument`) | broker event | payload `deal` + ambient `org`/`portfolio` | ✅ yes |
| **`onComplete`** (`onComplete`, `transactions.model.ts:136`) | Hub webhook `POST /hub/transactions/on-complete` (middleware-`exclude`d) **or** `userop-receipt-polling.service` | persisted `TransactionsEntity` → `organisationId` + `dealId` only (no portfolio/data-room) | ❌ no |

Because `onComplete` has **no request context and no command** — only `org + deal` from the stored transaction — the resolver must key off `org + deal` (the walk). Ambient-only or saga-forwarding would fix `syncDocument` but leave `onComplete` 404ing (saga-forwarding would additionally need new `TransactionsEntity` columns to carry portfolio/data-room into `onComplete`). The `org + deal` walk covers both sites with one code path.

### Where `portfolioId` can come from

Every candidate source, and whether it is available at each read site. Legend: ✅ available · ❌ not available · ⚠️ only with extra work.

| Source | Send (`syncDocument`) | `onComplete` (webhook / poller) | Yields root or direct? | Notes |
| ------ | :-------------------: | :-----------------------------: | ---------------------- | ----- |
| Event **payload** (`HubDocumentSyncingRequestedEventPayload`) | ❌ | ❌ | — | payload has only `dealId` + `organisationId` (no portfolio); `onComplete` has no event at all |
| Event **context** (`event.context.portfolioId`) | ✅ (proven) | ❌ | **direct** (+ `parentPortfolioIds` → root) | present on the event at the saga, but dropped by `map(({ payload }) => …)` |
| **Ambient request-context** (`getContextData(CONTEXT_TYPE.PORTFOLIO_ID)`) | ✅ | ❌ | **direct** (+ `PARENT_PORTFOLIO_IDS` → root) | broker consumer rehydrates it from `event.context` (Fact 3); webhook route is middleware-`exclude`d, poller has none ⇒ empty at `onComplete` |
| **Command** (`SyncDocumentCommand`) | ⚠️ only if we forward `context` in the saga | ❌ (no command) | direct | saga change; still does nothing for `onComplete` |
| Persisted **`TransactionsEntity`** | n/a | ⚠️ only if we **add columns** | whatever we persist | today it stores `organisationId` + `dealId` only |
| **Vault walk** `LIST Credentials/{org}/*/{deal}/` | ✅ | ✅ | **root** (the exact portfolio the key was written under) | uniform base from `org + deal`; needs Vault `list`; blind to portfolio-only keys (deal must be materialized in Vault) |
| **Cross-service** lookup (deals-service by `dealId`) | ✅ | ✅ | either | rejected — synchronous coupling on the hot send path |

Two things this makes obvious:

- Only the **Vault walk** and a **cross-service lookup** are available at **both** sites; the walk is the non-coupling option ⇒ it is the primary mechanism.
- The walk also **sidesteps the root-vs-direct problem**: context/ambient give the *direct* portfolio (needing `parentPortfolioIds` to derive root), whereas the walk finds the portfolio the key was actually **written** under — exactly what closest needs.

## Alternatives considered

- **[ADR-0010] Thread `portfolioId`/`dataRoomId` through the events** — correct but heavyweight (shared events + three services, coordinated deploy). Unnecessary once Fact 3 shows the ids already arrive via context. This ADR is the lighter realization of the same goal.
- **[ADR-0011] Promote closest scoped key into the org slot (no revert)** — works but pollutes the single org slot and forces sequential syncs (global-slot concurrency). Path Seeker needs no org write and has no such concurrency hazard.
- **Read scope from the ambient request-context as the *primary* mechanism** — rejected as primary: it fixes only the **send** leg. `onComplete` (webhook/poller) has no ambient context, so the scoped key would still 404 there. Retained only as an optional **send-side optimization** to skip portfolio enumeration.
- **Forward `context` through the saga (`new SyncDocumentCommand(payload, context)`)** — rejected: fixes only the send leg, and covering `onComplete` would additionally require persisting portfolio/data-room as new `TransactionsEntity` columns. More surface than the walk, for no gain.
- **hub-service calls deals/data-room service to look up portfolio + room** — rejected (synchronous cross-service coupling on the hot send path); the walk needs no such call.

> **Design note (2026-08-24):** the `onComplete` second read site inverts the original framing — the **`org + deal` Vault walk is the primary, uniform mechanism** (works at both sites), with ambient context demoted to a send-side optimization. The trade-off is that the walk needs Vault `list` and cannot resolve a *portfolio-only* key for a deal with no deeper key (acceptable while keys live at data-room level).

## Consequences

- **Positive**: contained to hub-service (ledger-factory + a Vault `LIST` helper); no event-schema, saga, cross-service, or UI change; **one resolver covers both read sites** (send + `onComplete`); no org-slot clobber or sequential-sync constraint; reuses ADR-0007 closest verbatim; degrades gracefully to org-only. Achieves the ADR-0010 outcome with a much smaller footprint and none of the ADR-0011 downsides.
- **Negative / trade-offs**:
  - **Vault `list` policy required**: the `org + deal` walk uses the KV-v2 `metadata` LIST on `Credentials/*`. This is now load-bearing (it is the uniform mechanism, not optional), because `onComplete` cannot use ambient context.
  - **Portfolio-only blind spot**: the walk can only reverse-map a deal that is **materialized in Vault** (a key exists at deal or data-room level). A *portfolio-only* key for such a deal falls through to org. Acceptable while keys live at data-room level.
  - **Root vs direct portfolio (send optimization only)**: when using ambient to skip enumeration, `context.portfolioId` is the *direct* portfolio; derive **root** from `parentPortfolioIds` to match the write path.
  - **`onComplete` walk cost**: the webhook/poller path pays the `O(#portfolios)` LIST (no ambient shortcut available there).
- **Boundary condition**: holds while scoped keys are keyed by the **room id** (`dataRoomBase.id`). If the feature ever moves to **per-provider** scoping (`deal_data_room_provider.id`, up to 7 per deal), the `{deal}/*` LIST becomes ambiguous and the provider/room id would have to be threaded in.

## Resolved open questions (2026-08-24)

Both questions the first draft left open are now settled from code (no live run required):

1. **Is `portfolioId` on the incoming sync event context?** — **Yes, proven.** Consumer (`NestAwsService.initRequestContext` → `initTraceContextUsingEventContext`) and producer (`NestAwsPubSub.collectEventContext` → `getTraceContextFromRequestContext` → `extractAdditionalTraceContextFromRequestContext`) both use the same portfolio keys, and the broker path has no other populator. The captured `HubDocumentSyncingFailedEvent` (emitted *by* hub-service) carried `context.portfolioId = 9460b622…`, which could only originate from the incoming event's context. The temporary `getContextData` log is now optional confirmation, not a prerequisite. *(This matters only for the send-side optimization; the walk doesn't depend on it.)*
2. **Ambient store vs. forward `context` through the saga?** — **Neither, as the primary.** The `onComplete` read site has no request context and no command (only `org + deal` from the persisted `TransactionsEntity`), and `getSpecificLedgerByLedgerType` fetches credentials eagerly, so it 404s too. The uniform mechanism is the **`org + deal` Vault walk** used at *both* sites; ambient context is kept only as a send-side optimization. Saga-forwarding is rejected (send-only; would need new entity columns for `onComplete`).

## Affected code (planned)

| Path | What changes |
| ---- | ------------ |
| `inveniam.io/apps/hub-service/.../transactions/application/providers/ledger-factory.provider.ts` | `getSpecificLedgerByLedgerType` NVNM branch: accept `dealId`, reconstruct scope via the `org + deal` walk, resolve via closest climb; org fallback unchanged. Optional: seed portfolio from `getContextData` when present (send-side) |
| `inveniam.io/apps/hub-service/.../transactions/domain/models/transactions.model.ts` | pass `dealId` into the factory from **both** call sites — `syncDocument` (payload) **and** `onComplete` (`transaction.dealId`, line 136) |
| `inveniam.io/apps/hub-service/.../integration-keys/domain/models/integration-keys.model.ts` | reuse `findClosestByScopeAndLedger` (no change) |
| `inveniam.io/apps/hub-service/.../secure-storage/providers/vault.provider.ts` | Vault `LIST` helper (KV-v2 `metadata`) to reverse-map `portfolio` and the single `dataRoomId` under `Credentials/{org}/…/{deal}/`; requires `list` capability in the hub-service Vault policy |
| tests | walk reconstruct (portfolio + data-room, ledger-enum disambiguation), closest climb + org fallback, **`onComplete` path resolves the scoped key**, optional ambient send-side shortcut |

## Related

- [ADR-0010 Scope-Aware Credentials In Transaction Execution](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md)
- [ADR-0011 NVNM Org-Slot Key Promotion For Sync (Demo)](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)
- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
