---
name: Hub Keys Everywhere (INV-42086)
date: 2026-08-21T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - index
  - architecture
---

# Hub Keys Everywhere (INV-42086)

Design decisions for the **scoped Hub integration keys** feature — adding HUB keys anywhere in the hierarchy (**organisation → portfolio → deal → data room**) with most-specific-wins resolution. Spans `inveniam.io` (`hub-service`) and `inveniam-v2` (Angular UI). This folder is scoped to this feature, **not** the whole project.

Each decision is a self-contained note capturing **context → decision → consequences**, so a future engineer can understand *why* the code looks the way it does without archaeology.

## How to use this folder

- One decision per note. Prefix with a zero-padded number: `ADR-0001 …`, `ADR-0002 …`.
- Start from [ADR Template](INV-42086%20-%20Hub%20Keys%20Everywhere/ADR%20Template.md) — copy it, fill it in, then add a row to the register below.
- Keep notes durable: record the reasoning and trade-offs, not a play-by-play of the work.
- Cross-link related decisions at the bottom with Markdown links (`[Title](Title.md)`, spaces URL-encoded as `%20`).
- Status values: `Proposed` · `Accepted` · `Superseded by [ADR-XXXX …](ADR-XXXX%20….md)` · `Deprecated`.

## Decision register

| ADR | Title | Area | Status | Date |
| --- | ----- | ---- | ------ | ---- |
| [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md) | Scoped Add HUB Key across the org hierarchy | inveniam-v2 UI + Hub | Accepted | 2026-08-20 |
| [ADR-0002 Per-Level Hub Key Endpoints](ADR-0002%20Per-Level%20Hub%20Key%20Endpoints.md) | Per-level POST endpoints + v2 DTO alignment | hub-service + inveniam-v2 UI | Accepted | 2026-08-21 |
| [ADR-0003 Gapless Scoped Vault Path And Command Wiring](ADR-0003%20Gapless%20Scoped%20Vault%20Path%20And%20Command%20Wiring.md) | Gapless scoped Vault path builder + scoped command wiring | hub-service | Accepted | 2026-08-21 |
| [ADR-0004 Scoped Hub Key Events](ADR-0004%20Scoped%20Hub%20Key%20Events.md) | Dedicated scoped Complete/Failed events routed away from deals-service | hub-service + events + websockets-service | Accepted | 2026-08-22 |
| [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md) | Scoped hub keys limited to the NVNM ledger only | hub-service + inveniam-v2 UI | Accepted (v2 UI portion superseded by [ADR-0006](ADR-0006%20Separate%20Scoped%20Hub%20Key%20Modal.md)) | 2026-08-22 |
| [ADR-0006 Separate Scoped Hub Key Modal](ADR-0006%20Separate%20Scoped%20Hub%20Key%20Modal.md) | Isolate the experimental scoped modal from the org settings modal | inveniam-v2 UI | Accepted | 2026-08-22 |
| [ADR-0007 Server-Side Closest Hub Key Resolution](ADR-0007%20Server-Side%20Closest%20Hub%20Key%20Resolution.md) | Move closest-key climb into a hub-service NVNM-only resolve endpoint; DLT Sync uses it | hub-service + inveniam-v2 UI | Accepted (implemented) | 2026-08-22 |
| [ADR-0008 Surface Scoped NVNM As Connected Validation Service](ADR-0008%20Surface%20Scoped%20NVNM%20As%20Connected%20Validation%20Service.md) | Append NVNM to `availableLedgers` via `/closest` so a scoped key shows as connected across the data room | inveniam-v2 UI | Accepted (implemented) | 2026-08-22 |
| [ADR-0009 In-App NVNM Register Symbol Flow](ADR-0009%20In-App%20NVNM%20Register%20Symbol%20Flow.md) | NVNM-only one-click "Register symbol" in v2 (create-if-missing setting; reuse register→registryId→writeback via `/hub/transactions/on-complete`) | inveniam-v2 UI + deals-service | **Accepted (implemented)** | 2026-08-24 |
| [ADR-0010 Scope-Aware Credentials In Transaction Execution](ADR-0010%20Scope-Aware%20Credentials%20In%20Transaction%20Execution.md) | Send path signs with the closest scoped NVNM key (climb→org); thread `portfolioId`/`dataRoomId` through sync/register events | hub-service + data-room-service + deals-service + events | **Rejected** → [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md) (kept for diagnosis) | 2026-08-24 |
| [ADR-0011 NVNM Org-Slot Key Promotion For Sync (Demo)](ADR-0011%20NVNM%20Org-Slot%20Key%20Promotion%20For%20Sync%20(Demo).md) | Demo shortcut: promote the closest scoped NVNM key into the org slot just before sync (no revert); UI sync calls promote instead of `/closest` | hub-service + inveniam-v2 UI | **Rejected** → [ADR-0012](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md) | 2026-08-24 |
| [ADR-0012 Path Seeker Reconstruct Scope Then Closest](ADR-0012%20Path%20Seeker%20Reconstruct%20Scope%20Then%20Closest.md) | Recover scope inside hub-service (`org+deal` → portfolio via [ADR-0013](ADR-0013%20Local%20Deal%20To%20Portfolio%20Projection%20For%20Scope%20Resolution.md), then ADR-0007 closest climb) — no event/saga/UI change | hub-service | **Accepted (implemented)** | 2026-08-24 |
| [ADR-0013 Local Deal To Portfolio Projection For Scope Resolution](ADR-0013%20Local%20Deal%20To%20Portfolio%20Projection%20For%20Scope%20Resolution.md) | Dedicated `deal_scope` projection (`deal_id` → `portfolio_id` / `parent_portfolio_ids`) from `DealCreated`/`DealUpdated`; O(1) root-portfolio lookup for Path Seeker | hub-service | **Accepted (implemented)** | 2026-08-24 |

