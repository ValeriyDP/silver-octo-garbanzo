---
name: ADR-0009 In-App NVNM Register Symbol Flow
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - adr
  - architecture
  - nvnm
  - registry
---

# ADR-0009 In-App NVNM Register Symbol Flow

- **Status**: **Accepted (implemented)** (2026-08-24). Pairs with [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md): 0009 registers the deal's NVNM symbol, 0012 makes the scoped key sign. Together they replace the rejected [ADR-0010](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md)/[ADR-0011](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md). See [NVNM Register And Sign Final Flow](NVNM%20Register%20And%20Sign%20Final%20Flow.md).
- **Date**: 2026-08-22
- **Area**: inveniam-v2 UI + deals-service (+ hub-service already done)
- **Deciders**: Valerii Ilikhmetov
- **Related**: [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md), [ADR-0005](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md), [ADR-0007](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md), [ADR-0008](ADR-0008%20Surface%20Scoped%20NVNM%20As%20Connected%20Validation%20Service.md), [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md), `INV-42086`

## Context

NVNM document validation anchors each document (`addRecord`) into a per-deal
**anchoring registry**. That registry's numeric `registryId` **is** the deal's NVNM
`symbol` (see the HOW-TO "Key concept"). Without it, DLT Sync fails with
`symbol should not be empty` (400).

Today inveniam-v2 has **no way to create that registry**. The register/tokenization
surfaces only exist in the legacy `frontend`. In v2 the scoped "Add Hub Key" flow
connects a key to Vault but never creates a deal integration setting, and there is
no "Register" action — so a freshly connected NVNM deal is stuck: connected but
un-syncable. Operators have had to hand-insert the registry id into the DB
(`vm_deal_integration_settings.config.symbol`), which is error-prone and bypasses
the event flow.

The **backend register→registryId→writeback chain already exists and is NVNM-aware**:

- `PATCH /new-deals/:dealId/register-symbol` (deals-service) → `symbolRegister` →
  emits a `Register` transaction event.
- hub-service NVNM codec `encode(Register)` → `addRegistry(name, description, metadata)`
  (currently hardcodes `name=description=dealId`, `metadata=''`).
- On completion the Hub app calls back the existing webhook
  `POST /hub/transactions/on-complete` → `TransactionsService.onComplete` →
  `NvnmLedgerProvider.onComplete` (for `Register` + `Succeed`): fetch receipt →
  `decodeRegistryCreatedFromReceipt` (reads the `RegistryCreated` log) → `registryId`
  → `publishSymbolRegisterEvent(symbol=registryId)` →
  `HubSymbolRegisteringSucceededEvent`. (A smart-account receipt-polling path runs
  the same `onComplete`.)
- deals-service saga `handleHubSymbolRegisteringSucceededEvent` →
  `SymbolRegistrationSucceededCommand` writes `config.symbol = registryId`,
  `registerSymbolStatus=Active`, and for NVNM `isTokenDeployed=true`,
  `icpLedgerState=Active` — updating both the write aggregate and the
  `vm_deal_integration_settings` read projection the UI reads.

Two gaps block reuse of this chain from v2:

1. **`symbolRegister` requires a pre-existing NVNM deal setting.** It calls
   `getIntegrationSettingCryptoTransaction(nvnm)` then immediately reads
   `appConfig.appType` — so it throws if no NVNM `deal_integration_settings` row
   exists. The scoped Add Hub Key flow writes only to Vault, so that row never
   exists.
2. **No v2 UI** to trigger register or reflect "connected but not registered".

## Decision

Add an **NVNM-only, one-click "Register symbol"** action in inveniam-v2, reusing the
existing backend chain, with one small deals-service change.

**deals-service — create-if-missing.** Make `symbolRegister` (NVNM path) create the
NVNM `data-validation` integration setting when it is absent, then proceed to emit
the `Register` event. This removes the hard dependency on a prior `connect-hub` and
fits the scoped-key model (key in Vault, no deal setting yet). Non-NVNM behaviour is
unchanged.

**No register form.** The registry is created with `name=description=dealId` and
predefined empty metadata (the encoder already hardcodes this). The action is a
single confirm — no user-entered name/metadata in v1. (Threading a custom name
through event → codec is a possible later enhancement.)

**inveniam-v2 UI — Register action + NotRegistered state.**

