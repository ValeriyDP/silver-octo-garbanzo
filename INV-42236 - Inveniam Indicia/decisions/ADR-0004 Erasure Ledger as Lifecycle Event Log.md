---
name: ADR-0004 Erasure Ledger as Lifecycle Event Log
date: 2026-09-08T16:20:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - adr
  - architecture
---

# ADR-0004 Erasure Ledger as Lifecycle Event Log

- **Status**: Proposed
- **Date**: 2026-09-08
- **Area**: sidecar / record store / erasure doors
- **Deciders**: investigation owner. **Locked 2026-09-08:** un-forget and the ledger remodel ship as **one** change ([JIRA Tasks](../wiki/JIRA%20Tasks.md) Task 1; former Task 4 merged). No interim `unforgotten_at` column. Everything under *Proposed — confirm* below is the agent's design, waiting for the owner's yes.
- **Pinned**: ledger is append-only; one table `erasure_events`; kinds are **`destroyed` / `reappeared`** (locked 2026-09-08 — matches shipped `destroyed_at` / `key_destroyed` and D3 “re-appearance”). "Currently forgotten" = latest event is `destroyed`; "this record's key was shredded" = a `destroyed` event at or after the record's `created_at`; heal and recalculate read the same "latest is destroyed" feed; the compound primary key `(company_id, subject_pseudonym)` goes away. HTTP/Go door stays un-forget (`POST /unforget`, `AppendUnforgotten`, `UnforgetSubject`) — tenant verb; `kind` is the log. **`cache_purged` is not a column on the new table and is not on the attestation JSON.**
- **Related**: [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md) §4 (recalculate exception — this ADR names the trigger), [Open Questions](../wiki/Open%20Questions.md) #5 #9, [JIRA Tasks](../wiki/JIRA%20Tasks.md) Task 1, [Write the Un-forget](../wiki/Write%20the%20Un-forget.md) (how-to), repo `docs/plans/DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md` D3.

## Context

`erasure_ledger` (sidecar migration `002_create_erasure_ledger.up.sql`) is **one row per `(company_id, subject_pseudonym)`**. The primary key does two jobs at once (source: comment in `002`): it stops a **retried** `POST /v1/erasures` from re-dating the first shred (`destroyed_at` / `completion_by` stay put — the regulator clock), and it silently declares that a subject has **one** lifecycle. For one shred that is a valid attestation. Every repo doc that touched the table (`CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md` §8, D3/D3c, Slice 2b §8.2, API spec) designed only "one shred + retry of the same POST." None investigated a second cycle.

[ADR-0003](ADR-0003%20Shared%20Redis%20Forget%20Set.md) landed the forget set: after erase, ingest answers `410 subject_erased` **forever**. That reversed shipped policy D3 ("erasure survives re-appearance — a later lawful event mints a fresh key"), accepted as an interim with un-forget as the exit ([ADR-0003 Landing Review Findings](../wiki/ADR-0003%20Landing%20Review%20Findings.md) Finding 2).

The first un-forget design (2026-09-08, morning) added a nullable `unforgotten_at` to the same row. Scoping it found the flaw:

| Column | What it is |
| --- | --- |
| `destroyed_at` | **Fact.** Vault destroyed this key. Once. |
| `completion_by` | **Deadline** for that same shred: `destroyed_at` + snapshot retention. |
| `unforgotten_at` | **Door flag** dressed as a date. `NULL` = fenced. Says nothing about any key. |

Un-forget is the act that makes a **second shred** possible. With one row per subject, a second erase can only `NULL` the flag back; the row's dates then describe the first shred and the second key destroy is undated. Updating the dates misdates the first shred; not updating them misdates the second. Both are wrong, and a table you `UPDATE` in place is not a ledger. `unforgotten_at` is not a stepping stone to a fix — it is a dead end that the fix would remove (migration, `Supersede`/`Reactivate` methods, a "known limit" sentence in the API spec, their tests).

What does **not** depend on the schema and survives from the first design: the `POST /v1/erasures/unforget` door, RBAC, `Recalculate` with a lock, the read path's "ever destroyed ≠ currently forgotten," heal reading the same feed as recalculate, the integration flow.

