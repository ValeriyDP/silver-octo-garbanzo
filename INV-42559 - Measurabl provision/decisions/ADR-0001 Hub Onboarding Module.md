---
name: ADR-0001 Hub Onboarding Module
date: 2026-09-15T20:07:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - adr
  - architecture
---

# ADR-0001 Hub Onboarding Module

- **Status**: Accepted
- **Date**: 2026-09-15
- **Area**: hub-service
- **Deciders**: INV-42559
- **Related**: [Hub Service Anchor Projector Sequence](../wiki/Hub%20Service%20Anchor%20Projector%20Sequence.md)

## Context

Stage 2 talks to Hub (the application): login, obtain an admin HubJWT, then create org/keys if missing. That is a different auth path from existing `tokenization/` (`HubTokenizationProvider` uses `/auth/service-login` + org HubKeys).

The module needs a name that means lazy-onboard, not “JWT” and not the ledger-write facade.

## Decision

New hub-service module: **`hub-onboarding`**.

```
apps/hub-service/src/hub-onboarding/
```

It owns login (`POST /auth/login`), holds the admin HubJWT, and calls Hub to create org / org wallet / HubKeys once. Ledger write (`addRegistry`, `addRecord`) stays on the existing tokenization / transactions path after keys exist.

## Alternatives considered

- **`hub-admin`** — accurate for “admin JWT,” but names the role, not the job (lazy-onboard).
- **`tokenization`** — already service-login + ledger write. Wrong login endpoint.
- **`hub-client` / `hub-jwt`** — collides with `HubTokenizationProvider`; JWT is a means.

## Consequences

- **Positive**: Clear split — projector warms `deal_anchors`; `hub-onboarding` establishes Hub org/keys; `tokenization` writes the chain.
- **Negative / trade-offs**: Two Hub HTTP clients (onboarding session vs service-login). That is intentional.
- **Follow-ups / open threads**: Login session is built. Org / keys HTTP is not.

## Affected code

| Path | What changed |
| ---- | ------------ |
| `apps/hub-service/src/hub-onboarding/` | Module, session (`POST /auth/login`), client stub. |
| `apps/hub-service/src/config/environment.ts` | `hub.adminEmail`, `hub.adminPassword`. |
| `apps/hub-service/src/app.module.ts` | Imports `HubOnboardingModule`. |

## Related

- [Measurabl Provisioning Handoff](../wiki/Measurabl%20Provisioning%20Handoff.md)

- [Decision register](Measurabl%20provision%20(INV-42559)/decisions/INDEX.md)
- [Hub Onboarding Chain](../wiki/Hub%20Onboarding%20Chain.md)
- [Hub Service Anchor Projector Sequence](../wiki/Hub%20Service%20Anchor%20Projector%20Sequence.md)
- [Wiki Index](../wiki/index.md)