- In the DLT modal row model (`buildDltRows`), when the ledger is **NVNM**, it is a
  connected validation service (ADR-0008 `availableLedgers` has NVNM), **and** the
  deal setting has no `symbol`, render a **NotRegistered** state.
- In that state show a **"Register symbol"** button in place of **Sync** (the
  `dataroom-taxonomy-info` row already has the action slot next to Sync).
- On click → new v2 API call `POST/PATCH …/register-symbol` (NVNM config) → row
  shows **"Registering…"** (Pending).
- **Wait via the existing hub webhook path.** The UI does not drive completion;
  registration completes server-side when the Hub app calls
  `/hub/transactions/on-complete`, which writes `config.symbol`. The UI reflects it
  by re-reading the deal integration settings (reload the resource; optionally
  triggered by the existing WS event stream) until `config.symbol` appears — then the
  row flips to normal and **Sync** is enabled, resuming the existing DLT flow.
- **NVNM-only gate**: only when `HUB_LEDGER_BY_TYPE[ledgerType] === 'NVNM'`
  (consistent with ADR-0005). Other ledgers never show Register.

## Alternatives considered

- **Require `connect-hub` first (no register-path backend change)** — the UI would
  call `connect-hub` to create the NVNM setting, then `register-symbol`. Rejected:
  `connect-hub` triggers a real hub connection flow and an extra round-trip/state;
  create-if-missing is simpler and matches the scoped model where the key already
  lives in Vault.
- **Collect a name + metadata form** — rejected for v1: the encoder ignores them
  today (hardcodes `dealId`), so a form would be cosmetic until the event/codec are
  extended. Keep v1 one-click; revisit if product wants human-readable registry
  names.
- **Keep hand-inserting the registry id in the DB** — rejected: bypasses the event
  flow, must target the read projection `vm_deal_integration_settings`, and is
  operator-only. Fine as a break-glass, not a product flow.
- **Client-driven wait/poll of a hub read endpoint** — unnecessary: completion is
  already delivered by the `/hub/transactions/on-complete` webhook writing back the
  symbol; the UI only needs to observe the resulting deal-settings change.

## Consequences

- **Positive**: v2 becomes self-sufficient for NVNM validation (connect → register →
  sync) with no DB surgery; reuses the entire proven backend chain incl. the webhook
  completion and smart-account polling path; NVNM-only keeps blast radius minimal.
- **Negative / trade-offs**: one deals-service behaviour change (create-if-missing)
  that must not regress non-NVNM providers; the UI must handle a Pending/"Registering"
  window whose completion is asynchronous (webhook-driven), including the failure
  event (`HubSymbolRegisteringFailedEvent` → `SymbolRegistrationFailedCommand`).
- **Follow-ups / open threads**:
  - Confirm which signal the v2 modal uses to refresh after register (reload of the
    deal-integration-settings resource vs a specific WS event fanned to the client).
  - Decide whether "Register" should also be surfaced outside the DLT modal (e.g.
    the connected-services popover) or modal-only for v1.
  - Optional later: user-provided registry name/metadata (event + codec changes).

## Affected code

| Path | What changed |
| ---- | ------------ |
| `inveniam.io/apps/deals-service/.../models/deal-integration-settings.model.ts` | `symbolRegister` NVNM: create the NVNM data-validation setting if missing before emitting Register |
| `inveniam-v2/.../shared/inveniam-api/.../new-deals/(dealId)/register-symbol` | New v2 endpoint binding to `PATCH /new-deals/:dealId/register-symbol` |
| `inveniam-v2/.../browser/inveniam-api/.../*integration-settings*.service.ts` | Service method to call register-symbol |
| `inveniam-v2/.../features/dataroom/.../helpers/dlt-management.helper.ts` (`buildDltRows`) | Add NVNM NotRegistered state (connected + no symbol) |
| `inveniam-v2/.../features/dataroom/.../dataroom-taxonomy-info/*` | Render "Register symbol" button in NotRegistered state |
| `inveniam-v2/.../features/dataroom/.../dataroom-dlt-management-modal/*` | Wire register handler + Pending/"Registering" + reload-until-symbol |

## Related

- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0008 Surface Scoped NVNM As Connected Validation Service](ADR-0008%20Surface%20Scoped%20NVNM%20As%20Connected%20Validation%20Service.md)
- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md)