## Guides

| Guide | Purpose |
| ----- | ------- |
| [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md) | End-customer + developer runbook for getting document validation (DLT sync) working end to end on NVNM |
| [IMPLEMENTATION PLAN Scoped NVNM Sign And Register](IMPLEMENTATION%20PLAN%20Scoped%20NVNM%20Sign%20And%20Register.md) | Ordered, file-level path (Phase A projection → B scope-aware signing → C in-app register) to implement the accepted ADR-0009 + 0012 + 0013 design; verify/rollback per step |
| [NVNM Register And Sign Final Flow](NVNM%20Register%20And%20Sign%20Final%20Flow.md) | Implemented connect → closest → Register symbol → Path Seeker sign → Hub addRegistry sequence (success + immediate RPC fail) |
| [PM Overview Hub Keys Everywhere PoC](PM%20Overview%20Hub%20Keys%20Everywhere%20PoC.md) | Non-technical briefing / slide copy for PMs: what shipped, customer journey, PoC boundaries |
| [Feature Branch vs Mainline](Feature%20Branch%20vs%20Mainline.md) | What `INV-42086-hub-keys-everywhere` adds vs develop/master: attach → connected → register → sync (no ADR history) |

## Conventions

- **Filename**: `ADR-<n> <Short Title>.md` (Title Case).
- **Areas**: `inveniam-v2 UI`, `hub-service`, `deals-service`, `iam-service`, `platform/infra`, etc.
- **Supersession**: never delete an ADR — mark it `Superseded` and link the replacement.

## Search

This folder is an isolated, `qmd`-searchable LLM wiki. See [AGENTS](INV-42086%20-%20Hub%20Keys%20Everywhere/AGENTS.md) → [CLAUDE](INV-42086%20-%20Hub%20Keys%20Everywhere/CLAUDE.md) for the search workflow and one-time setup; [log](INV-42086%20-%20Hub%20Keys%20Everywhere/log.md) tracks every change.
