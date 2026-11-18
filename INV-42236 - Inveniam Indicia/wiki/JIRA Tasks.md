---
name: JIRA Tasks
date: 2026-09-03T14:42:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - task
  - jira
---

# JIRA Tasks

**Summary**: Register of JIRA-worthy follow-up tasks that come out of this investigation but are **not** part of the current change (the person-erase forget-set landing). Each task is self-contained — copy its block into JIRA as-is. Add new tasks as sections; update the status line when a task is filed (record the INV number) or done. Do not put vault ADR ids, decision links, or the vault metaphor “graveyard” into JIRA — those stay in this vault.

**Sources**: [Landing Review Findings](ADR-0003%20Landing%20Review%20Findings.md); repo docs `docs/plans/DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md` D3, `docs/plans/SEPARATION_OF_CONCERNS_SLICE_2B_RECORD_STORE.md` §8.2, `docs/plans/CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md` §8, `docs/plans/SECURITY_ASSESSMENT_2026-08-17.md` DP-001/DP-002.

**Last updated**: 2026-09-08 (kinds locked: `destroyed` / `reappeared`; door stays un-forget)

---

## Register

| # | Task | Origin | When to file | Status |
| - | ---- | ------ | ------------ | ------ |
| 1 | Un-forget: restore lawful subject re-appearance; erasure ledger becomes a lifecycle event log | [Findings](ADR-0003%20Landing%20Review%20Findings.md) Finding 2; [Open Questions](Inveniam%20Indicia%20(INV-42236)/wiki/Open%20Questions.md) #5 #9; [ADR-0004](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) | After the person-erase forget-set PR merges | drafted |
| 2 | ~~Retire `cache_purged`~~ | [Findings](ADR-0003%20Landing%20Review%20Findings.md) Finding 3 | — | **merged into Task 1** (2026-09-08): the new table and the attestation JSON omit the field; DP-001 closure is "retired, not made honest" |
| 3 | Update repo docs for the person-erase forget-set change (API spec + ops playbook) | [Findings](ADR-0003%20Landing%20Review%20Findings.md) Findings 4 (doc half) and 5 | Alongside the landing PR — same release, ideally same PR | done (docs in repo 2026-09-08; ship with the landing PR) |
| 4 | ~~Erasure ledger v2~~ | — | — | **merged into Task 1** (2026-09-08): shipping the interim `unforgotten_at` flag and removing it later was pure rework; no deadline pressure justified the split |

---

## Task 1 — Un-forget: restore lawful subject re-appearance; erasure ledger becomes a lifecycle event log

**Status**: drafted. **File after** the person-erase forget-set change merges ([Write the Person Graveyard](Write%20the%20Person%20Graveyard.md)). Blocked-by relationship in JIRA: this task depends on that PR. Do not start it in the same PR — the landing change pins the forget set as append-only and forbids shrink.

**Design:** [ADR-0004 Erasure Ledger as Lifecycle Event Log](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) (Proposed — see its "confirm" list). **How-to (you write the Go):** [Write the Un-forget](Write%20the%20Un-forget.md).

**Scope history (2026-09-08).** First draft split this into two tickets: Task 1 lifted the ingest ban with a nullable `unforgotten_at` on the one-row-per-subject ledger and documented the "second shred keeps the first shred's dates" lie; Task 4 fixed the lie later with an event-log remodel. **Merged the same day**: the flag was not a stepping stone but a dead end the remodel would remove (migration, `Supersede`/`Reactivate`, a spec caveat, their tests), and nobody was waiting on the ban alone. One ticket, done once, honestly. The split's only justification would have been deadline pressure on lifting the ban; none exists.

### Copy into JIRA

#### Title

Un-forget: restore lawful subject re-appearance; erasure ledger becomes a lifecycle event log

#### Description