## Decision

**Replace the one-row-per-subject table with an append-only lifecycle log, and ship un-forget on top of it in the same change.**

### 1. Schema (`003_create_erasure_events.up.sql`)

```sql
CREATE TABLE IF NOT EXISTS erasure_events (
    company_id        TEXT        NOT NULL,
    subject_pseudonym TEXT        NOT NULL,
    -- 0 = first shred; reappeared of cycle n is followed by destroyed of cycle n+1.
    cycle             INTEGER     NOT NULL,
    kind              TEXT        NOT NULL CHECK (kind IN ('destroyed', 'reappeared')),
    occurred_at       TIMESTAMPTZ NOT NULL,
    -- destroyed only: occurred_at + key-store snapshot retention.
    completion_by     TIMESTAMPTZ,
    PRIMARY KEY (company_id, subject_pseudonym, cycle, kind),
    CONSTRAINT erasure_events_shape CHECK (
        (kind = 'destroyed'  AND completion_by IS NOT NULL) OR
        (kind = 'reappeared' AND completion_by IS NULL))
);
CREATE INDEX IF NOT EXISTS idx_erasure_events_tenant_time
    ON erasure_events (company_id, occurred_at DESC);

INSERT INTO erasure_events (company_id, subject_pseudonym, cycle, kind, occurred_at, completion_by)
SELECT company_id, subject_pseudonym, 0, 'destroyed', destroyed_at, completion_by
  FROM erasure_ledger
ON CONFLICT DO NOTHING;
```

- **No uniqueness on the pair.** Uniqueness is per **act**: `(pair, cycle, kind)`. That is what keeps retry idempotency on the proven `INSERT … ON CONFLICT DO NOTHING` path instead of moving it into application locks.
- **`cycle`** is the count of shreds. It answers the question the old table could not: *how many times, and when each time.*
- **Two kinds.** `destroyed` = Vault killed this key; the row carries `completion_by` (matches `destroyed_at` / `key_destroyed`). `reappeared` = an admin restored the right to process (D3); no key is created here. Door names stay un-forget (`AppendUnforgotten` writes `reappeared`; `AppendDestroyed` writes `destroyed`). Adding `completed` later is a `CHECK` migration — see Alternatives.
- **No `cache_purged`.** After ADR-0003 the field is not the control plane; it reports `true` after a local DEK drop while sibling RAM is not evicted. The new table does not copy the lie. Keyvault may still set `Attestation.CachePurged` internally — the HTTP door does not persist or echo it. DP-001's closure: the field was retired, not made honest.
- `erasure_ledger` is backfilled into cycle 0 (without the old flag) and **left in place, unwritten**. A later migration drops it after one release of verification. No `.down.sql` (none exist in this tree).

### 2. The four questions and their queries

| Question | Who asks | Query |
| --- | --- | --- |
| Is this subject **currently forgotten**? | ingest / read fence (via Redis), preview `already_erased` | latest event by `ORDER BY cycle DESC, (kind = 'reappeared') DESC LIMIT 1`; forgotten ⇔ `kind = 'destroyed'` |
| Which subjects are forgotten **right now**? | forget-set heal **and** recalculate (same feed) | `DISTINCT ON (company_id, subject_pseudonym)` with the same order, outer `WHERE kind = 'destroyed'` |
| Was **this record's** key shredded? | `resolveUnopenable` on unwrap failure | `EXISTS kind = 'destroyed' AND occurred_at >= record.created_at` |
| Forgotten in **this** tenant? | `GET /v1/erasures` | same latest-is-`destroyed` feed as heal, `company_id = $1`. No history of shreds or un-forgets in this change (later). |

Ordering is by `(cycle, kind)`, **never** by wall clock: two replicas' clocks can disagree by more than the gap between an erase and an un-forget.

The third question is sharper than today's "any row → `erased`." After un-forget, a **new** record is sealed under a **fresh** key. If that key later fails to unwrap while the subject is *not* re-erased, today's logic would say `erased`; it is an integrity alarm. `occurred_at >= created_at` says so. Records sealed before a destroy are `erased`; records sealed after the latest destroy are not explained by it.

