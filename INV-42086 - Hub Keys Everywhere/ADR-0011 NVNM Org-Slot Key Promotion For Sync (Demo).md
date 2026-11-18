---
name: ADR-0011 NVNM Org-Slot Key Promotion For Sync (Demo)
date: 2026-08-23T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - inveniam-v2
  - scoped-keys
  - vault
  - ledger
  - architecture
  - adr
  - rejected
---

# ADR-0011 NVNM Org-Slot Key Promotion For Sync (Demo)

- **Status**: **Rejected** (2026-08-24) in favour of [ADR-0012 Path Seeker — Reconstruct Scope Then Closest](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md). The org-slot copy was a demo shortcut for a problem ADR-0012 solves cleanly (no shared org slot, no sequential-sync constraint, no org-visibility of scoped keys). Kept for the rationale on why revert/mirror-on-connect were also rejected.
- **Date**: 2026-08-23
- **Area**: hub-service + inveniam-v2 UI
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0010 Scope-Aware Credentials In Transaction Execution](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md), [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md), [ADR-0004 Scoped Hub Key Events](ADR-0004%20Scoped%20Hub%20Key%20Events.md), [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md), [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)

## Context

DLT **Sync** fails for a data-room-scoped NVNM key with `HubDocumentSyncingFailedEvent reason: "Hub credentials were not found"`. Root cause (fully diagnosed in [ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md)): the transaction executor reads signing credentials **org-only** —

```ts
// hub-service .../transactions/application/providers/ledger-factory.provider.ts
await secureStorageProvider.getHubCredentials(ledgerType, organisationId);
```

— and the scoped key lives at `…/{org}/{portfolio}/{deal}/{dataRoom}/NVNM/testnet`, so org 404s. The same org read happens **twice**: once at send (`TransactionsModel.syncDocument`) and again in the async webhook (`onComplete` → `getSpecificLedgerByLedgerType` → `getHubCredentials(org)`) that decodes the `registryId`.

[ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md) is the durable fix (thread scope through the sync/register events; read the scoped key directly on the send side). But this is a **demo** feature that should stay small and avoid a coordinated change across `@inveniam/events` + data-room-service + deals-service + hub-service. We want the shortest path that makes scoped NVNM keys actually sign.

Key facts that shape the shortcut:

- The send path only knows the **org** scope; it cannot locate a scoped key without the scope. The scope *is* known to the **UI**, which already calls the ADR-0007 `GET …/ledger/:ledgerType/closest` before each sync (`resolveHubKeyScope` for NVNM) to get `matchedScope`.
- `/closest` deliberately **never returns key material** (ADR-0007), so the key can only be copied **server-side**.
- There will be **many different** scoped NVNM keys (per data room / deal), so a permanent "mirror on connect" that pins one key to the org slot does not work.

## Decision

Add a hub-service operation that **promotes the closest scoped NVNM key into the org slot just before a sync**, so the existing org-only reads (send *and* `onComplete`) find the right key. **No revert** — the next sync overwrites the org slot with its own key; the org slot simply holds "the last key used".

### hub-service — promote endpoint

- New route: `POST /integration-keys/ledger/:ledgerType/promote-to-org?portfolioId&dealId&dataRoomId` (org/user from token, permission `HubKeysView`, or a create/edit permission if we treat it as a write — TBD at implementation).
- **NVNM-only** body guard (matches ADR-0005 / ADR-0007).
- Behaviour: reuse the ADR-0007 climb (`IntegrationKeysModel.findClosestByScopeAndLedger` candidate order: data room → deal → portfolio) to locate the closest scoped key, read its full credentials via `getScopedHubCredentials(matchedScope)`, and **write them to the org path** via `setHubCredentials(ledgerType, credentials, organisationId)`.
- **Raw Vault write, no domain event.** It must **not** emit `HubSetIntegrationKeysCompleteEvent` — that event triggers org-level tokenization bootstrap in deals-service ([ADR-0004](ADR-0004%20Scoped%20Hub%20Key%20Events.md)). Promotion is a credential copy, not a "key was configured" business event.
- Returns the `matchedScope` (same `ClosestHubKeyDTO` shape as `/closest`, no key material). `404` when there is no scoped or org key to promote.
- If the closest match is already the org level, it is a no-op (org slot already holds the key).

