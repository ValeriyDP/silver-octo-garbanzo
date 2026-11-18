---
name: ADR-0007 Server-Side Closest Hub Key Resolution
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - inveniam-v2
  - scoped-keys
  - architecture
  - adr
---

# ADR-0007 Server-Side Closest Hub Key Resolution

- **Status**: Accepted (implemented)
- **Date**: 2026-08-22
- **Area**: hub-service + inveniam-v2 UI
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md), [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md), [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md), [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)

## Context

Scoped keys can be **written** at portfolio / deal / data-room level (ADR-0002, ADR-0003) but there is no way to **read** the closest one. The DLT **Sync** button (in the data-room DLT management modal → `onTaxonomySyncRequested` → `resolveHubKeyScope` → `getTaxonomyCreateRequest`) needs the scope of the nearest existing key so tokenization uses the right credentials.

Today that resolution is attempted **client-side**: `OrganisationIntegrationSettingsApiService.resolveClosestHubKey` loops from the narrowest scope up to the org, calling `GET /integration-keys/ledger/:ledgerType` with the scope as `searchParams` and treating a `404` as "climb to parent" (`skipAuthErrorHandling`). This is broken and misplaced:

- **It doesn't work** — the backend GET (`readByOrgIdAndLedger`) reads org-from-token + `:ledgerType` only and **ignores** the scope search params (ADR-0002 open thread). So the walk resolves to the org key regardless of scope, or reports a false positive at the narrowest level.
- **Wrong layer** — closest-wins over the org hierarchy is a **domain rule**, not a UI concern. `buildScopedPath` was already designed for it (its comment: "so the closest-key walk can climb from the narrowest level back up to the organisation").
- **Fragile & chatty** — 404-as-control-flow, up to four sequential round trips per click, and it leaks "does a key exist at this exact scope?" to the client.

## Decision

Move the climb into hub-service behind a dedicated read endpoint; the UI makes a single call.

### hub-service — new resolve endpoint

- New route: `GET /integration-keys/ledger/:ledgerType/closest?portfolioId&dealId&dataRoomId` (`organisationId`/`userId` from the org token as usual). Permission `HubKeysView`.
- **NVNM-only.** Guard in the handler body: `if (ledgerType !== HubLedgerTypeEnum.NVNM) throw new BadRequestException(...)`, matching the ADR-0005 controller-body-guard pattern. Scoped keys only exist for NVNM, so climbing only makes sense there; other ledgers keep the plain org read.
- **Climb narrowest → broadest**, returning the first level that has a key:
  1. data room (`org + portfolio + deal + dataRoom`) → `buildScopedPath`
  2. deal (`org + portfolio + deal`) → `buildScopedPath`
  3. portfolio (`org + portfolio`) → `buildScopedPath`
  4. org (`org` only) → **`buildPath`** (the org builder — `buildScopedPath` deliberately rejects org-only, ADR-0003)
  - Start from the **narrowest *defined*** level in the request; the chain is gapless (ADR-0003), so there are no holes.
- Only a genuine **not-found** climbs to the next level; auth/transport errors must **rethrow** (do not swallow as "keep climbing" — the same trap the UI hit with `skipAuthErrorHandling`, now server-side and testable). The vault read's not-found shape must be verified before implementing.
- **Response**: `{ matchedScope, accessKeyStatus, userName }` — the scope where the key was found plus non-secret metadata. **Never** return private key material over this endpoint.
- **`404`** only when no key exists anywhere up to and including org.

### inveniam-v2 — Sync button uses it (for NVNM)

- `resolveHubKeyScope(ledgerType)` branches:
  - `NVNM` → call the new `.../closest` endpoint, use the returned `matchedScope`.
  - otherwise → resolve to `{ organisationId }` (existing org path); never send portfolio/deal/dataRoom.
- Delete the client-side `resolveClosestHubKey` walk and its `skipAuthErrorHandling` 404-probing.
- **Both branches pre-check existence** so the customer gets immediate feedback before the sync fires:
  - NVNM: the `.../closest` `404`.
  - non-NVNM: a single org-level GET `404`.
- On not-found, **reuse the existing failure path** — `notifyTaxonomyCreateRequestFailed(ledgerType, 'Hub keys not found')` routing through the existing `resolveDltSyncFailureToast` / `DLT_MANAGEMENT_TRANSLATIONS` toast. **No new message or i18n entry** is introduced.
- The rest of the Sync flow is unchanged: `matchedScope` still feeds `getTaxonomyCreateRequest`; no new UI screens or router routes.

## Alternatives considered

- **Augment the existing `GET …/ledger/:ledgerType` with scope params + a `resolve=closest` flag** — rejected: overloads the org read's semantics; a dedicated route keeps the org path and the NVNM rule localized.
- **Make resolve ledger-agnostic (one endpoint climbs for all ledgers)** — rejected: scoped keys are NVNM-only (ADR-0005), so non-NVNM has nothing to climb; keeping the climb endpoint NVNM-only keeps the whole scoped feature (write + read) bounded to NVNM and removable as a unit.
- **Server-to-server resolution inside the taxonomy-create path (UI passes no scope)** — deferred: cleaner still, but crosses service boundaries. The `.../closest` endpoint is the pragmatic step and keeps the UI thin. See "two read paths" below.
- **Keep climbing in the UI** — rejected: business rule in the wrong layer, doesn't work against the current backend, fragile 404 control-flow.

## Consequences

- **Positive**: closest-wins lives in the domain; one round trip; no 404-as-control-flow in the client; scoped read/climb stays NVNM-bounded and removable; the Sync button finally works with scoped keys.
- **Trade-offs — two read paths remain**: the UI resolves via `.../closest`, and the tokenization side separately reads the key by the `matchedScope` it was handed. These stay consistent **because the UI is the entry point** and passes an exact scope that resolve just confirmed. If a sync is ever triggered without the UI, the tokenization read would need the same climb — that's the trigger to revisit the deferred server-to-server option.
- **Follow-ups**: verify the vault not-found error shape; this resolves the ADR-0002 open GET thread.

## Affected code (planned)

| Path | What changes |
| ---- | ------------ |
| `inveniam.io/apps/hub-service/.../integration-keys.controller.ts` | + `GET …/ledger/:ledgerType/closest`, NVNM body guard |
| `inveniam.io/apps/hub-service/.../domain/services/integration-keys-query-factory.service.ts` | + `findClosestByScopeAndLedger` |
| `inveniam.io/apps/hub-service/.../domain/queries/*` + `models/integration-keys.model.ts` | climb query/handler; read narrowest→org, catch not-found only |
| `inveniam-v2/packages/shared/inveniam-api/.../ledger/(ledgerType)/**` | + resolve endpoint definition |
| `inveniam-v2/packages/browser/inveniam-api/.../organisation-integration-settings-api.service.ts` | replace `resolveClosestHubKey` walk with single call |
| `inveniam-v2/packages/browser/features/dataroom/.../dataroom-dlt-management-modal.component.ts` | `resolveHubKeyScope` branches NVNM vs org; reuse existing not-found toast |

## Related

- [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md)
- [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)
- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
- [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)
