---
name: ADR-0002 Per-Level Hub Key Endpoints
date: 2026-08-21T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - inveniam-v2
  - scoped-keys
  - architecture
  - adr
---

# ADR-0002 Per-Level Hub Key Endpoints

- **Status**: Accepted
- **Date**: 2026-08-21
- **Area**: hub-service + inveniam-v2 UI
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md), [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

## Context

[ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md) shipped the v2 side by POSTing a single body (`HubKeyJson`) — carrying `organisationId` plus optional `portfolioId`/`dealId`/`dataRoomId` — to one endpoint `POST /hub/integration-keys/ledger/:ledgerType`.

The backend then took a different shape: instead of one endpoint that accepts a fuzzy scope, `hub-service` now exposes **one endpoint per scope level**, derives `organisationId` and `userId` from the org token, and requires the scope ids **in the body**. v2 had to be aligned to that contract (backend was not to be changed in this pass).

## Decision

### Backend contract (hub-service — reference, not changed by v2)

`apps/hub-service/src/integration-keys/integration-keys.controller.ts` adds three routes alongside the existing org route. Org + user come from the token (`@OrgId()`, `@UserId()`); scope ids are validated body fields.

| Route (POST) | Body DTO | Body fields |
| --- | --- | --- |
| `…/ledger/:ledgerType` | `SetIntegrationKeysDTO` | `hubKey`, `hubPrivate`, `userName` |
| `…/:ledgerType/portfolio` | `SetPortfolioIntegrationKeysDTO` | + `portfolioId` |
| `…/:ledgerType/deal` | `SetDealIntegrationKeysDTO` | + `portfolioId`, `dealId` |
| `…/:ledgerType/data-room` | `SetDataRoomIntegrationKeysDTO` | + `portfolioId`, `dealId`, `dataRoomId` |

DTO files: `set-integration-keys-porfolio.dto.ts` (sic — typo in filename/class prefix stays as `Portfolio`), `set-integration-keys-deal.dto.ts`, `set-integration-keys-data-room.dto.ts`. Each `Omit`s `organisationId`/`ledgerType`/`userId` and adds its scope id; `hubKey` is validated as a UUID, `hubPrivate` against a PEM regex, `userName` is required.

Note: at time of writing the three new handlers are **stubs** that echo the body back — DTO validation is live, command wiring is not yet.

### v2 alignment

- **DTOs** — `inveniam-v2/packages/shared/dto/src/lib/v1/hub/hub-ledger.ts`: replaced `HubKeyJson` with request types that mirror the backend and **omit `organisationId`**:
  `HubKeyCredentials` (`hubKey`, `hubPrivate`, `userName`), `SetOrgHubKeyRequest`, `SetPortfolioHubKeyRequest` (+`portfolioId`), `SetDealHubKeyRequest` (+`dealId`), `SetDataRoomHubKeyRequest` (+`dataRoomId`), and a `SetHubKeyRequest` union. `HubKeyScope` and the helpers (`isOrgOnlyHubKeyScope`, `parentHubKeyScope`, `rootPortfolioIdFromDeal`) are unchanged.
- **Endpoints** — `packages/shared/inveniam-api/src/lib/v1/hub/integration-keys/ledger/(ledgerType)/index.ts`: added `uploadPortfolioHubLedgerProfile`, `uploadDealHubLedgerProfile`, `uploadDataRoomHubLedgerProfile`, and retyped `uploadHubLedgerProfile` to `SetOrgHubKeyRequest`.
- **Service** — `packages/browser/inveniam-api/src/lib/services/organisation-integration-settings-api.service.ts`: `hubKey(ledgerType, scope, credentials)` now **routes by scope depth** and sends `{ hubKey, hubPrivate, userName }` plus only the relevant scope ids (no `organisationId`). Depth is resolved with destructuring narrowing (`portfolioId`/`dealId`/`dataRoomId`), avoiding non-null assertions (repo enforces `@typescript-eslint/no-non-null-assertion`).
- **Modal** — `packages/browser/features/hub-integration-settings/src/lib/modals/add-ledger-via-hubkey-modal/add-ledger-via-hubkey-modal.component.ts`: calls `hubKey(ledger.id, scope, { hubKey, hubPrivate })`; dropped the `HubKeyJson` body assembly and import. Org-only `patch({ appType: 'tokenization' })` behaviour is unchanged (still gated by `isOrgOnlyHubKeyScope`).
- **Tests** — service spec now mocks the three new endpoints and asserts each scope hits its own endpoint with the right body and no `organisationId`; modal spec still valid (it asserts the `scope` argument, which still carries `organisationId`).

## Alternatives considered

- **Keep the single fuzzy endpoint and let the backend branch on which ids are present** — rejected: backend already committed to per-level routes with strict per-level DTO validation; v2 must match the wire contract.
- **Send `organisationId` in the body anyway** — rejected: backend derives it from the token and the SET DTOs `Omit` it; sending it is at best ignored, at worst a whitelist-validation rejection.

## Consequences

- **Positive**: v2 request bodies now exactly match the backend DTOs; each level is strongly typed; no `organisationId` leaks into bodies.
- **Trade-offs**: four endpoint definitions and a small routing branch in the service instead of one call.
- **Open thread (GET not aligned)**: `getHubIntegrationKeysByLedger` still sends `searchParams: HubKeyScope`, and `resolveClosestHubKey` still walks parents on 404. But the backend GET (`readByOrgIdAndLedger`) reads org-from-token + `:ledgerType` only and **ignores search params**, so the closest-key walk currently resolves to the org key regardless of scope. Aligning read-side resolution needs a matching backend GET change — **resolved by [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)** (dedicated NVNM-only `.../closest` endpoint that climbs server-side).

## Affected code

| Path | What changed |
| ---- | ------------ |
| `inveniam.io/apps/hub-service/.../integration-keys.controller.ts` | +3 per-level POST routes (backend; reference) |
| `inveniam.io/apps/hub-service/.../dto/set-integration-keys-{porfolio,deal,data-room}.dto.ts` | new per-level request DTOs (backend; reference) |
| `inveniam-v2/packages/shared/dto/.../hub/hub-ledger.ts` | request DTOs replacing `HubKeyJson`; no `organisationId` |
| `inveniam-v2/packages/shared/inveniam-api/.../ledger/(ledgerType)/index.ts` | +3 upload endpoints; retyped base |
| `inveniam-v2/packages/browser/inveniam-api/.../organisation-integration-settings-api.service.ts` | `hubKey()` routes by scope depth |
| `inveniam-v2/packages/browser/features/hub-integration-settings/.../add-ledger-via-hubkey-modal.component.ts` | new `hubKey()` call signature |
| `*.spec.ts` (service) | per-endpoint routing assertions |

## Related

- [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
