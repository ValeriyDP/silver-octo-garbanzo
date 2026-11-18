---
name: Open Questions
date: 2026-09-01T13:34:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
---

# Open Questions

**Summary**: Parking lot for things we do not know yet. Promote a question to an ADR in `decisions/` when a design choice is required.

**Sources**: —

**Last updated**: 2026-09-08 (kinds locked `destroyed` / `reappeared` on ADR-0004)

---

| # | Question | Notes | Status |
| - | -------- | ----- | ------ |
| 1 | Do deploy manifests pin the sidecar to a single replica? | Assessment said no in-repo manifest commits a replica count. Until [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) is **implemented**, multi-replica still has hole 1/2. The ADR does not answer whether today’s manifests pin. | open |
| 2 | Is `internal-keyvault-3` (post-erase write fence) in 2c scope or a separate change? | [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) (**Accepted**): shared Redis set + ledger row **is** the fence; ingest `SISMEMBER` before mint. Same delivery as the check. Not implemented yet. | decided |
| 3 | Do we ship API keys / FusionAuth Application (M2M) for BYO machine identities? | Not forget / 2c. See [BYO Producer](BYO%20Producer.md). Left here so it is not lost; **out of this investigation’s scope**. | out of scope |
| 4 | Must a BYO hasher talk to a FusionAuth the core already trusts, or do we accept an IdP we have never configured? | Not forget / 2c. **Out of this investigation’s scope.** | out of scope |
| 5 | Un-forget / graveyard shrink: how does a forgotten subject lawfully re-appear, and how does the Redis forget-set shrink? | [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md): Redis is append-only in 2c; recalculate is the **only** shrink. **Decided 2026-09-08 ([ADR-0004](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md), Proposed):** un-forget door appends a `reappeared` event, then recalculates Redis from the “latest event is destroyed” feed under a lock. Ships together with the ledger remodel (former Task 4 — merged), resolving **Finding 2** of [ADR-0003 Landing Review Findings](ADR-0003%20Landing%20Review%20Findings.md) (interim permanent processing ban; D3 “re-appearance” restored via explicit admin act). JIRA: [JIRA Tasks](JIRA%20Tasks.md) Task 1 — file after the forget-set PR merges. How-to: [Write the Un-forget](Write%20the%20Un-forget.md). Offboard “disable is reversible” in Vault is not this Redis rebuild. | decided — [ADR-0004](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) |
| 6 | R2: close the check-then-cache window (lock erase vs open), or leave “honest on the next request”? | [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) R2: **ok for 2c** — one in-flight GET may still decrypt. Not a 2c blocker. Promote to an ADR if we later want the per-subject lock on read. | open |
| 7 | Company HTTP door + tenant walk (offboard/purge API, company graveyard first). | No API today (`API_SPECIFICATION.md`: not available). [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) §3b is the contract when it is built. **Out of this feature** — person graveyard + replica list only. Do not lose. | out of scope |
| 9 | Erasure ledger as a **lifecycle event log** instead of one row per subject + nullable `unforgotten_at`? | Raised 2026-09-08 while scoping un-forget. `destroyed_at` + `completion_by` describe **one shred**; `unforgotten_at` is a door flag, not a fact. With the compound PK a second erase after un-forget can only clear the flag — the dates still describe the first shred. **Decided 2026-09-08 ([ADR-0004](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md), Proposed):** yes — `erasure_events`, kinds **`destroyed` / `reappeared`** (matches `destroyed_at` and D3; door stays `/unforget`), `cycle` per shred, uniqueness per act `(pair, cycle, kind)`; merged into [JIRA Tasks](JIRA%20Tasks.md) Task 1. `forgotten` / `unforgotten` as kinds rejected (`forgotten` = same POST as destroy; `unforgotten` is the door word). `revoked` / `reinstated` rejected — cleaner English, worse fit to shipped vocab. `completed` deferred until a job appends it. | decided — [ADR-0004](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) |
| 8 | Heal scope: per-company Redis keys (`sidecar:forgotten:{company_id}`) or one global key + all-company hydrate (`ListAllErasures`)? | Review 2026-09-03 found the poisoning case: global key + per-company `ListErasures` heal → first tenant’s heal makes the set non-empty, other tenants never heal → their forgotten members missing (both holes reopen; warm-cache `OpenEvent` bypasses the ledger fallback). **Decided 2026-09-03: one global key, plain set; heal hydrates ALL rows via a new `ListAllErasures`.** No per-company split — the forget-list is expected to stay small. **Revisit trigger:** if the set grows big enough that full hydrate hurts, reopen this row (sharding by company is the known escape). See [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md) Step 2, [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) R3 note. | decided |

When a row becomes a decision, add the ADR and link it here. Leave the question in place with status `decided` and a link, so the wiki still explains *what we asked*.

## Related pages

- [Wiki Index](INV-42236%20-%20Inveniam%20Indicia/wiki/index.md)
- [New Developer Onboarding](New%20Developer%20Onboarding.md)
- [Core and Sidecar](Core%20and%20Sidecar.md)
- [BYO Producer](BYO%20Producer.md)
- [Repository Docs](Repository%20Docs.md)
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](TOCTOU.md)
- [ADR-0004 Erasure Ledger as Lifecycle Event Log](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md)
- [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- [ADR-0002 Forget Table Before Cache](../decisions/ADR-0002%20Forget%20Table%20Before%20Cache.md)
- [ADR-0001 Acknowledged Sidecar Cache Purge](../decisions/ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md)
- [Decision register](../decisions/INDEX.md)
