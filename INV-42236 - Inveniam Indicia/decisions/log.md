---
name: Decisions Log
date: 2026-09-01T11:54:04.478Z
tags:
  - inveniam-indicia
  - inv-42236
  - adr
  - log
---

# Decisions log

Append-only. Newest at the bottom.

- 2026-09-01 — Created ADR investigation (`decisions/`) for Inveniam Indicia (INV-42236). Register is empty.
- 2026-09-02 — [ADR-0001 Acknowledged Sidecar Cache Purge](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md): Proposed. Sidecar control-plane purge with replica ack; not an Indicia event; `cache_purged` only after acks.
- 2026-09-02 — ADR-0001: named the stack **quiesce–shred–invalidate-ack**; “unfreeze” does not lift the tombstone on the shredded subject.
- 2026-09-02 — ADR-0001: “skip” restated as **process-as-is** — inert row + hashes, verify `erased`; not delete, not retry.
- 2026-09-03 — [ADR-0002 Forget Table Before Cache](ADR-0002%20Forget%20Table%20Before%20Cache.md): Proposed. Forget-table is truth; nudge = reload; list before cache. Intended to supersede ADR-0001 if accepted.
- 2026-09-03 — [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md): Proposed. Hot forget-list in shared Redis (`SADD` only); no nudge. Intended to supersede ADR-0002 if accepted.
- 2026-09-03 — ADR-0003: R1 + R4 approved; R5 pinned Redis-first then ledger (no `SREM` on insert fail). R2 + R3 still open.
- 2026-09-03 — ADR-0003: Redis forget-set is append-only. Routine sync = Postgres query + `SADD` on top. Recalculate (rebuild the key) only if a graveyard row is removed in Postgres.
- 2026-09-03 — ADR-0003: un-forget / Redis recalculate is **out of Slice 2c** — dedicated follow-up; parked as [Open Questions](../wiki/Open%20Questions.md) #5.
- 2026-09-03 — ADR-0003 R2: ok for 2c (one in-flight read). Tighten-or-not parked as [Open Questions](../wiki/Open%20Questions.md) #6.
- 2026-09-03 — ADR-0003 R3: empty Redis graveyard → heal from Postgres + `SADD` on top, then continue (not fail closed).
- 2026-09-03 — ADR-0003 R5 corrected: **erase write = Postgres first**, then `SADD`. Read/ingest still Redis first. Redis-first was the check path, not the erase path.
- 2026-09-03 — [ADR-0003](ADR-0003%20Shared%20Redis%20Forget%20Set.md) **Accepted**. [ADR-0001](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md) and [ADR-0002](ADR-0002%20Forget%20Table%20Before%20Cache.md) superseded. No implementation.
- 2026-09-03 — ADR-0003 §3b: tenant TOCTOU freeze = company graveyard first (Postgres + `SADD`), then walk people. Ingest checks company, then person.
- 2026-09-03 — Company HTTP door / tenant walk **out of this feature**. §3b kept as later contract. [Open Questions](../wiki/Open%20Questions.md) #7.
- 2026-09-03 — ADR-0003 how-to: [Write the Person Graveyard](../wiki/Write%20the%20Person%20Graveyard.md). Still not implemented.
- 2026-09-03 — ADR-0003 review note under R3: heal-on-empty with one global key + per-company hydrate is unsound (first tenant’s heal hides the rest). Scope decision parked as [Open Questions](../wiki/Open%20Questions.md) #8; key example in §1 to be amended when decided.
- 2026-09-03 — ADR-0003 / #8 **decided**: global key stays; R3 heal hydrates **all** rows via new `ListAllErasures`. No per-company key split (list expected small; reopen #8 if it grows). §1 key example unchanged.
- 2026-09-08 — [ADR-0004 Erasure Ledger as Lifecycle Event Log](ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md): Proposed. Un-forget and the ledger remodel are **one** change (former JIRA Task 4 merged into Task 1); the interim `unforgotten_at` flag design is dropped. New `erasure_events` (append-only; kinds `destroyed`/`unforgotten`; `cycle` per shred; uniqueness per act), backfill from `erasure_ledger`; heal/recalculate read the same “latest is destroyed” feed; `resolveUnopenable` asks “destroyed since this record’s creation”. Resolves [Open Questions](../wiki/Open%20Questions.md) #5 and #9. “Proposed — confirm” block lists what awaits the owner’s yes.
- 2026-09-08 — ADR-0004: **`cache_purged` is not on `erasure_events` and is not on the HTTP attestation.** Former JIRA Task 2 folded in. DP-001 closure: retired, not made honest. Keyvault local purge unchanged and unattested.
- 2026-09-08 — ADR-0004 kinds **locked `destroyed` / `reappeared`**. Door stays un-forget. `revoked`/`reinstated` rejected (vocab fit); `unforgotten` as a kind rejected (door already owns the word).
- 2026-09-09 — ADR-0004: `GET /v1/erasures` **locked** as currently forgotten in that tenant (same latest-is-`destroyed` feed as heal). Full event-log listing deferred.
