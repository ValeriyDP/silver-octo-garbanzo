---
name: Wiki Index
date: 2026-09-09T12:33:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - index
---

# Wiki Index

Knowledge base for **Inveniam Indicia (INV-42236)**. How-tos, diagrams, current state, open questions.

Decisions live in [decisions/INDEX](../decisions/INDEX.md). Accepted: [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) (implemented; landing PR in flight). Proposed: [ADR-0004 Erasure Ledger as Lifecycle Event Log](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) (un-forget + ledger remodel, one change). Cross-link; do not copy ADRs here.

## Pages

- [New Developer Onboarding](New%20Developer%20Onboarding.md) — Cold start for the erasure / Slice 2c thread: product split, vocabulary, and Taskfile local start (core vs sidecar/Vault).
- [Core and Sidecar](Core%20and%20Sidecar.md) — Two ports, one HTTP ingest hop, what they share and do not (Vault, DBs, verify join).
- [BYO Producer](BYO%20Producer.md) — Customer hasher uses the same hash-only door and a FusionAuth `writer` JWT; no other-language SDK.
- [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) — Questions that are not decisions yet.
- [Repository Docs](Repository%20Docs.md) — Map of the live repo `docs/` tree; qmd collection `inveniam-indicia-docs`.
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md) — Launch-gating leftover: whole-tenant offboard/purge + Redis cache invalidation; target vs gap PlantUML; do not decouple from the three latent findings.
- [TOCTOU](TOCTOU.md) — Time-Of-Check to Time-Of-Use; why the tenant offboard door is deferred.
- [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md) — Let's Go–style tutorial + how-to for ADR-0003 (person erase only). Steps 0–10: syntax, then a full edit, then a full test. You write the Go.
- [Write the Un-forget](Write%20the%20Un-forget.md) — Same tutorial form for JIRA Task 1 / ADR-0004: `erasure_events` lifecycle log (kinds `destroyed` / `reappeared`, `cycle` per shred), un-forget door, Redis recalculate, remint allowed; old records stay `erased`, a second erase gets its own dates. Store **keeps** `InsertErasureIfAbsent` / `GetErasure` / `ListErasures` / `ListAllErasures`; adds `AppendUnforgotten` + `KeyDestroyedSince`.
- [QA Person Graveyard](QA%20Person%20Graveyard.md) — API-call script for QA (curl) and developers (`task sidecar:*`, `start:sidecar:replica`).
- [ADR-0003 Landing Review Findings](ADR-0003%20Landing%20Review%20Findings.md) — Six pre-implementation findings with all evidence inlined (D3 quote, DP-001/002, API spec facts); scoreboard of what is decided vs open. Discussion reference.
- [JIRA Tasks](JIRA%20Tasks.md) — Register of JIRA-worthy follow-ups from this investigation, each copy-paste ready. Task 1: un-forget + ledger event log, no `cache_purged` (design: ADR-0004; how-to: [Write the Un-forget](Write%20the%20Un-forget.md)). Task 2: **merged into Task 1**. Task 3: **done** (API spec + ops playbook; ship with the landing PR). Task 4: **merged into Task 1**.
- [Handoff 2026-09-03](Handoff%202026-09-03.md) — Session handoff: state (all decided, no code), working rules (human writes the Go, agent teaches), page map, likely next asks. **Start here in a fresh session.**

## Related

- [Project README](../README.md)
- [CLAUDE](../CLAUDE.md) — agent guide, including [how to write the next `Write the …`](../CLAUDE.md#implementation-how-to--after-adrs-are-ready) after ADR(s) are ready (canon: the two how-tos above)