### 3. Writes (append only)

**Erase** (`POST /v1/erasures`) — Vault destroy → append `destroyed` → `SADD`. Same order as ADR-0003 R5.

```sql
INSERT INTO erasure_events (company_id, subject_pseudonym, cycle, kind, occurred_at, completion_by)
SELECT $1, $2, COALESCE(MAX(cycle) + 1, 0), 'destroyed', $3, $4
  FROM erasure_events
 WHERE company_id = $1 AND subject_pseudonym = $2 AND kind = 'reappeared'
ON CONFLICT DO NOTHING
RETURNING …
```

Next cycle = one past the last un-forget, or 0. A retry computes the same cycle, conflicts, and the handler answers with the incumbent `destroyed` event (`already_erased: true`, original dates) — the second-round-trip pattern `InsertErasureIfAbsent` already uses and documents. **No `Reactivate`:** a second erase after un-forget is just cycle n+1 with its own dates.

**Un-forget** (`POST /v1/erasures/unforget`, new) — append `reappeared` → `Recalculate` Redis. The path name stays un-forget (tenant door); the row's `kind` is `reappeared`.

```sql
INSERT INTO erasure_events (company_id, subject_pseudonym, cycle, kind, occurred_at)
SELECT company_id, subject_pseudonym, cycle, 'reappeared', $3
  FROM erasure_events
 WHERE company_id = $1 AND subject_pseudonym = $2 AND kind = 'destroyed'
 ORDER BY cycle DESC LIMIT 1
ON CONFLICT DO NOTHING
RETURNING …
```

Zero rows means either never erased (`404 not_erased`) or already un-forgotten (`200 already_unforgotten: true`); the handler tells them apart with the latest-event query. Redis failure after the row is `503 unforget_incomplete`; re-POST retries only the rebuild. RBAC = `company_admin` + `requireTenant`, same group as erase; no `global_admin`.

**Nothing ever `UPDATE`s or `DELETE`s a row.** The forget set stays append-only on the erase/heal path (ADR-0003 §4); `Recalculate` (`DEL` + `SADD` of the current feed, under a `SET NX` lock) is the one shrink, and its trigger is now named: **a `reappeared` event was appended.**

### 4. HTTP shape

- `POST /v1/erasures` attestation gains `cycle`. `already_erased` keeps its meaning.
- `GET /v1/erasures` keeps the `erasures` array: **currently forgotten** subjects in that tenant (latest event is `destroyed`). Each item gains `cycle`. After un-forget the subject is absent; after re-erase they return with the new shred's dates. **No history listing** (`reappeared` rows, older shreds) in this change. **No `cache_purged`.**
- `POST /v1/erasures/unforget` → `200 {company_id, subject_pseudonym, cycle, unforgotten_at, already_unforgotten, message}` · `404 not_erased` · `503 store_failed | unforget_incomplete`.
- Ingest after un-forget: `202`, fresh key. Old records: `410 erased` on GET, `result: erased` on verify.

### 5. Go surface (consumer-side interfaces, as today)

| Package | Change |
| --- | --- |
| `internal/sidecar/store` | `Erasure` → `ErasureEvent` (`Cycle int`, `Kind EventKind`, `OccurredAt`, `CompletionBy *time.Time`). Keep `InsertErasureIfAbsent`, `GetErasure`, `ListErasures` (latest-is-`destroyed`, one tenant), `ListAllErasures` (same feed, all tenants). Add `AppendUnforgotten`, `KeyDestroyedSince`. |
| `internal/sidecar/forget` | `Hydrator.ListForgotten`; `Recalculate` (+ `Del`, `SetNX` on `redisSet`); `IsForgotten` / `MarkForgotten` unchanged and still forbidden `Del`/`SRem`. |
| `internal/sidecar/http` | `ErasureStore` grows `AppendUnforgotten` + `KeyDestroyedSince`; `ForgetSet.Recalculate`; erase/preview keep existing verbs; listing stays current-forgotten; new `UnforgetSubject`. |
| `internal/sidecar/router.go` | `erasure.POST("/unforget", …)` in the existing `company_admin` group. |

