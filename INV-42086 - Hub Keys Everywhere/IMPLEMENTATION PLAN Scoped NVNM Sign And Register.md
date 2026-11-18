---
name: IMPLEMENTATION PLAN Scoped NVNM Sign And Register
date: 2026-08-24T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - inveniam-v2
  - scoped-keys
  - vault
  - ledger
  - architecture
  - index
---

# IMPLEMENTATION PLAN — Scoped NVNM Sign & Register

A step-by-step, adjustable path to make **scoped NVNM keys actually work end to end**: register a deal's anchoring symbol and sign DLT-sync transactions with the closest scoped key. This is a **planning runbook**, not a decision record — the "why" lives in the ADRs; this is the "how/where", ordered, with verify + rollback per step so you can adjust and hand-implement.

> **Implementation status (2026-08-24)**: **Phases A + B + C implemented.** A/B in `hub-service` (`deal_scope` + Path Seeker signing). C in `deals-service` (NVNM create-if-missing) + `inveniam-v2` (Register symbol in the DLT modal). **Deferred**: the ADR-0012 Vault-walk fallback (a projection miss degrades to org-level) and relocation upkeep (A4). Sequence: [NVNM Register And Sign Final Flow](NVNM%20Register%20And%20Sign%20Final%20Flow.md).

**Accepted design** (see register): [ADR-0009](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md) (register symbol) + [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md) (reconstruct-then-closest; walk = fallback) + [ADR-0013](ADR-0013%20Local%20Deal%20To%20Portfolio%20Projection%20For%20Scope%20Resolution.md) (local `deal → portfolio` projection = primary). **Rejected**: [ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md), [ADR-0011](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md). Everything is **NVNM-only** and confined to `hub-service` + `inveniam-v2`.

## Why this order

Registration (`Register` → `addRegistry`) is **itself a hub transaction** that signs through the same `ledger-factory` credential lookup as sync. So **scope-aware signing must land first**, otherwise even "register symbol" 404s for a scoped-only key. Hence:

1. **Phase A — Projection** (ADR-0013): give hub-service a `deal → portfolio` lookup.
2. **Phase B — Scope-aware signing** (ADR-0012): resolve the closest scoped key in `ledger-factory` (projection → walk → closest), for sync + register + onComplete.
3. **Phase C — In-app register** (ADR-0009): UI to create the deal's registry (now that register can sign).

Phase B is the load-bearing fix. A/B together make sync work for an already-registered deal; C removes the manual DB step for registration.

> Single choke point for signing: `TransactionsModel.getSpecificLedgerByLedgerType` (`transactions.model.ts:1183`) → `LedgerFactoryProvider.getSpecificLedgerByLedgerType` (`ledger-factory.provider.ts:35`), which fetches creds eagerly at `ledger-factory.provider.ts:48`. NVNM callers to make scope-aware: `syncDocument` (`:467`), `registerSymbol` (`:418`), `onComplete` (`:136`). ~25 other callers stay org-only.

---

## Phase A — New `deal_scope` projection table (ADR-0013)

**Goal:** `DealScopeRepository.get(dealId)` returns `{ portfolioId, parentPortfolioIds }`. **Do not extend the existing `deals` entity** — a dedicated table keeps scope resolution self-contained and removable (see ADR-0013 "Why a separate table").

- [x] **A1. New entity + migration.** `inveniam-data/domain/entities/deal-scope.entity.ts` (`DealScopeEntity`; SnakeNamingStrategy → `deal_id` PK, `portfolio_id`, `parent_portfolio_ids`) + migration `src/migrations/1756032000000-add-deal-scope-table.ts` (glob-loaded, `migrationsRun: true`).
- [x] **A2. Model + DTO + command.** `deal-scope.model.ts` (`save()` + `rootPortfolioId(organisationId)`, mirroring the UI `rootPortfolioIdFromDeal`), `DealScopeDTO` in `infrastructure/interfaces.ts`, `save-deal-scope.command.ts` (handler upserts by PK).
- [x] **A3. Populate on create/update.** `application/sagas/deal-scope.sagas.ts` maps `DealCreatedEvent`/`DealUpdatedEvent` → `SaveDealScopeCommand({ dealId: payload.id, portfolioId, parentPortfolioIds })`.
- [ ] **A4. Keep fresh on move — OUT OF SCOPE (PoC).** Relocation handling (deal moved across portfolios, or portfolio/deal re-rooted) is **not** implemented; the projection is assumed stable. Noted for the durable solution: add a saga on the relocation event (`DataRoomDealMovedEvent` vs IAM `deal-resource-moved`) → `SaveDealScopeCommand`, choosing the event that matches the write-time (root) portfolio. Until then a moved deal degrades to org-level.
- [x] **A5. Repository + wiring.** `infrastructure/repositories/deal-scope.repository.ts`; `initDealScopeModel` on the factory; `DealScopeRepository` registered + exported in `inveniam-data.module.ts`; barrels updated. Tests: model, saga, command, factory (all green).
- [ ] **A6. Backfill (optional).** One-time script to fill `deal_scope` for deals created before this table existed — **not done**; such deals currently degrade to org-level.

**Verify:** create a deal, move it; confirm the `deal_scope` row shows the correct `portfolio_id`/`parent_portfolio_ids`. Existing `deals` cache untouched.
**Rollback:** drop the `deal_scope` table, saga, command, repository, and module registration — a fully isolated removal with no impact on the `deals` cache.

---

## Phase B — Scope-aware signing in `ledger-factory` (ADR-0012)

**Goal:** for NVNM, sign with the **closest** scoped key; resolve portfolio via projection (primary) → Vault walk (fallback); reuse ADR-0007 closest. Fixes sync **and** register **and** onComplete.

