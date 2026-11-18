---
name: HOW-TO Enable DLT Validation (NVNM)
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - how-to
  - runbook
  - nvnm
  - ledger
---

# HOW-TO Enable DLT Validation (NVNM)

- **Status**: Living document — keep updated as new nuances are found
- **Area**: inveniam-v2 UI + hub-service + Hub app
- **Ticket**: INV-42086

A step-by-step for getting document validation (DLT sync) working on the **NVNM**
ledger, end to end. Two audiences below: **end customers** (what to click) and
**developers** (what must be set up once). No code here — details live in the
linked ADRs.

> Scope note: scoped hub keys are **NVNM-only** (see
> [ADR-0005](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)). NVNM is an
> **anchoring** ledger: a document is validated by anchoring its fingerprint
> (hash) on-chain — there is no token/symbol to mint.

---

## Key concept — the registry is tied to the deal's "symbol"

This is the crux of NVNM validation and easy to miss:

- An NVNM **anchoring registry** is created on-chain (`addRegistry`) and returns a
  numeric **`registryId`**.
- That `registryId` **is** the deal's NVNM **`symbol`** — it is stored on the deal's
  NVNM integration setting as `config.symbol` (in `deals-service`,
  `deal_integration_settings`, `providerType: "nvnm"`).
- **One registry per deal.** Every document in the deal is anchored (`addRecord`)
  **into that single registry**. There is no per-document or per-data-room registry.
- Therefore the binding is: **hub key → connects; registry (`registryId`) → is the
  deal's symbol; documents → records inside that registry.**
- If the deal has no NVNM `config.symbol`, sync fails early with **"symbol should
  not be empty"** — because there is no registry to anchor into.

Contrast with tokenization ledgers, where "symbol" is a token ticker. For NVNM,
"symbol" is overloaded to mean the **anchoring registry id**.

> Note: connecting a scoped hub key (Add Hub Key) writes only to Vault — it does
> **not** create the NVNM `deal_integration_settings` row. The registry id must be
> recorded on the deal separately (Register flow, or recorded manually for an
> off-site registry). See developer step 4.

---

## For end customers — validate a document

1. **Connect a validation service.** In the organisation, portfolio, deal, or
   data room where you want validation, open **Add Hub Key** and enter your NVNM
   key. The most specific level wins (a data-room key overrides a deal key, and
   so on).
2. **Confirm it's connected.** The data room shows NVNM under **Connected
   validation services** with an active status.
3. **Register the deal for validation (one-time per deal).** In the file's **DLT Management** modal, NVNM shows **Register symbol** when a closest key exists but the deal has no registry yet. Click it. When registration completes, the button becomes **Sync**. If the NVNM chain rejects the write, the setting stays Failed and Register remains available.
4. **Sync a document.** Open the file, go to its **DLT / validation** action, pick
   **NVNM**, and choose **Sync**.
5. **Wait for confirmation.** The document gets an on-chain validation record; the
   file's status updates when the transaction is confirmed.

If a step is greyed out or errors, see **Common problems** below or contact a
developer.

---

## For developers — one-time setup (reminder)

Do these once per environment so the customer steps above work. Exact commands
and paths are in this chat's history and the linked ADRs — this is the checklist.

1. **Hub app is running and reachable.** hub-service must be able to reach the Hub
   application, and the Hub app must have NVNM configured and its wallet funded
   with testnet gas.
2. **Anchoring ABI is stored.** The NVNM anchoring contract ABI (and precompile
   address) must be present in the secret store so hub-service can encode
   transactions. Without it, sync fails before reaching the chain.
3. **Hub key is connected at the right scope.** Add the NVNM key at org /
   portfolio / deal / data room. Scope must be gapless (no skipped levels) — see
   [ADR-0003](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md).
   Closest-key resolution for sync is handled server-side
   ([ADR-0007](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)).
4. **Registry exists and is recorded on the deal.** Create the anchoring registry
   (via the app's Register flow, or off-site) and record its `registryId` as the
   deal's NVNM validation `symbol` (see **Key concept** above — one registry per
   deal). A document cannot be anchored until the deal has a registry recorded.
   - inveniam-v2 **Register symbol** (DLT modal) is the product path: `PATCH /new-deals/:dealId/register-symbol` creates the NVNM setting if missing and emits the Hub Register event ([ADR-0009](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md), [final flow](NVNM%20Register%20And%20Sign%20Final%20Flow.md)). To record an **off-site** registry without going on-chain, `PATCH {deals}/{dealId}/integration-settings/symbol-registered` still only **updates an existing** NVNM setting. Hand-insert remains break-glass (see the DB gotcha below).
   - **DB gotcha — write table vs read projection.** `deals-service` is CQRS: the
     UI reads deal integration settings from the **read projection**
     `vm_deal_integration_settings` (via `GET /new-deals/:dealId/integration-settings`
     → `DealsIntegrationSettingsViewQueryHandler`), **not** from the aggregate/write
     table `deal_integration_settings`. A manual `INSERT` used to record an off-site
     registry must land in **`vm_deal_integration_settings`** (that's the one the
     sync symbol lookup and connected-service surfaces read); writing only to
     `deal_integration_settings` has no effect on the UI. `config` in both tables is
     a **JSON string scalar** (`to_jsonb('{...}'::text)`) to satisfy the read path's
     `JSON.parse(item.config)`. Prefer the event flow (register/connect) which writes
     both sides; hand-inserts are for local unblocking only.
5. **Verify surfacing.** NVNM should appear as a connected validation service
   across the data room UI
   ([ADR-0008](ADR-0008%20Surface%20Scoped%20NVNM%20As%20Connected%20Validation%20Service.md)).
6. **Trigger a sync** from a document and confirm the on-chain record.

---

## Common problems

- **"symbol should not be empty" (400 on Sync).** The deal has no anchoring
  registry recorded yet — i.e. no NVNM `config.symbol` (the registry is the deal's
  symbol; see **Key concept**). Complete step 3/4 (register the deal / record the
  registry id) and retry. If you recorded it by hand-inserting a DB row and still
  see empty `symbol` in the sync request (`{"symbol":"", ...}`), you likely wrote to
  `deal_integration_settings` instead of the read projection
  `vm_deal_integration_settings` — see the DB gotcha in developer step 4.
- **"No Hub key found for the requested scope or organisation" (404).** No NVNM
  key is connected at or above this data room, or a scope level was skipped.
  Connect a key at the right level (gapless).
- **"Cannot GET …/closest" or a route that used to work now 404s.** hub-service is
  running stale code — rebuild/restart it, then retry.
- **NVNM doesn't show as connected.** Rebuild the backend if the resolve endpoint
  is new, and confirm the key scope covers this data room.

---

## Keeping this up to date

Append new nuances here as they're discovered (new prerequisite, new failure mode
and its fix). When a step reflects a design decision, capture the decision as an
ADR and link it from the relevant step above. Re-run the qmd index after edits.

## Related

- [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md)
- [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md)
- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
- [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md)
- [ADR-0008 Surface Scoped NVNM As Connected Validation Service](ADR-0008%20Surface%20Scoped%20NVNM%20As%20Connected%20Validation%20Service.md)
- [ADR-0009 In-App NVNM Register Symbol Flow](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md)
- [NVNM Register And Sign Final Flow](NVNM%20Register%20And%20Sign%20Final%20Flow.md)