**Background.** The person-erase forget-set change (INV-42236) closed two post-erasure holes: a sibling replica's warm DEK cache could still decrypt an erased subject's old events, and ingest re-minted a key for an erased subject so new events looked first-time. The fence: Postgres `erasure_ledger` row + member in a shared Redis set (`sidecar:forgotten`), checked with `SISMEMBER` before `SealEvent` (ingest) and `OpenEvent` (read). The set is append-only; nothing removes members.

**The deliberate side effect this task removes.** Decision D3 (`docs/plans/DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md`) documented: "erasure survives re-appearance — a later lawful event for the same subject mints a fresh key; old records fail unwrap (`erased`, via ledger), new records unwrap (live). GDPR erasure ≠ do-not-track." After the forget set landed, that is no longer true: an erased subject is **refused at ingest forever** — GDPR erasure currently behaves as a permanent processing ban for that identifier, which is stricter than GDPR requires. This was accepted knowingly as an interim state (investigation INV-42236, 2026-09-03), with this task as the exit.

**Why the ledger changes shape in the same ticket.** `erasure_ledger` is one row per `(company_id, subject_pseudonym)`: valid while a subject can be erased exactly once. Un-forget makes a **second** erase possible, and one row cannot date two shreds — any flag-based design either misdates the second shred or rewrites the first (both wrong on a regulator artifact), and puts an `UPDATE` on a table whose value is that nothing updates it. So the ticket replaces the table with an append-only lifecycle log and builds un-forget on top.

**What to build.**

1. **New table `erasure_events`** (sidecar migration + backfill of existing rows): one row per act, `(company_id, subject_pseudonym, cycle, kind)` unique, `kind ∈ destroyed | reappeared`, `occurred_at`, `completion_by` on `destroyed` events. **No `cache_purged` column** — the old field attested a fleet-wide RAM drop that never happens; the door fence is the guarantee. Nothing ever UPDATEs or DELETEs a row. Cycle 0 is the first shred; an un-forget of cycle n writes `reappeared` and is followed by a destroy of cycle n+1 **with its own dates**. Existing `erasure_ledger` is backfilled as cycle 0 (without the old flag), left unwritten, dropped in a later release.
2. **Un-forget door** `POST /v1/erasures/unforget` (body `{"user_id": …}`, pseudonymized in-handler, never persisted or logged — same rule as erase): append the `reappeared` event for the current cycle, then **recalculate** the Redis forget-set from the subjects whose latest event is `destroyed` (drop the key, `SADD` each, under a lock). Recalculate is the single allowed exception to "never delete or replace the set"; routine heal stays union-only. Codes: `200` (with `already_unforgotten` on re-POST), `404 not_erased`, `503 unforget_incomplete` (event appended, Redis rebuild failed — re-POST retries the rebuild only).
3. **Erase on the new table**: append the next cycle's `destroyed` event. Retry idempotency stays a unique-key conflict (a re-POST returns the incumbent event's original dates). A second erase after un-forget produces a **new attestation with its own `destroyed_at` / `completion_by`** and re-adds the Redis member.
4. **Read/verify honesty**: an unwrap failure resolves as `erased` only when a `destroyed` event exists **at or after the record's creation** — after an un-forget and remint, a broken new record is an integrity alarm, not a lawful erasure. Old records stay `erased` forever; the old key is destroyed and that is irreversible by design.
5. **Tenant listing**: `GET /v1/erasures` stays "who is forgotten right now in this tenant" (latest shred only). After un-forget the subject is absent; after a second erase they return with that shred's dates. A history of shreds and un-forgets is later work — do not build it here.

**Access control.** At least `company_admin` + tenant scoping (same as the erase door); consider requiring a stronger role or two-step confirmation — un-forget reverses a compliance action.