- [x] **B1. Thread `dealId` to the choke point.** Added optional `dealId?` to `TransactionsModel.getSpecificLedgerByLedgerType` (`:1183`) and `LedgerFactoryProvider.getSpecificLedgerByLedgerType` (`:35`). Passed from the 3 NVNM callers: `syncDocument` (`payload.dealId`), `registerSymbol` (`payload.dealId`), `onComplete` (`transaction.dealId`). Other ~25 callers unchanged; smart-account wrapper path unchanged.
- [x] **B2. Resolver.** `ledger-factory.provider.ts` now calls `resolveHubCredentials(...)` instead of the direct org lookup:
  - `ledgerType !== NVNM` or no `dealId` → `getHubCredentials(org)` (unchanged behaviour);
  - else `portfolio = initDealScopeModel(dealId).rootPortfolioId(org)` — **primary**;
  - gapless candidates narrowest→broadest `{org,portfolio,deal}`, `{org,portfolio}` → climb via `getScopedHubCredentials` (only `NotFoundException` climbs; others rethrow);
  - org fallback via `getHubCredentials(org)` (no data-room rung — redundant per ADR-0012).
- [ ] **B2-walk. Vault-walk fallback — DEFERRED.** The ADR-0012 `LIST Credentials/{org}/*/{deal}/` fallback on a projection miss is **not implemented**; a miss degrades to org-level. (Needs a Vault `list` policy — B4.)
- [x] **B3. Smart-account path.** Confirmed `getSpecificLedgerBySmartAccount` does **not** fetch Hub credentials (uses the smart-account config), so it never 404s on scoped keys — no change needed; NVNM sync uses the standard path.
- [ ] **B4. Vault `list` policy (fallback only) — DEFERRED.** Only needed if/when the walk fallback (B2-walk) is implemented.

**Verify:** with a data-room-scoped NVNM key and **no** org key, a DLT sync signs (no more `"Hub credentials were not found"`); confirm both the send and the `onComplete` webhook resolve. Temp `logger.info` the resolved `matchedScope` for one run.
**Rollback:** `dealId` is optional and the resolver falls through to `getHubCredentials(org)`, so reverting = stop passing `dealId` (behaviour returns to org-only).

---

## Phase C — In-app "Register symbol" for NVNM (ADR-0009)

**Goal:** one-click registration in `inveniam-v2` so a connected-but-unregistered deal creates its anchoring registry (no DB surgery). Depends on Phase B (register signs with the scoped key).

- [x] **C1. Create-if-missing (deals-service).** Make `symbolRegister` create the NVNM `data-validation` deal setting when absent (today it crashes on `appConfig.appType` because scoped Add-Hub-Key writes only Vault, so no row exists). Keep it NVNM-guarded.
- [x] **C2. No form.** Confirm the register encoder hardcodes name/description = `dealId`, empty metadata (one-click; no user input).
- [x] **C3. UI action.** Add an NVNM-only **"Register symbol"** state in the DLT surface: when `config.symbol` is empty, show "Register symbol" instead of "Sync". Wire it to `PATCH /new-deals/:dealId/register-symbol`.
- [x] **C4. Wait via webhook.** After triggering, the UI reloads deal integration settings until `config.symbol` appears (the backend chain `Register` → hub `addRegistry` → `POST /hub/transactions/on-complete` → `HubSymbolRegisteringSucceededEvent` → deals saga writes `config.symbol`), then enables "Sync". Immediate Hub write failures skip `on-complete` and emit `HubSymbolRegisteringFailedEvent` instead.

**Verify:** on a fresh NVNM-connected deal, click Register → wait → `symbol` populates in both the write table and `vm_deal_integration_settings` → Sync becomes available and succeeds.
**Rollback:** feature-flag or hide the Register button; the manual DB path (see [HOW-TO](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)) remains the fallback.

---

## Out of scope (PoC)

- **Deal / portfolio relocation** — a deal moving across portfolios, or a portfolio/deal re-rooted under a different root, is **not** handled. The `deal_scope` projection is populated at create/update and assumed stable. To be considered for the durable solution (relocation saga, per A4); until then a moved deal degrades to the Phase B walk fallback → org.

## Cross-cutting

- **Tests.** A: projection persist (create/update/move) + root derivation. B: resolver projection-hit / walk-fallback / org-last / rethrow, and the `onComplete` path resolves the scoped key. C: create-if-missing, register→wait→sync happy path.
- **Deploy order.** A → B → C. A and B are backend-only (hub-service); ship + verify before the C UI. No shared-event or cross-service schema changes (that's the whole point vs rejected ADR-0010).
- **NVNM-only guardrails.** Every branch added must no-op for non-NVNM ledgers (matches ADR-0005/0007).
- **Keep docs live.** Update each ADR's status to `Accepted (implemented)` and append to [log](Hub%20Keys%20Everywhere%20(INV-42086)/log.md) as phases land; refresh the [HOW-TO](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md) as nuances surface.

## Minimal path (if you only need one deal working now)

The `deal_scope` table + resolver (Phase A + B) makes an **already-registered** deal sync; you can even seed a single `deal_scope` row by hand for the demo deal instead of the full saga wiring. Registration for that one deal can stay the manual `vm_deal_integration_settings` insert (HOW-TO) until Phase C ships.

## Related

- [ADR-0009 In-App NVNM Register Symbol Flow](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md)
- [ADR-0012 Path Seeker Reconstruct Scope Then Closest](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md)
- [ADR-0013 Local Deal To Portfolio Projection For Scope Resolution](ADR-0013%20Local%20Deal%20To%20Portfolio%20Projection%20For%20Scope%20Resolution.md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
