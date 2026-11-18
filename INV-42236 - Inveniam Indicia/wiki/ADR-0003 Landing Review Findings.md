---
name: ADR-0003 Landing Review Findings
date: 2026-09-03T14:35:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - review
  - architecture
---

# ADR-0003 Landing Review Findings

**Summary**: Pre-implementation review (2026-09-03) of the plan to land [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) — the how-to is [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md). Six findings, checked against the repo docs tree (`trace-chain/InveniamIndicia/docs`, ~55 files) and the shipped sidecar code. **Self-contained on purpose**: every quote, path, and finding ID needed to discuss these is on this page — no re-reading of the repo docs required.

**Sources**: repo docs — `docs/plans/SECURITY_ASSESSMENT_2026-08-17.md`, `docs/plans/SECURITY_ASSESSMENT_2026-08-14_BACKLOG.md`, `docs/plans/DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md`, `docs/plans/SEPARATION_OF_CONCERNS_SLICE_2B_RECORD_STORE.md`, `docs/plans/CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md`, `docs/api/API_SPECIFICATION.md`, `docs/feature_summaries/IDEMPOTENCY.md`, `docs/new ideas/devops-datastore-recovery-playbook.md`, `docs/standards/CODING_STANDARDS.md`; code — `internal/sidecar/http/{erasure,handler,read}.go`, `internal/sidecar/store/erasure.go`, `internal/keyvault/cache.go`, `cmd/sidecar/main.go`.

