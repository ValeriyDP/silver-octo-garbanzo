---
name: ADR-0003 Gapless Scoped Vault Path And Command Wiring
date: 2026-08-21T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - scoped-keys
  - vault
  - architecture
  - adr
---

# ADR-0003 Gapless Scoped Vault Path And Command Wiring

- **Status**: Accepted
- **Date**: 2026-08-21
- **Area**: hub-service
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md), [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md), [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)

## Context

[ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md) added the per-level POST routes and DTOs but left the sub-org handlers as echo stubs. This ADR covers making the **write path actually store keys in Vault at the right scope**, plus the naming/wiring decisions taken to get there.

Vault credentials were previously stored per organisation via `buildHubCredentialsPath` (`…/Credentials/{org}/{ledger}/{network}`). Scoped keys need a path that nests the hierarchy (`organisation → portfolio → deal → dataRoom`) so the eventual closest-key read walk can climb it. The scope object (`ScopedPath`) carries four optional ids, which means a caller could in principle pass a **discontiguous** scope (e.g. `{ organisationId, dataRoomId }`) that no gapless walk can resolve.

## Decision

### 1. One scoped command path, not three

- Command factory exposes a single `setScopedIntegrationKeys(keys: ISetScopedIntegrationKeys)` alongside the untouched org-only `setIntegrationKeys`. Chosen over three per-level methods (`setPortfolio/Deal/DataRoomIntegrationKeys`) to keep the domain thin; the required-vs-optional scope constraint is enforced in the per-level DTOs instead of the method type.
- `ISetScopedIntegrationKeys extends ISetIntegrationKeys` adding optional `portfolioId` / `dealId` / `dataRoomId` (`domain/interfaces.ts`).
- Controller handlers keep their names (`createPortfolioKeys`, `createDealKeys`, `createDataRoomKeys`); each builds the scope and delegates to `setScopedIntegrationKeys`.
- New `SetScopedIntegrationKeysCommand` + `SetScopedIntegrationKeysCommandHandler` → `IntegrationKeysModel.setScopedIntegrationKeys` → `VaultProvider.setScopedHubCredentials`.

### 2. Gapless scoped path builder (`buildScopedPath`)

`apps/hub-service/src/secure-storage/providers/vault.provider.ts`

The builder validates the scope is a **gapless prefix** of `organisation → portfolio → deal → dataRoom` and rejects **org-only** (that has its own dedicated non-scoped endpoint/path). Expressed functionally with lodash `takeWhile`:

```ts
const levels = [organisationId, portfolioId, dealId, dataRoomId];
const definedPrefix = takeWhile(levels, Boolean);   // leading contiguous defined ids
const definedCount = levels.filter(Boolean).length; // total defined ids

if (definedPrefix.length !== definedCount) throw …; // a defined id sits past a gap
if (definedPrefix.length < 2) throw …;              // org-only → use the org endpoint

return [kv, 'data', entity, ...definedPrefix, ledgerType, networkType].join('/');
```

- **Gap detection is an equation**: if the contiguous leading run is shorter than the total count of defined ids, something was defined after a hole → reject. No index math.
- `definedPrefix` doubles as the path segments, so validation and construction can't drift.
- **Segment order**: scope chain first, then `ledgerType`/`networkType` — i.e. `…/Credentials/{org}/{portfolio}/{deal}/{dataRoom}/{ledger}/{network}`.

### 3. Wiring correctness (found via a dry trace)

- Registered `SetScopedIntegrationKeysCommandHandler` in `commands/index.ts` — without it the command had no bound handler and would fail at runtime.
- Renamed the scoped handler class (it had been copy-pasted as `SetIntegrationKeysCommandHandler`, colliding with the org handler once both are imported).
- Typed `SetScopedIntegrationKeysCommand.payload` as `ISetScopedIntegrationKeys` (was `ISetIntegrationKeys`), so scope ids are typed factory → command → model.

## Alternatives considered

- **Naive `buildScopedPath` (filter + join)** — rejected: silently drops gaps and would let `{org, dataRoom}` build a path skipping portfolio/deal, corrupting the resolution walk.
- **Imperative gap check (`findIndex` + `slice` + `some`)** — worked, but the `takeWhile` form states the "gapless prefix" intent directly and reuses the result as segments.
- **Three explicit command-factory methods / per-level commands** — rejected as boilerplate; the DTO layer already enforces per-level required ids.
- **Allow org-only through the scoped builder** — rejected: org keys have a dedicated non-scoped endpoint (`setHubCredentials` / `buildHubCredentialsPath`); reaching the scoped builder with only an org id signals misuse.

## Consequences

- **Positive**: sub-org keys are stored at a correctly nested Vault path; discontiguous/org-only scopes are rejected at the builder; the write chain is fully wired and typed end-to-end.
- **Trade-offs / accepted**:
  - The builder's `UnprocessableEntityException`s are effectively **defense-in-depth for HTTP callers**: the per-level DTOs already forbid gaps, and `IntegrationKeysModel.setScopedIntegrationKeys` **swallows errors** (applies a `Failed` event + logs, no rethrow). The guards still matter for **non-HTTP callers** of the builder.
  - Write is **fire-and-forget** (`202 Accepted`): reused `HubSetIntegrationKeysComplete/FailedEvent` carry no scope ids. Clients learn the outcome by **re-reading the item (GET)** or **waiting for a websocket** event — accepted.
- **Follow-ups / open threads**: read-side closest-key resolution still not aligned (see [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md) open thread); scope ids are not yet propagated on the complete/failed events.

## Affected code

| Path | What changed |
| ---- | ------------ |
| `secure-storage/providers/vault.provider.ts` | `buildScopedPath` gapless + org-only validation (FP `takeWhile`); reads `scopedPath` and nests segments |
| `integration-keys/domain/interfaces.ts` | `ISetScopedIntegrationKeys` (adds optional `portfolioId`/`dealId`/`dataRoomId`) |
| `integration-keys/domain/commands/set-scoped-integration-keys.command.ts` | command payload typed `ISetScopedIntegrationKeys`; handler renamed `SetScopedIntegrationKeysCommandHandler` |
| `integration-keys/domain/commands/index.ts` | registered `SetScopedIntegrationKeysCommandHandler` |
| `integration-keys/domain/services/integration-keys-command-factory.service.ts` | `setScopedIntegrationKeys()` |
| `integration-keys/domain/models/integration-keys.model.ts` | `setScopedIntegrationKeys()` → `setScopedHubCredentials()` |
| `integration-keys/integration-keys.controller.ts` | `create{Portfolio,Deal,DataRoom}Keys` delegate to `setScopedIntegrationKeys` |

## Related

- [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md)
- [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md)
- [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)
