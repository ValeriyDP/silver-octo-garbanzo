---
name: ADR-0001 Scoped Add HUB Key
date: 2026-08-20T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - inveniam-v2
  - scoped-keys
  - architecture
  - adr
---

# ADR-0001 Scoped Add HUB Key

- **Status**: Accepted
- **Date**: 2026-08-20
- **Area**: inveniam-v2 UI (+ Hub integration)
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

## Context

Originally a HUB integration key (the credential that lets Inveniam talk to a blockchain provider via the Hub) could only be added at the **organisation** level, from Org settings → Blockchain → Ledgers. That is too coarse: different portfolios / deals / data rooms can need their own provider credentials, and the org-only key forces everything through a single set of credentials.

We wanted "Add HUB key" to be available **everywhere in the hierarchy** — org, portfolio, deal, data room — while keeping resolution predictable: when an operation needs a key, use the **most specific** key that exists, falling back up the tree.

The scope hierarchy is: `organisation → portfolio → deal → dataRoom`.

## Decision

Introduce a **scope object** that travels through the UI and is sent to the Hub, plus a **closest-key resolution** walk that climbs the hierarchy.

### 1. Scope as a first-class DTO

`packages/shared/dto/src/lib/v1/hub/hub-ledger.ts`

```ts
type HubKeyScope = {
  organisationId: string;
  portfolioId?: string;
  dealId?: string;
  dataRoomId?: string;
};
type HubKeyJson = HubKeyScope & { hubKey; hubPrivate; userName };
```

Helpers:
- `isOrgOnlyHubKeyScope(scope)` — true when only `organisationId` is set.
- `parentHubKeyScope(scope)` — strips the rightmost set id (dataRoom → deal → portfolio → org → `undefined`).
- `rootPortfolioIdFromDeal(deal, organisationId)` — resolves the **root** portfolio for a deal (first non-org ancestor, else the deal's own `portfolioId`), so deal-level keys attach to the root portfolio rather than a nested one.

### 2. Closest-key resolution (client-side walk)

`packages/browser/inveniam-api/src/lib/services/organisation-integration-settings-api.service.ts`

- `hubKey(ledgerType, body)` — uploads the key; sends exactly the scope ids present in `body` plus the session `userName`.
- `resolveClosestHubKey(ledgerType, startScope)` — GETs the key for `scope`; on **404** it strips the rightmost id via `parentHubKeyScope` and retries, until a key is found or the scope is exhausted (returns `undefined`). Non-404 errors propagate.

### 3. Modal + single opener

- `openAddHubKeyModal(modalService, { scope, destroyRef?, onSubmitted? })` (`.../hub-integration-settings/src/lib/open-add-hub-key-modal.ts`) is the one entry API; every call site passes its `scope`.
- `AddLedgerViaHubkeyModalComponent` uploads via `hubKey()` and **only patches the org tokenization/integration setting when the scope is org-only** (`isOrgOnlyHubKeyScope`). Below-org scopes must not mutate org-level settings.

### 4. Entry points (thin, scope-aware)

- **Org settings** — existing button, now sends `{ organisationId }`.
- **Root portfolio menu** — `portfolios-tree.component`; button shown **only for root portfolios**.
- **Deal header** — `deal-header.component`; uses `rootPortfolioIdFromDeal` so the key attaches to the root portfolio.
- **Data room title bar** — `dataroom-title-bar.component`.

### 5. Taxonomy create-request

The data-room DLT "send to Hub" flow (`dataroom-dlt-management-modal`) attaches the **resolved** scope (from `resolveClosestHubKey`) to the taxonomy create-request so tokenization uses the correct key.

## Alternatives considered

- **Server-side closest-key resolution** — cleaner conceptually, but the Hub/deals endpoints already return 404 per-scope, and a client walk shipped without backend changes. Trade-off: N sequential requests worst-case; acceptable given shallow hierarchy (≤4).
- **Reuse org-only patch at every level** — rejected: it would corrupt org-level integration settings when adding a narrower key.

## Consequences

- **Positive**: keys can live at any level; resolution is deterministic (most-specific-wins with fallback); one modal opener keeps call sites thin; org settings are never mutated by sub-org keys.
- **Negative / trade-offs**: closest-key walk is up to 4 sequential GETs on a cold miss; the "root portfolio only" rule needed an explicit carve-out (see below).
- **Product rule — "General" excluded**: the auto-created **General** portfolio node is intentionally **not** treated as a root portfolio, so it shows no "Add HUB key" button (`isRootPortfolio` returns false for `portfolio.id === 'general'`). Nested (non-root) portfolios also don't show it.

## Notable fixes made along the way

- **Lint**: `sort-imports` (alphabetized DTO imports) and `@typescript-eslint/member-ordering` (moved `canManageHubKeys` computed above the constructor).
- **Angular test infra**: `Cannot set and add/remove DecoratorFactory at the same time!` — caused by `overrideComponent` using both `set` and `add` for the same metadata; fixed by putting `schemas: [NO_ERRORS_SCHEMA]` inside the single `set` object.

## Affected code

| Path | What changed |
| ---- | ------------ |
| `packages/shared/dto/.../hub/hub-ledger.ts` | `HubKeyScope`, extended `HubKeyJson`, `isOrgOnlyHubKeyScope`, `parentHubKeyScope`, `rootPortfolioIdFromDeal` |
| `packages/browser/inveniam-api/.../organisation-integration-settings-api.service.ts` | `hubKey()` sends scope ids; `resolveClosestHubKey()` 404-walk |
| `packages/browser/features/hub-integration-settings/.../add-ledger-via-hubkey-modal.component.ts` | scope-through-modal; org-only patch guard |
| `packages/browser/features/hub-integration-settings/.../open-add-hub-key-modal.ts` | single scope-aware modal opener |
| `packages/browser/features/deals/.../portfolios-tree.component.ts` | root-only "Add HUB key"; excludes `general` |
| `packages/browser/features/deals/.../deal-header.component.ts` | deal entry point; root portfolio id |
| `packages/browser/features/dataroom/.../dataroom-title-bar.component.ts` | data-room entry point |
| `packages/browser/features/dataroom/.../dataroom-dlt-management-modal.component.ts` | attaches resolved scope to taxonomy create-request |
| `*.spec.ts` across the above | body ids per level, root-only button, 404 strip-walk, deal→root portfolio |

## Testing notes

Unit tests assert: exact scope ids per level are POSTed (org / portfolio / deal / dataRoom) with session `userName`; the root-portfolio-only button visibility (incl. `general` exclusion); the 404 strip-walk of `resolveClosestHubKey`; deals resolving to the **root** portfolio id.

## Related

- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