**Docs to update in the same change.**
- `docs/plans/DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md` D3 note — re-appearance is restored, now via explicit un-forget instead of silent remint.
- `docs/plans/SEPARATION_OF_CONCERNS_SLICE_2B_RECORD_STORE.md` §8.2 and `docs/plans/CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md` §8 — same policy statement; explainer also gets the per-cycle attestation.
- `docs/api/API_SPECIFICATION.md` — new endpoint; ingest behavior after un-forget; attestation gains `cycle`; listing stays currently-forgotten subjects (check consumers if `cycle` is added).
- Close the remint remediation trail: `SECURITY_ASSESSMENT_2026-08-17.md` DP-002 offered "refuse OR re-consent/un-erase" — this task delivers the re-consent path on top of refuse.
- DP-001 closure: `cache_purged` is retired from the attestation (not made honest). The erasure guarantee is the door fence, not RAM eviction.

#### Acceptance criteria

- [ ] Migration creates the event log and backfills every existing erasure as cycle 0 without losing or re-dating any attestation; nothing writes the old table afterwards.
- [ ] Un-forget endpoint appends the lifecycle event for one subject in one tenant; raw `user_id` is pseudonymized in-handler and never persisted or logged; the action is audit-logged (pseudonym only); RBAC enforced.
- [ ] Redis set is recalculated from the "latest event is destroyed" feed; two concurrent recalculates must not lose members (lock); heal reads the same feed and remains union-only — after a flush, an un-forgotten subject stays off the set and a re-erased one comes back.
- [ ] After un-forget: ingest for that subject succeeds and mints a fresh key; new events seal and read normally.
- [ ] Erase → un-forget → erase produces two `destroyed` events with their own `destroyed_at` / `completion_by`; the listing hides the subject after un-forget and shows them once after the second erase (`cycle` 1); the subject is fenced again (ingest `410`).
- [ ] Retry of any erase or un-forget appends nothing and returns the incumbent event's original dates.
- [ ] Read/verify: unwrap failure on a record created before a shred answers `erased`; unwrap failure on a record created after the latest shred (e.g. post-remint) raises the integrity alarm. Both tested.
- [ ] Cross-replica integration test: erase → un-forget → ingest succeeds on a sibling replica; unrelated forgotten subjects stay forgotten through the recalculate.
- [ ] Attestation and listing JSON have no `cache_purged`; API spec and DP-001 trail say the field was retired.
- [ ] The five repo docs above updated in the same PR.

#### Out of scope