### inveniam-v2 — Sync uses promote instead of resolve

- In the DLT-sync path, for NVNM, replace the single `/closest` call in `resolveHubKeyScope` with the `promote-to-org` call (it climbs, copies to org, and returns the same `matchedScope` that feeds `getTaxonomyCreateRequest`). One-line swap of which endpoint the sync path hits.
- Read-only surfaces keep using `/closest`: the ADR-0008 `availableLedgers` "connected validation service" resolution stays a pure read (no promotion side effects on display).
- No new user-facing message/i18n; the existing not-found → `notifyTaxonomyCreateRequestFailed` toast (ADR-0007) still covers "nothing to promote".

## Alternatives considered

- **[ADR-0010] Thread scope through the events, read scoped key directly on send** — the correct long-term fix; deferred here because it spans shared events + three services and this is a demo. This ADR is explicitly the interim; ADR-0010 stays the target.
- **Mirror-on-connect (write scoped key to org whenever a scoped key is saved), no revert** — rejected: with many distinct keys they fight over the single org slot; whichever was connected last wins regardless of which deal you sync.
- **Swap with revert (promote before, restore/delete after)** — rejected as unnecessarily fragile: the org credential is needed again by the async `onComplete` webhook, so a revert must wait for the terminal WS event (`HubDocumentSyncingSucceeded/Failed`) rather than the send returning; a missed event orphans a scoped key at org scope. Overwriting-without-revert removes that timing problem entirely.
- **Piggyback the copy onto the existing `/closest` GET** — rejected: `/closest` is also called on display (ADR-0008), so a GET side effect would promote keys just by viewing; a dedicated POST keeps promotion deterministic and tied to sync.
- **Return the private key from `/closest` and let the UI hand it to sync** — rejected: never move key material through the browser (ADR-0007).

## Consequences

- **Positive**: smallest change that makes scoped NVNM sync work end to end (send + `onComplete`); contained to hub-service (one endpoint) + one UI call; no event-schema or cross-service changes; no fragile async revert; read/display path unchanged.
- **Negative / trade-offs**:
  - **Global org slot / concurrency**: the org NVNM key is a single shared slot. Two overlapping syncs for different keys can clobber each other before the other's `onComplete` runs. **Run syncs sequentially** in the demo. This is the main reason it is demo-only.
  - **Security/semantics**: a scoped key becomes readable at org scope and org-level "connected" surfaces (`GET …/ledger/:ledgerType`) will show NVNM as connected once promoted; the org slot persists the last-used key indefinitely (no revert).
  - **Not a substitute for [ADR-0010]**: production still needs scope-aware execution.
- **Follow-ups**: when moving past the demo, implement [ADR-0010] and remove the promote endpoint + the UI swap; confirm the promotion permission; consider an org-slot cleanup/expiry if the demo lingers.

## Affected code (planned)

| Path | What changes |
| ---- | ------------ |
| `inveniam.io/apps/hub-service/.../integration-keys/integration-keys.controller.ts` | + `POST …/ledger/:ledgerType/promote-to-org`, NVNM body guard |
| `inveniam.io/apps/hub-service/.../domain/models/integration-keys.model.ts` | + `promoteClosestScopedKeyToOrg` (reuse climb; `getScopedHubCredentials` → `setHubCredentials(org)`; no `apply()`/event) |
| `inveniam.io/apps/hub-service/.../domain/services/*` + `commands/*` | wire promotion (command factory + command handler, or a query-style handler — no domain event either way) |
| `inveniam-v2/packages/shared/inveniam-api/.../ledger/(ledgerType)/**` | + promote endpoint definition |
| `inveniam-v2/packages/browser/.../organisation-integration-settings-api.service.ts` | sync path calls promote instead of `/closest` |
| `inveniam-v2/packages/browser/features/dataroom/.../dataroom-dlt-management-modal.component.ts` | `resolveHubKeyScope` (NVNM) uses promote result |

## Related

- [ADR-0010 Scope-Aware Credentials In Transaction Execution](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0004 Scoped Hub Key Events](ADR-0004%20Scoped%20Hub%20Key%20Events.md)
- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)
- [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)
