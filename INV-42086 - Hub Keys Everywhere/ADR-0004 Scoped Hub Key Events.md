---
name: ADR-0004 Scoped Hub Key Events
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - scoped-keys
  - events
  - architecture
  - adr
---

# ADR-0004 Scoped Hub Key Events

- **Status**: Accepted
- **Date**: 2026-08-22
- **Area**: hub-service (+ shared Events module, websockets-service)
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md), [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md), [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

## Context

`IntegrationKeysModel.setScopedIntegrationKeys` (see [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)) reused the **org-level** events `HubSetIntegrationKeysCompleteEvent` / `HubSetIntegrationKeysFailedEvent`. Tracing the consumers showed this is wrong:

- **deals-service** subscribes to the Complete event via a saga → `HubSetIntegrationKeysCompleteBootstrapCommand` → `tokenizationBootstrapService.startBootstrapAfterHubKeyUpload({ organisationId, ledgerType, userId })`, i.e. it prepares the **org** ledger for tokenization. A portfolio/deal/data-room upload would wrongly trigger org-level bootstrap.
- **frontend (legacy)** refreshes the org key list on these events; **inveniam-v2** does not listen at all (request/response — awaits the POST, then re-reads or waits for WS).
- **websockets-service** rebroadcasts both events (org-shaped payload, no scope ids).

The org events also can't carry scope ids, so consumers can't distinguish levels.

## Decision

Introduce two dedicated events for sub-org writes and route them away from deals-service.

- **New events** (`shared-modules/Events/Hub/IntegrationKeys/`): `HubSetScopedIntegrationKeysCompleteEvent`, `HubSetScopedIntegrationKeysFailedEvent`.
- **Payload** (`Hub/interfaces.ts`): org payload (`organisationId`, `ledgerType`, `hubKey`, `userId?`) + optional `portfolioId` / `dealId` / `dataRoomId`; Failed extends Complete.
- **Routing** (`EventsConstants.ts`, both `EventToMSMap` and `MSToEventsMap`): both events → `hub` + `websocket_main` **only** — explicitly **not** `deals` (no org tokenization bootstrap) and **not** `metachain`.
- **Emit** (`IntegrationKeysModel.setScopedIntegrationKeys`): applies the scoped events with scope ids; org `setIntegrationKeys` still emits the org events.
- **Handlers** (hub-service): `HubSetScopedIntegrationKeys{Complete,Failed}EventHandler` (log only), registered in `IntegrationKeysHandlers`.
- **WebSocket** (`websockets-service/hub-event-messages.config.ts`): both events mapped with `visiblePayloadProps: ['organisationId', 'portfolioId', 'dealId', 'dataRoomId', 'ledgerType', 'hubKey']`.

## Alternatives considered

- **Keep org events, make deals-service saga scope-aware** — rejected: leaks scope logic into a service that should only handle org ledger prep; every other org consumer would still misfire.
- **Route scoped Complete to deals too** — rejected for now: no scope-aware bootstrap exists; can be added later if sub-org tokenization is needed.
- **Route to metachain (audit)** — deferred: org Failed is already excluded there; scoped audit isn't required yet.

## Consequences

- **Positive**: scoped uploads no longer trigger org tokenization bootstrap; events carry scope ids; org path unchanged.
- **Trade-offs**: two more event types + dual-map registration to maintain; inveniam-v2 still doesn't consume them (request/response), so the WS mapping is forward-looking.
- **Follow-ups**: no unit test yet for `setScopedIntegrationKeys` event emission; consider scope-aware deals-service handling if sub-org tokenization is required.

## Affected code

| Path | What changed |
| ---- | ------------ |
| `shared-modules/Events/Hub/interfaces.ts` | scoped Complete/Failed payloads |
| `shared-modules/Events/Hub/IntegrationKeys/*` | two event classes + barrel export |
| `shared-modules/Events/EventsConstants.ts` | `EventToMSMap` + `MSToEventsMap` (hub, websocket_main) |
| `apps/hub-service/.../integration-keys.model.ts` | emit scoped events with scope ids |
| `apps/hub-service/.../events/*` | scoped log handlers + registration |
| `apps/websockets-service/src/hub-event-messages.config.ts` | WS mapping with scope ids |

## Related

- [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md)
- [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md)
- [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