**Last updated**: 2026-09-03 (all findings settled: 1 decided — #8; 2 → Task 1; 3 outdated → Task 2; 4 decided — 410 `subject_erased`, doc half → Task 3; 5 → Task 3; 6 naming decided — code says `forget`/`ForgetSet`, graveyard is vault prose only)

---

## Context in three sentences

ADR-0003 (Accepted 2026-09-03, not implemented) closes two post-erasure holes with a shared Redis forget-set checked at the sidecar's HTTP doors: **hole 1** — a sibling replica's warm DEK cache (`internal/keyvault/cache.go`, `NoopInvalidator`) still decrypts an erased subject's events; **hole 2** — ingest never consults the erasure ledger, so `EnsureSubjectKey` re-mints a key and new events for an erased person look first-time. The mechanism: Postgres `erasure_ledger` is durable truth; a Redis set on the sidecar's existing Redis (`INDICIA_SIDECAR_REDIS_ADDR`) is the hot list — erase writes Vault destroy → ledger insert → `SADD`; ingest and read check `SISMEMBER` before `SealEvent` / `OpenEvent`; empty Redis heals from Postgres (`SADD` on top, union only, never `SREM`). These findings are what a docs + code review surfaced **before** any code was written.

The two holes map exactly to the repo's security findings: hole 1 = **DATA-PROTECTION-001** (backlog twin `internal-keyvault-2`), hole 2 = **DATA-PROTECTION-002** (twin `internal-keyvault-3`), both in `SECURITY_ASSESSMENT_2026-08-17.md`.

---

## Finding 1 — Heal poisoning with a global key + per-company hydrate — **DECIDED**

**Status: decided 2026-09-03** ([Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) #8): keep one plain global set; heal hydrates **all** rows via a new store method `ListAllErasures(ctx)` (no company filter). No per-company key split — the forget-list is expected to stay small. Reopen #8 only if the set grows big enough that full hydrate hurts; per-company sharding (`sidecar:forgotten:{company_id}`, matching the `idem:{tenant}:` convention) is the known escape.

**The bug that forced the decision.** The draft heal used `ListErasures(companyID)` — the only listing the store has, and it is per-tenant. With one global key, walk a Redis flush with two tenants:

1. Redis flushed. Company A's request sees the empty set, heals **A's rows only**. The set is now non-empty.
2. Company B's request sees `SCARD > 0` → **heal never triggers for B**. B's forgotten members are missing from Redis indefinitely.
3. For B's erased subject: ingest remints (hole 2 back), and a warm sibling's `OpenEvent` **succeeds** from cache — so the Postgres fallback in `resolveUnopenable` never fires (it only runs on unwrap *failure*). Hole 1 back too.

**Why this was invisible in the ADR**: ADR-0003 R3 says "requery Postgres, `SADD` every graveyard row on top" — correct — but the store had no all-tenant query, and the draft quietly substituted the per-tenant one. The unit test pinning this: *heal restores every tenant's members, not just the caller's* (how-to Step 3).

---

## Finding 2 — Ingest refuse contradicts decision D3 — **DEFERRED to future work (2026-09-03)**

**Status: accepted as interim, resolved by the un-forget follow-up.** Decision (investigation owner, 2026-09-03): this is not part of the ADR-0003 change. Until un-forget ships, erasure behaves as a permanent processing ban for that identifier — old records unreadable (by design, irreversible) **and** no new key can be minted, because the ledger row / graveyard member blocks ingest. The exit is [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) #5; the JIRA-ready task is [JIRA Tasks](JIRA%20Tasks.md) Task 1, to be filed **after** the ADR-0003 PR merges. Residual risk: a reviewer citing D3 may still object to the interim state — point them at this finding and the drafted follow-up.

The strongest conflict in the repo docs. `docs/plans/DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md`, D3 note (verbatim):

> "erasure survives re-appearance — a later lawful event for the same subject mints a fresh key; old records fail unwrap (`erased`, via ledger), new records unwrap (live). GDPR erasure ≠ do-not-track."

Reinforced twice more:

- `docs/plans/SEPARATION_OF_CONCERNS_SLICE_2B_RECORD_STORE.md` §8.2 records remint as an **accepted limitation**: "An erased subject re-provisions on write… GDPR-correct — erasure is not a processing ban."
- `docs/plans/CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md` §8 makes the same policy statement.

Then the security assessment (2026-08-17, **after** D3) flagged remint as DATA-PROTECTION-002 with three remediation options: "refuse writes **or** require explicit re-consent/un-erase **or** at minimum flag/audit re-provisioning." ADR-0003 picked **refuse**, with un-forget parked as [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) #5.

**The tension**: refuse-without-un-forget is *stricter than GDPR requires* and reverses D3's written policy. A person erased once can never lawfully appear again until Open Questions #5 ships. A reviewer citing D3 can bounce the landing PR.

**Resolution taken (2026-09-03)**: "refuse now, un-forget later" — the un-forget feature restores lawful re-appearance as an explicit admin action instead of D3's silent remint. Task drafted: [JIRA Tasks](JIRA%20Tasks.md) Task 1 (covers the D3 / Slice 2b §8.2 / compliance explainer doc updates too). The rejected alternative (downgrade ingest to flag/audit-only) would have satisfied D3 as written but left hole 2 open — that would have been a different ADR-0003.

One nuance kept for the compliance conversation: the pseudonym is a deterministic per-tenant HMAC, so the ban is really on the *identifier*, not the human. Same person re-registered under the same `user_id` → same pseudonym → blocked; re-onboarded under a different `user_id` → fresh pseudonym → ingest works.

---

## Finding 3 — `cache_purged: true` stays dishonest — **OUTDATED (2026-09-03)**

**Status: outdated by decision** (investigation owner, 2026-09-03) — we no longer relate to this field at all. ADR-0003 already pinned "`cache_purged` is still not the control plane"; after the graveyard lands, the erasure signals that matter are the ledger row and the Redis member. **2026-09-08:** retirement folded into [JIRA Tasks](JIRA%20Tasks.md) Task 1 / [ADR-0004](../decisions/ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) — `erasure_events` has no column; the attestation JSON drops the key. DP-001 closure: retired, not made honest.

Original evidence, kept for the record. DP-001's exact remediation (`SECURITY_ASSESSMENT_2026-08-17.md`):

> "Wire the planned Slice 2c cross-instance invalidator; until then pin to one replica and **do not assert `cache_purged: true` without an acknowledged broadcast purge**."

The erasure attestation (regulator-facing, `internal/sidecar/http/erasure.go` → `erasure_ledger.cache_purged`) reports `cache_purged: true` today, but only the **local** replica's DEK cache is dropped (`Eraser.EraseSubject`); siblings keep warm DEKs (`NoopInvalidator` in `internal/keyvault/cache.go`). ADR-0003 does **not** add the acknowledged broadcast (ADR-0001 is superseded) — it makes the cached DEKs *unreachable through the doors* instead of evicted. If DP-001's closure review asks about the field: the answer is that it was retired with the event-log remodel (Task 1 / ADR-0004), and the erasure guarantee is the door fence, not RAM eviction — ADR-0003's consequence line already concedes "We still do not attest 'every process zeroized.'"

---

## Finding 4 — Ingest status code is new API contract — **DECIDED: 410 `subject_erased`; doc half → Task 3**

**Status (2026-09-03)**: decided — **`410 Gone` + error code `subject_erased`** (investigation owner delegated; rationale: the read door already answers 410 `erased` for the same fact; 410 means "gone, likely permanent," matching the interim ban; 403 is taken by the tenant mismatch and overloading it forces body-parsing to tell authorization from resource state). Documenting it in `API_SPECIFICATION.md` (plus the drifted ingest error table) is [JIRA Tasks](JIRA%20Tasks.md) **Task 3**. The refusal `Warn` log stays in the landing PR code.

What `docs/api/API_SPECIFICATION.md` documents today:

- **Read door**: `410 erased` vs `404 not_held`; `500 content_mismatch`; `503 store_failed`. Verify: all four verdicts as HTTP `200`.
- **Ingest door** (`POST /v1/events`): only validation errors (`validation_failed`, `unknown_event_type` 400, `validation_unavailable` 500). **No** erased-subject semantics exist. Even `seal_failed` (which the code returns) is undocumented — the ingest error table already drifts from the code.
- Ingest code already uses `403 forbidden` for a company-id mismatch (`decodeRequest` in `internal/sidecar/http/handler.go`).

**The choice**: refusing an erased subject's ingest needs a status code. Candidates: `410 Gone` (rhymes with the read door's `erased`) or `403` with a distinct code like `subject_erased` (but 403 is already taken by the tenant mismatch — the JSON `error` code must differ). Either works; it must be added to `API_SPECIFICATION.md` in the landing PR, and fixing the drifted ingest error table at the same time is cheap.

Also from the review: log the refusal at `Warn` with `company_id` + `subject_pseudonym` only (never raw `user_id`). DP-002's backlog explicitly wants a signal on post-erasure write attempts — today there is none — and one log line satisfies the "flag/audit" remediation option for free.

---

## Finding 5 — Redis moves onto the read path — **moved to JIRA (Task 3)**

**Status (2026-09-03)**: the ops/API documentation work (new 503 cause on read/verify, recovery-playbook heal notes) is drafted as [JIRA Tasks](JIRA%20Tasks.md) **Task 3** — file alongside the landing PR. Evidence kept below.

Today a Redis outage breaks ingest (idempotency middleware answers 503 — sidecar refuses to start without `INDICIA_SIDECAR_REDIS_ADDR`, per `docs/guides/ENVIRONMENT_VARIABLES.md`), but **reads and verify still work**. After ADR-0003, `GET`/verify also answer **503 when Redis is down** — correctly, because failing open reopens both holes ("guessing not-forgotten is how hole 2 returns").

What the ops docs don't know:

- `docs/new ideas/devops-datastore-recovery-playbook.md` treats `FLUSHDB`/`FLUSHALL` as disposable-env-only and has **no heal concept**. After ADR-0003 a flush is *recoverable by design* — the graveyard heals from `erasure_ledger` on the next request. The playbook should say so, or a Redis failover becomes a mystery incident.
- `API_SPECIFICATION.md` read/verify error sections need the new 503 cause.

Related trade already conceded in ADR-0003's consequences: "every content read/write hits Redis (sidecar already depends on it)."

---

## Finding 6 — Smaller items — **folded into the how-to**

- **Cross-replica integration test is the proof.** Unit fakes cannot demonstrate the sibling story. `tests/integration/sidecar_fulldata_test.go` already builds two handler stacks against one real Redis — erase via handler A, then read **and** ingest via handler B, assert `erased`/refused. This is the test that actually closes DP-001. Add a flush-then-heal case.
- **Lint gate**: `docs/standards/CODING_STANDARDS.md` pins golangci-lint **v2.12.2** and `make lint` / `make check-all`; `go vet` alone is not what CI runs.
- **Interface naming**: **decided 2026-09-03**, concrete type **renamed 2026-09-07** — package `forget`, concrete `forget.Subjects` (names the members; `Set` was too generic), consumer interface `ForgetSet`, methods `MarkForgotten`/`IsForgotten`. Rationale: “graveyard” in GDPR-erasure code reads as gallows humor to auditors. `ForgetSet` is a noun-phrase rather than the standards’ `-er` form; the defense is that it names the capability the door needs and matches ADR-0003. Metaphor stays in the vault prose only. See how-to Step 1 naming note.
- **Two Redis round trips** per request (`SCARD` then `SISMEMBER`): fine for the first PR; go-redis pipelining folds them later.

---

## What the docs exploration confirmed (no action, useful for discussion)

- **No repo doc describes a forget-set.** The documented DP-001 fix was Redis **pub/sub** into the keyvault `Invalidator` seam (evict sibling caches). ADR-0003 is a *different mechanism* — fence at the doors instead of evict — chosen deliberately (no purge event, no ack protocol). Anyone citing the assessments' "wire the pub/sub invalidator" is reading the pre-ADR-0003 plan.
- **Verify "no cache" (D2)** forbids caching verify *results* — it does not forbid a Redis membership check on the verify path. No conflict.
- **RBAC unchanged**: erasure door stays `company_admin` + `requireTenant` (D3a/D5); this feature adds no new roles or doors.
- **Redis key conventions** in the repo: `idem:{tenant}:{key}`, TTLs 30s inflight / 24h complete (`docs/feature_summaries/IDEMPOTENCY.md`). The forget-set is the first *unexpiring* sidecar key — deliberate: a graveyard must not TTL out.
- **Idempotency replay edge**: a replayed pre-erase ingest request within the 24h idempotency window returns the cached `202` without reaching the handler or the fence. No plaintext leak (content was sealed pre-erase, key now destroyed); noted for completeness, not worth code.

## Scoreboard

| # | Finding | Status | Where it lives |
| - | ------- | ------ | -------------- |
| 1 | Heal poisoning (global key + per-company hydrate) | **Decided** — `ListAllErasures`, global key | [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) #8; ADR-0003 R3 note; how-to Step 2 |
| 2 | Ingest refuse vs D3 "re-appearance" policy | **Deferred — future work; JIRA drafted** | [JIRA Tasks](JIRA%20Tasks.md) Task 1; [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) #5 |
| 3 | `cache_purged` honesty (DP-001 wording) | **Outdated — field retired in Task 1 / ADR-0004 (not made honest)** | [JIRA Tasks](JIRA%20Tasks.md) Task 1 |
| 4 | Ingest status code + refusal log | **Decided — 410 `subject_erased`**; doc half → Task 3 | how-to Step 6; [JIRA Tasks](JIRA%20Tasks.md) Task 3 |
| 5 | Redis on the read path — ops/API docs | **Moved to JIRA — Task 3** (file alongside landing PR) | [JIRA Tasks](JIRA%20Tasks.md) Task 3 |
| 6 | Integration test, lint gate, naming, pipelining | Folded into the how-to; **naming decided** — `forget.Subjects` / `ForgetSet` / `MarkForgotten` / `IsForgotten` | how-to Steps 1, 9, 10 |

## Related pages

- [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md) — the how-to these findings amended
- [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) — #5 un-forget, #6 R2 window, #7 company door, #8 heal scope (decided)
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](TOCTOU.md)
- [Wiki Index](INV-42236%20-%20Inveniam%20Indicia/wiki/index.md)
- [Decision register](../decisions/INDEX.md)