- Company/tenant offboard door and tenant walk (Open Questions #7).
- Closing the R2 in-flight read window (Open Questions #6).
- Any change to Vault key destruction — old keys stay destroyed; un-forget never resurrects old content.
- A `completed` lifecycle event (only honest once a job appends it; until then `completion_by` stays a field on the destroy event).
- Dropping the old `erasure_ledger` table (follow-up migration after one release of verification).
- Making `cache_purged` honest (acknowledged broadcast) — the field is gone, not repaired.

### Why the read-semantics acceptance criterion is the tricky one

Today `resolveUnopenable` (`internal/sidecar/http/read.go`) uses the ledger row to distinguish a lawful erasure from an integrity alarm: unwrap failure **with** a row → `erased`; **without** a row → alarm ("a subject key vanished without an erasure behind it"). Un-forget breaks the binary twice over: hard-deleting history would turn every old record into a false alarm, and "any destroyed event exists" would do the opposite — after a remint, a genuinely broken **new** record would be filed as `erased` forever. The event log answers with a timestamp comparison instead: shredded **at or after this record's creation** → `erased`; otherwise → alarm. Clock skew between the two sidecar timestamps fails toward the visible alarm, never toward a hidden erasure.

---

## Task 2 — Retire the `cache_purged` attestation field

**Status**: **merged into Task 1** (2026-09-08). Task 1 already rebuilds the attestation table and JSON; carrying the field onto `erasure_events` would keep the DP-001 lie on a new artifact. The new table has no column; the door does not emit the key. DP-001's closure trail (in Task 1's docs) is "retired, not made honest."

---

## Task 3 — Update repo docs for the person-erase forget-set change (API spec + ops playbook)

**Status**: done in the app repo on 2026-09-08 (`docs/api/API_SPECIFICATION.md`, `docs/new ideas/devops-datastore-recovery-playbook.md`). **Ship alongside** the person-erase forget-set landing PR — the docs describe behavior that changes the moment the code merges, so same release, ideally the same PR. If tracked separately in JIRA, link it to the landing task so it cannot slip a release.

### Copy into JIRA

#### Title

Docs: API spec and ops playbook updates for the person-erase forget-set change

#### Description

**Background.** The person-erase forget-set change (INV-42236) adds a shared Redis forget-set checked at the sidecar's HTTP doors: ingest (`POST /v1/events`) and content read/verify now consult `SISMEMBER` before `SealEvent` / `OpenEvent`. Two documents describe the old world and must be updated with the code.

**1. `docs/api/API_SPECIFICATION.md`**

- **Ingest, erased subject**: `POST /v1/events` gains a new refusal — an event whose data subject is in the forget set is not sealed and no key is minted. Answer: **`410 Gone`, error code `subject_erased`** (decided 2026-09-03 — matches the read door's 410 `erased`; 403 was rejected as already taken by the tenant mismatch). Include: the refusal is per-identifier and permanent until the un-forget feature ships.
- **Read/verify, new 503 cause**: `GET`/verify now answer `503` when Redis is unreachable (fail closed — guessing "not forgotten" would reopen the erasure holes). Add to the existing 503 causes (`store_failed`, `key_backend_unavailable`); a caller must be able to tell "we could not check" from a content verdict.
- **Ingest error table drift (pre-existing)**: the spec documents only validation errors for ingest; the code also returns `seal_failed`, `store_failed`, `core_rejected`, `core_unavailable`, `payload_too_large`, `pseudonymization_failed`. Fix the table while in the file.

**2. `docs/new ideas/devops-datastore-recovery-playbook.md`**

- Redis is now on the sidecar's **read path**, not just ingest idempotency: a Redis outage 503s content GET/verify by design. Name the symptom so a failover is not diagnosed as a sidecar bug.
- A Redis flush is **recoverable by design** for the forget-set: it heals from Postgres `erasure_ledger` on the next request (`SADD` on top, union only). The playbook's "FLUSHDB is disposable-env only" stance stays true for streams/idempotency; the forget-set is the exception that self-heals.
- Note the one residue window: a ledger row whose `SADD` has not happened yet is invisible to siblings until the erase re-POST or a heal — same class as the accepted in-flight-read window.

#### Acceptance criteria

- [x] API spec documents the erased-subject ingest refusal (`410` / `subject_erased`), and states it is permanent until un-forget.
- [x] API spec read/verify sections list Redis unavailability as a 503 cause distinct from content verdicts.
- [x] Ingest error table matches the handler's actual error codes.
- [x] Recovery playbook explains: Redis on the read path (outage symptom), forget-set heal-on-flush, and the SADD-lag residue window.
- [x] No doc claims sibling RAM is evicted on erase — the guarantee is the door fence (`cache_purged` retirement ships with Task 1).

#### Out of scope

- D3-family policy docs (`DECISION_SET_2026-08-10` D3, Slice 2b §8.2, compliance explainer §8) — those move when un-forget restores re-appearance (Task 1).
- `cache_purged` retirement (folded into Task 1).

---

## Related pages

- [Landing Review Findings](ADR-0003%20Landing%20Review%20Findings.md) — Findings 2 and 3 (both Task 1)
- [ADR-0004 Erasure Ledger as Lifecycle Event Log](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) — Task 1 design (Proposed)
- [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md) — the change these tasks follow
- [Write the Un-forget](Write%20the%20Un-forget.md) — Task 1 how-to
- [QA Person Graveyard](QA%20Person%20Graveyard.md) — API-call script for QA after the landing PR
- [Open Questions](Inveniam%20Indicia%20(INV-42236)/wiki/Open%20Questions.md) — #5 (Task 1), #6, #7
- [Wiki Index](Inveniam%20Indicia%20(INV-42236)/wiki/index.md)
