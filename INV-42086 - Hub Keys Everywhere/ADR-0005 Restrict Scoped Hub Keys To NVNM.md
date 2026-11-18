---
name: ADR-0005 Restrict Scoped Hub Keys To NVNM
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

# ADR-0005 Restrict Scoped Hub Keys To NVNM

- **Status**: Accepted — the `NVNM`-only rule and hub-service body guard stand; the **inveniam-v2 (UX guard)** implementation below is superseded by [ADR-0006 Separate Scoped Hub Key Modal](ADR-0006%20Separate%20Scoped%20Hub%20Key%20Modal.md)
- **Date**: 2026-08-22
- **Area**: hub-service + inveniam-v2 UI
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0004 Scoped Hub Key Events](ADR-0004%20Scoped%20Hub%20Key%20Events.md), [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md), [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)

## Context

Scoped hub keys (portfolio / deal / data room) were built to accept **any** `HubLedgerTypeEnum` value, mirroring the org-level endpoint. But **tokenization** is a large, org-shaped concern: uploading an org key for a tokenization-bearing ledger kicks off org ledger bootstrap in deals-service and deploy-on-Active flows (see [ADR-0004 Scoped Hub Key Events](ADR-0004%20Scoped%20Hub%20Key%20Events.md), which already routed scoped events away from that bootstrap).

Conflating scoped credentials with tokenization ledgers pulls that whole topic into the scoped feature, which is not the intent. The only ledger that makes sense for scoped credentials is **`NVNM`** (the Inveniam-native ledger), which does not carry the tokenization fan-out. So the scoped surface should accept `NVNM` only; every other ledger stays org-level.

Today there is no constraint:
- **hub-service**: the three scoped POST routes validate with `LedgerTypePipe` (full enum minus `HubExcludedLedgerTypeEnum`).
- **inveniam-v2**: `AddLedgerViaHubkeyModalComponent` is shared by org and scoped flows and offers all 14 ledgers from `ledgerFixtures` regardless of scope.

## Decision

Restrict the scoped hub-key surface to `HubLedgerTypeEnum.NVNM` on both sides. Org-level behaviour is unchanged.

### hub-service (authoritative enforcement)

- `LedgerTypePipe` is left **unchanged** (it stays a generic enum validator shared by every hub route).
- Each scoped handler (`createPortfolioKeys`, `createDealKeys`, `createDataRoomKeys`) guards in its **body**: `if (ledgerType !== HubLedgerTypeEnum.NVNM) throw new BadRequestException(...)` before delegating to `setScopedIntegrationKeys`. The org route (`/ledger/:ledgerType`) is untouched.
- Rationale for the body guard over a pipe change: the restriction is specific to the scoped endpoints, so it lives with them rather than adding a parameter to a shared validator.

### inveniam-v2 (UX guard)

- In `AddLedgerViaHubkeyModalComponent`, an `isScopedHubKey` computed (`!isOrgOnlyHubKeyScope(scope)`) drives `ledgerOptions`: scoped offers **only** the `NVNM` fixture; org-only keeps the full list. This covers every scoped entry point (root portfolio, deal header, data-room title bar) via the shared modal.
- The file-based `autoSelectLedgerTypeFromFile` effect now only auto-selects a ledger present in `ledgerOptions`, so a key file carrying a non-`NVNM` `ledgerType` can't bypass the scoped restriction.
- For scoped keys the ledger control is pre-set to `NVNM` and **disabled** in the constructor (no point showing a select with one option); `submit()` reads `form.getRawValue()` so the disabled control's value is still sent.

## Alternatives considered

- **Extend `LedgerTypePipe` with an allow-list** — rejected: adds a parameter to a validator shared by all hub routes for a restriction that only concerns the scoped endpoints; the body guard keeps the constraint local.
- **Dedicated `NvnmLedgerTypePipe`** — a one-off pipe with no reuse; the in-body `if` is simpler and equally clear.
- **Enforce only in v2** — rejected: the API must be authoritative; non-UI callers could still POST other ledgers.
- **Enforce only in hub-service** — rejected for UX: the modal would still let users pick a ledger that the backend then rejects.

## Consequences

- **Positive**: scoped keys can't drag in tokenization ledgers; the constraint is enforced at the API and surfaced in the UI; the shared `LedgerTypePipe` and the org path are untouched.
- **Trade-offs**: the same `if` guard is repeated in three handlers (acceptable, and it reads clearly at each endpoint).
- **Follow-ups**: if scoped support later expands beyond `NVNM`, update the three guards and the modal filter.

## Affected code

| Path | What changed |
| ---- | ------------ |
| `apps/hub-service/src/integration-keys/integration-keys.controller.ts` | scoped handlers throw `BadRequestException` unless `ledgerType === HubLedgerTypeEnum.NVNM` |
| `inveniam-v2/.../add-ledger-via-hubkey-modal.component.ts` | `ledgerOptions` restricted to `NVNM` for non-org scope; file auto-select guarded; scoped ledger pre-selected |
| `inveniam-v2/.../add-ledger-via-hubkey-modal.component.spec.ts` | scoped→NVNM assertions, option-restriction tests, 3-arg `hubKey` fix |

## Related

- [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md)
- [ADR-0004 Scoped Hub Key Events](ADR-0004%20Scoped%20Hub%20Key%20Events.md)
- [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)