## Alternatives considered

- **Nullable `unforgotten_at` on the existing row (Task 1 v1), event log later (Task 4).** Rejected 2026-09-08. Delivers the door but leaves a second shred undated and puts an `UPDATE` on the attestation table; the migration, methods, spec sentence and tests are all removed by the follow-up. Cheaper to do once. The only argument for it was deadline pressure on lifting the ban; none exists.
- **Four states `destroyed / forgotten / unforgotten / completed`.** `forgotten` would be written by the same handler in the same request as `destroyed` — no independent act, no independent clock; the fence *is* the consequence of the destroy, so the latest-is-destroyed rule expresses it. `unforgotten` as a *kind* was dropped: it is the leftover antonym of `forgotten`, and the HTTP door already owns that word. `completed` is only honest if a job appends it when `completion_by` passes; no such job exists. Until one does, `completion_by` stays a field on the `destroyed` event.
- **`revoked` / `reinstated` as kinds.** Cleaner English on one axis (right to process). Rejected 2026-09-08 in favour of `destroyed` / `reappeared`: those words already live in the attestation (`destroyed_at`, `key_destroyed`) and in D3 (“re-appearance”). The door stays `/unforget`; `kind` is the log.
- **`key_destroyed` / `key_created` (or `created`).** Rejected: un-forget does not create a key; remint is a later ingest and is not an erasure-ledger event. There is a gap (ban lifted, no new key yet) that only a non-destroy row can fill.
- **Alter `erasure_ledger` in place** (drop the PK, add `kind`/`cycle`, make `destroyed_at` nullable). Same data model, but `destroyed_at` holding an un-forget time and a `NOT NULL` column going nullable read as lies in the SQL. A new table with honest column names and a backfill is one migration either way.
- **Per-subject advisory lock instead of `(pair, cycle, kind)` uniqueness.** Works, but moves retry safety from a constraint the database enforces into a code path every writer must remember. The unique act key keeps `ON CONFLICT DO NOTHING`.
- **Wall-clock `MAX(created_at)` for "latest".** The user's first sketch. Rejected for ordering: `cycle` + `kind` is total and replica-clock-independent; `occurred_at` stays for humans and regulators.
- **`SREM` of one member on un-forget.** Rejected in ADR-0003 §4 already: two concurrent un-forgets each `SREM` their own and neither sees the other's snapshot; rebuild-from-Postgres under a lock is the rule.
- **Carry `cache_purged` onto `erasure_events`.** Rejected 2026-09-08. The column is not the control plane (ADR-0003); nothing reads it; it still attests a fleet-wide RAM drop that never happens. Copying it into a new table would keep the DP-001 lie on the regulator artifact. The door omits the JSON field; keyvault's local purge is unchanged and unattested.

## Consequences

- **Positive**: every shred has its own `destroyed_at` / `completion_by`; "how many times" is `cycle`; retry idempotency is still a unique constraint; no `UPDATE` on the regulator artifact; the read path stops calling a live-key failure `erased` after an un-forget; un-forget and second erase are one door pattern (append, then Redis), no `Reactivate` special case; ADR-0003 §4's "row removed in Postgres" trigger is replaced by a real event.
- **Negative / trade-offs**: one migration with a backfill and a dead table for one release; six store methods change name and shape, so every fake in `http` and `forget` tests is rewritten; the tenant listing changes shape (items gain `kind`/`cycle`, shred fields become optional) — check for external consumers before the PR; `KeyDestroyedSince` compares two sidecar-side clocks (`created_at` vs `destroyed_at`) — a record sealed within skew of the destroy can misread as an **alarm**, never as a hidden erasure (fails toward the visible error); un-forget and erase for the same subject at the same moment is an admin coordination problem — the ledger stays consistent (append-only, unique per act) and Redis converges on the next recalculate or heal.
- **Follow-ups / open threads**: drop `erasure_ledger` (migration 004, later release). **Tenant listing of the full event log** (every shred and un-forget) — deferred 2026-09-09; `GET /v1/erasures` stays "who is forgotten now." `cache_purged` is gone from the new table and the attestation — former [JIRA Tasks](../wiki/JIRA%20Tasks.md) Task 2 is folded here; note the retirement in DP-001's closure trail (field retired, not made honest). **Unverified until the integration test (Step 8 of the how-to):** keyvault mints a fresh subject key after a Transit destroy of the same subject name (D3 asserted it; nothing has exercised it since the forget set landed). R2 in-flight read ([Open Questions](../wiki/Open%20Questions.md) #6) and the company door (#7) are untouched.

