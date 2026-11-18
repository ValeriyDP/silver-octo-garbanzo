---
name: ADR-0010 Scope-Aware Credentials In Transaction Execution
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - deals-service
  - data-room-service
  - scoped-keys
  - vault
  - ledger
  - architecture
  - adr
  - rejected
---

# ADR-0010 Scope-Aware Credentials In Transaction Execution

- **Status**: **Rejected** (2026-08-24) in favour of [ADR-0012 Path Seeker — Reconstruct Scope Then Closest](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md). The cross-service event threading is unnecessary — ADR-0012 shows the scope is recoverable inside hub-service (portfolio from ambient request-context, data room from the `UQ__deal_id` 1:1), achieving the same scope-aware-send goal in one file. Kept for the diagnosis and rationale.
- **Date**: 2026-08-22
- **Area**: hub-service + data-room-service + deals-service + events
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0011 NVNM Org-Slot Key Promotion For Sync (Demo)](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md), [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md), [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md), [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md), [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

> **Note (2026-08-24)**: **Rejected.** Superseded by [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md), which reaches the same "scoped key signs the transaction" outcome **without** touching `@inveniam/events` or data-room/deals-service — the scope is already available to hub-service via the ambient request-context (see ADR-0012 Fact 3). The earlier interim ([ADR-0011](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md)) is likewise rejected. This ADR is retained only for its root-cause diagnosis (the two-Vault-reads finding).

## Context

With a scoped NVNM key connected at the **data-room** level and a `registryId` set (deal symbol), DLT **Sync** still fails:

```
HubDocumentSyncingFailedEvent  reason: "Hub credentials were not found"  transactionType: Sync-Document
```

Live logs of a single sync show **two different Vault reads** in the same request:

| Step | Method | Vault path | Result |
| ---- | ------ | ---------- | ------ |
| UI resolve / display (ADR-0007) | `getScopedHubCredentials` | `hub/data/Credentials/{org}/{portfolio}/{deal}/{dataRoom}/NVNM/testnet` | **200** |
| Transaction send | `getHubCredentials` | `hub/data/Credentials/{org}/NVNM/testnet` (**org-only**) | **404 → "Hub credentials were not found"** |

Root cause: the transaction executor fetches signing credentials **org-only**, ignoring scope:

```ts
// inveniam.io/apps/hub-service/src/transactions/application/providers/ledger-factory.provider.ts
const { hubKey, hubPrivate, accessKey } =
  await secureStorageProvider.getHubCredentials(ledgerType, organisationId);
```

ADR-0007 made the **read/resolve** scope-aware for the UI, but the **send** path was left on the org key. ADR-0007's "two read paths" trade-off named exactly this: *"the tokenization side separately reads the key by the `matchedScope`… if a sync is ever triggered without the UI, the tokenization read would need the same climb."* In fact the send path never consumes `matchedScope` at all — it always reads org-level — so **any** scoped-only NVNM key can resolve and display but can never sign a transaction. This ADR is the trigger to implement the deferred server-side resolution.

### Why it can't be fixed in `ledger-factory` alone

The climb needs a **gapless** scope (`org → portfolio → deal → dataRoom`) — `buildScopedPath` rejects gaps and requires at least `org + portfolio` (ADR-0003). But the request that reaches the executor carries almost none of it:

- `HubDocumentSyncingRequestedEventPayload` = `BaseHubInterface + DLTRequestInterface + { symbol, organisationId }` → only `dealId` + `organisationId` (no `portfolioId`, no `dataRoomId`).
- The saga forwards **only `payload`** to the command (`new SyncDocumentCommand(payload)`), so `EventContext` ids don't reach the executor either.

With today's payload the executor cannot build a single scoped candidate — so scope must be **threaded end-to-end**.

## Decision

Make the transaction-execution credential lookup **scope-aware for NVNM**, using the same closest-climb rule as ADR-0007 but on the **send** side, and thread the scope through the events that reach it. **NVNM-only**; every other ledger and flow keeps the existing org-only `getHubCredentials`.

### 1. Events (`@inveniam/events`)

Add optional scope to the requested-event payloads so the executor can climb:

- `HubDocumentSyncingRequestedEventPayload` → `+ portfolioId?: string; dataRoomId?: string;`
- `HubSymbolRegisteringRequestedEventPayload` (register path) → same optional scope.

Optional keeps non-NVNM emitters and older messages valid; the executor treats missing scope as "org-only".

### 2. data-room-service — emit scope (Sync)

`data-room/taxonomy/domain/entity.ts` `requestLedgerSync` builds `HubDocumentSyncingRequestedEvent`. Populate:

- `dataRoomId` = the file's `roomId` (available in `taxonomy-functional.service` as `room.entity.id` / `file.entity.roomId`).
- `portfolioId` = the request context portfolio (`CONTEXT_TYPE.PORTFOLIO_ID`, already read in `request-data-room-file-taxonomy-dlt.command.ts`) — this must be the **root** portfolio that the key was written under (matches ADR-0007's `resolveHubKeyScope`).

Thread both into `requestLedgerSync(...)` and include them in the emitted payload.

### 3. deals-service — emit scope (Register)

`integration-settings/.../event-factory-providers/Hub/hub-events-factory.ts` builds `HubSymbolRegisteringRequestedEvent`; add `portfolioId` + `dataRoomId` from the register command's scope so a first-time NVNM registration also signs with the scoped key.

### 4. hub-service — closest-climb on the send side

In `ledger-factory.provider.ts`, add an **optional** `scopedPath?: ScopedPath` to `getSpecificLedgerByLedgerType(...)` and replace the direct `getHubCredentials` call with a resolver:

```
resolveClosestHubCredentials(provider, ledgerType, organisationId, scopedPath?):
  if not NVNM or scopedPath is absent/insufficient → getHubCredentials(org)   // unchanged
  for scope in candidates(org, portfolio, deal, dataRoom):   // narrowest → broadest, gapless prefixes, length ≥ 2
      try: return getScopedHubCredentials(ledgerType, scope)
      catch NotFoundException: continue      // climb
      // any other error → rethrow (no 404-as-control-flow, ADR-0007)
  return getHubCredentials(ledgerType, org)  // org last; throws NotFound only if nothing exists anywhere
```

- Candidate order mirrors ADR-0007's read climb: `dataRoom → deal → portfolio → org`.
- Only `NotFoundException` climbs; auth/transport errors rethrow immediately.
- Thread `scopedPath` only from `TransactionsModel.syncDocument` and `registerSymbol` (both already receive the scoped payload); the ~13 other callers keep passing org only and get today's behaviour.

## Alternatives considered

- **Fix `ledger-factory` only (no event changes)** — impossible: the payload lacks `portfolioId`/`dataRoomId`, so no scoped candidate can be built; the climb would degrade to org-only and still 404.
- **hub-service derives the missing scope from `dealId`** (call deals/data-room service to look up portfolio + room in the transaction path) — rejected: adds synchronous cross-service calls and coupling on the hot send path; the emitters already hold the ids.
- **Copy the scoped key up to the org path** (or require an org-level NVNM key) — rejected as the design: defeats the purpose of scoped keys. It remains a valid **manual unblock** for a single environment, not a fix.
- **Return the private key from `/closest` and have the UI pass it to sync** — rejected: never move key material through the browser (ADR-0007 forbids it).

## Consequences

- **Positive**: scoped NVNM keys can actually **sign** Sync (and Register) transactions; closest-wins is consistent across read (ADR-0007) and send; the deferred "server-to-server" thread from ADR-0007 is closed; blast radius stays NVNM-only and the whole scoped feature remains removable as a unit.
- **Negative / trade-offs**: touches a shared event schema plus three services; requires coordinated deploy (emitters + consumer). Optional fields make it backward-tolerant, but a stale hub-service would ignore new scope and still 404 — so **deploy hub-service first**, then the emitters.
- **Follow-ups**: confirm the root-portfolio id the emitter provides equals the one used at write time in all cases (link/child-portfolio edge cases); add a targeted test that a data-room-only NVNM key signs a sync.

## Affected code (planned)

| Path | What changes |
| ---- | ------------ |
| `inveniam.io/shared-modules/Events/Hub/interfaces.ts` | `+ portfolioId?`, `dataRoomId?` on syncing + register-symbol requested payloads |
| `inveniam.io/apps/data-room-service/.../taxonomy/domain/entity.ts` | `requestLedgerSync` emits `portfolioId` + `dataRoomId` |
| `inveniam.io/apps/data-room-service/.../taxonomy/domain/services/taxonomy-functional.service.ts` | pass `roomId` + portfolio into `requestLedgerSync` |
| `inveniam.io/apps/deals-service/.../event-factory-providers/Hub/hub-events-factory.ts` | register event carries scope (Register path) |
| `inveniam.io/apps/hub-service/.../transactions/application/providers/ledger-factory.provider.ts` | `+ scopedPath?`, `resolveClosestHubCredentials` (NVNM climb, org fallback) |
| `inveniam.io/apps/hub-service/.../transactions/domain/models/transactions.model.ts` | `syncDocument` / `registerSymbol` pass scope into the factory |
| tests | factory resolver (climb + org fallback + rethrow); entity emission |

## Related

- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)
- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
