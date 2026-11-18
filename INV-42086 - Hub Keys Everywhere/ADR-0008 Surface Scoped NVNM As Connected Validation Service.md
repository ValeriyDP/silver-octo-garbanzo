---
name: ADR-0008 Surface Scoped NVNM As Connected Validation Service
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - adr
  - architecture
---

# ADR-0008 Surface Scoped NVNM As Connected Validation Service

- **Status**: Accepted (implemented)
- **Date**: 2026-08-22
- **Area**: inveniam-v2 UI
- **Deciders**: Valeriy (eng), pairing session
- **Related**: [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md), [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md), `INV-42086`

## Context

After uploading a **scoped NVNM** hub key at the data-room level, nothing in the UI showed NVNM as connected — the data-room title-bar popover still read "1 Connected validation service" (or fewer) with NVNM absent.

The reason: every existing "connected" surface derives from **deal integration settings** (`GET /new-deals/:dealId/integration-settings`), read through `DataroomIntegrationSettingsService.availableLedgers` and fanned out to:

- the title-bar **"Connected validation services" popover** (count + list),
- the **DLT status** badge/filter,
- the file-actions menu **"DLT Management"** visibility,
- the **DLT management modal** rows (`buildDltRows` filters to `availableLedgers`).

A scoped hub key writes to Vault and emits scoped events (ADR-0004); it **never** updates deal integration settings. So the presence of a scoped/inherited NVNM key was invisible everywhere, and — because the modal filters rows to `availableLedgers` — NVNM couldn't even be synced from the modal.

## Decision

Augment the single `availableLedgers` resource so NVNM is appended as a connected ledger when a hub key resolves for the current data-room scope, reusing the **server-side closest-key climb** from ADR-0007 (`GET …/ledger/NVNM/closest`). This keeps one source of truth: every consumer of `availableLedgers` (popover count/list, DLT status, DLT-management visibility, modal rows) picks it up automatically, so what shows as "connected" is exactly what the DLT Sync can use.

Shape of the solution (`DataroomIntegrationSettingsService`):

- `availableLedgers` is now a `resource()` (still a `ResourceRef<AvailableLedgers[] | undefined>`, so the modal's `DltManagementModalData` type and all `.value()` / `.isLoading()` callers are unchanged).
- Loader = deal ledgers (unchanged `extractLedgerTypes` → `filterActiveLedgers`) **plus** an NVNM entry when `hasClosestNvnmKey(scope)` succeeds.
- Scope is assembled from the activated organisation, the deal's root portfolio (`rootPortfolioIdFromDeal`, via `DealsAPIService.getOne`), the deal id, and the data-room id (`dataRoomBase`). Portfolio + data-room ids are required — a scoped key only exists on a **gapless** path (ADR-0003), so no portfolio ⇒ nothing scoped to find.
- The NVNM entry is surfaced with `isValidating: true` → the popover's green **"Connected"** badge (the popover has only Connected/Not-configured states; a resolvable key is what makes NVNM usable here).
- The extra scope dependencies (`OrganisationApiService`, `DealsAPIService`, `DataroomApiManagementService`) are injected `{ optional: true }` so the existing service unit spec (base + http only) still constructs and the deal-only behavior is untouched.

## Alternatives considered

- **Merge only in the popover component** — would fix the count but leave the DLT modal filtering NVNM rows out (sync unreachable) and duplicate logic across the DLT status + file-actions menu. Rejected: fragmented, inconsistent "connected" meaning.
- **Change `availableLedgers` to a plain computed `Signal`** — breaks the `ResourceRef` contract (`.value()` / `.isLoading()` used everywhere, plus the modal's `DltManagementModalData.availableLedgers: ResourceRef`). Rejected: large, mechanical blast radius.
- **Rewrite it as one giant multi-source resource with required deps** — would break the ~40-test service spec and risk SSR fetches. Rejected in favor of optional deps + the SSR-aware `resource` helper from `@inveniam/browser/http`.
- **Only show NVNM for a key set *at this level* (not inherited)** — the `/closest` response carries the matched scope, so this is possible, but "connected = the sync can use a key here" (closest-any, incl. org) matches the Sync semantics and the user's mental model. Left as a follow-up if a "set here vs inherited from org" distinction is wanted.

## Consequences

- **Positive**: A scoped/inherited NVNM key is now visible as a connected validation service across the whole data-room surface from one code path, and NVNM becomes syncable from the DLT modal. Consistent with the DLT Sync's own resolution (ADR-0007). No API/type changes for consumers.
- **Negative / trade-offs**: `availableLedgers` now issues an extra `getOne` + `/closest` request (only when org + data room are known) and re-runs when the org/data-room signals settle. Because closest climbs to org, NVNM shows for **any** data room in an org once an org-level NVNM key exists (accepted: it *is* usable there).
- **Follow-ups / open threads**: If needed, label "set at this data room" vs "inherited from organisation" using the matched-scope ids from `/closest`. Non-NVNM ledgers are unaffected (scoped keys are NVNM-only, ADR-0005).

## Affected code

| Path | What changed |
| ---- | ------------ |
| `packages/browser/features/dataroom/src/lib/services/dataroom-integration-settings.service.ts` | `availableLedgers` rebuilt as `resource()` merging deal ledgers + scoped-NVNM via `/closest`; optional scope deps; `loadDealLedgers` / `resolveScopedNvnmLedger` / `hasClosestNvnmKey` helpers |
| `…/services/dataroom-integration-settings.service.spec.ts` | New sibling `describe` covering NVNM append on resolve, 404, no-data-room, and no-portfolio (gapless) skips |

## Related

- [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