### Proposed — confirm

1. **Locked:** kinds `destroyed` / `reappeared`. Door stays `/unforget`. `completed` deferred until a job exists.
2. New table `erasure_events` + backfill; `erasure_ledger` kept unwritten until migration 004.
3. `(company_id, subject_pseudonym, cycle, kind)` as the primary key; `cycle` computed inside the `INSERT … SELECT`.
4. `resolveUnopenable` asks `KeyDestroyedSince(record.CreatedAt)`, not "any destroyed event."
5. **Locked 2026-09-09:** `GET /v1/erasures` lists currently forgotten subjects in that tenant only. Full shred/un-forget history is later.
6. Un-forget response carries `cycle` + `unforgotten_at` only (the shred's dates are in the listing).
7. **Locked:** no `cache_purged` on `erasure_events` or on the HTTP attestation.

## Affected code

Grounding paths (repo `InveniamIndicia`, forget set already shipped):

| Path | What changes |
| ---- | ------------ |
| `internal/sidecar/store/migrations/003_create_erasure_events.up.sql` | New table + backfill (§1) |
| `internal/sidecar/store/erasure.go` | `ErasureEvent`, `EventKind`; six methods (§5); `SummarizeSubject` unchanged |
| `internal/sidecar/store/erasure_test.go` | Two cycles, retry idempotency, `KeyDestroyedSince` before/after, `ListForgotten` excludes un-forgotten |
| `internal/sidecar/forget/forget.go` | `Hydrator.ListForgotten`; `Recalculate`; `redisSet` + `Del`, `SetNX` |
| `internal/sidecar/forget/forget_test.go` | fake `Del`/`SetNX`; rebuild drops one, keeps other; lock held → error |
| `internal/sidecar/http/handler.go` | `ForgetSet.Recalculate` |
| `internal/sidecar/http/erasure.go` | `ErasureStore` + `UnforgetSubject`; listing still current-forgotten (add `cycle`, drop `cache_purged`) |
| `internal/sidecar/http/read.go` | `resolveUnopenable` → `KeyDestroyedSince(record.CreatedAt)` |
| `internal/sidecar/http/*_test.go` | `erasureLedger` fake rewritten over `[]store.ErasureEvent`; stubs grow `Recalculate` |
| `internal/sidecar/router.go`, `router_test.go` | `POST /v1/erasures/unforget` on the `company_admin` table |
| `tests/integration/sidecar_fulldata_test.go` | erase → un-forget → remint → erase again; sibling fence; old record `410` |
| `docs/api/API_SPECIFICATION.md`, D3, Slice 2b §8.2, explainer §8, DP-001, DP-002 | Listing shape, new door, re-appearance restored; **no** `cache_purged`; **no** "known limit" sentence |

## Related

- [Decision register](Inveniam%20Indicia%20(INV-42236)/decisions/INDEX.md)
- [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md) — §4 recalculate exception; R5 write order reused
- [Write the Un-forget](../wiki/Write%20the%20Un-forget.md) — how-to for this ADR; you write the Go
- [JIRA Tasks](../wiki/JIRA%20Tasks.md) — Task 1 (merged with former Task 4)
- [Open Questions](../wiki/Open%20Questions.md) — #5, #9 decided here
- [ADR-0003 Landing Review Findings](../wiki/ADR-0003%20Landing%20Review%20Findings.md) — Finding 2 (the interim this ADR exits)
- [Wiki Index](../wiki/index.md)
