---
name: ADR-0003 Shared Redis Forget Set
date: 2026-09-03T14:38:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - adr
  - architecture
---

# ADR-0003 Shared Redis Forget Set

- **Status**: Accepted
- **Date**: 2026-09-03
- **Area**: sidecar / keyvault
- **Deciders**: investigation owner (accepted 2026-09-03). Not implemented yet.
- **Pinned**: R1 + R4 approved (`SADD` only, never replace the key). **R5 split:** erase **write** = Postgres first, then `SADD`; **read**/ingest check = Redis first (heal if empty). **Tenant walk / company door:** out of this feature ([Open Questions](../wiki/Open%20Questions.md) #7); §3b is the later contract. Redis forget-set is **append-only**; full recalculate only if a graveyard row is removed in Postgres (post-2c, [Open Questions](../wiki/Open%20Questions.md) #5). R2 accepted for 2c as one in-flight read — tighten-or-not is [Open Questions](../wiki/Open%20Questions.md) #6. R3 = **heal on empty** (Postgres → `SADD` on top, then continue) — heal hydrates **all** rows via new `ListAllErasures` (one global key confirmed; [Open Questions](../wiki/Open%20Questions.md) #8 decided, review note under R3).
- **Related**: Supersedes [ADR-0002 Forget Table Before Cache](ADR-0002%20Forget%20Table%20Before%20Cache.md) and [ADR-0001 Acknowledged Sidecar Cache Purge](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md). [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md), [TOCTOU](../wiki/TOCTOU.md), [Open Questions](../wiki/Open%20Questions.md) #2 #5 #6 #7

## Context

[ADR-0002](ADR-0002%20Forget%20Table%20Before%20Cache.md) put “forgotten” in Postgres, copied it into each replica’s RAM, and used a Redis **nudge** so siblings reload. The nudge is extra machinery. The forget-set itself can live in the Redis **all sidecar replicas already share** (`INDICIA_SIDECAR_REDIS_ADDR` — idempotency; sidecar will not start without it). Then every request asks one shared set. No event.

Risk the operator named: a **new replica** starting against an already-forgotten world must not **overwrite** that set with empty.

Two holes still apply: stale DEK RAM (hole 1) and remint-as-first-time (hole 2). List-before-cache on the shared set addresses both on the HTTP doors.

## Decision

**Postgres keeps the durable forget-row (attestation / hydrate). Redis holds the hot set. Members are only added (`SADD`). Nobody replaces the key from process memory. No purge event.**

### 1. Two stores, two jobs

| Store | Job |
| ----- | --- |
| Postgres `erasure_ledger` / future `purged_tenants` | Durable truth, regulator row, source to **hydrate** Redis |
| Redis **set** (one key, e.g. `sidecar:forgotten`) | Shared hot list every replica checks |

Person member: `company_id` + `subject_pseudonym`. Company member: `company_id` only (tenant door). Same granularity rule as ADR-0002: do not put a company id on the set for “forget Alice.”

`cache_purged` is still not the control plane.

### 2. Erase path (no broadcast)

Replica that got the API call:

1. Vault disable/destroy (existing library).
2. **Insert Postgres row first** (durable graveyard + hydrate source). If this fails, stop — do not `SADD`. HTTP erase fails (503).
3. **`SADD` the member** (siblings refuse write/decrypt on the next request).
4. Drop **this** process’s DEK / pseudonym cache for that id.

Siblings are not told. Their next GET/POST sees Redis.

**R5 pinned (corrected):** **Write** = Postgres first, then Redis. **Read** = Redis first (`SISMEMBER` before cache; R3 heal if the set is empty). If Postgres is down, erase never `SADD`s — no “forgotten only in Redis” residue after a flush. Crash after the row and before `SADD`: ledger has Alice, Redis does not — **healable** (R3 if the set is empty, or routine `SADD` on top from Postgres).

### 3. List before cache

Every ingest and every content read, **in this order**, before `unwrapDEK` / `subjectDEK` / `cache.get`:

1. **Company** in the graveyard? → refuse / `erased`. Do not mint. Drop local unlock-codes for that company if we bother (or drop on the next per-id hit).
2. **Person** in the graveyard? → same for that person only.

On hit: do not `put`. Write → refuse. Read → `erased` (process-as-is).

### 3b. Tenant walk (TOCTOU) — same graveyard, company first — **out of this feature**

Forgetting a **company** used to need a separate “freeze writes, then list, then destroy.” The freeze **is** the company member.

**Not in this feature.** No company HTTP door, no `purged_tenants` wiring, no walk. This section is the contract **when** that door is scheduled ([Open Questions](../wiki/Open%20Questions.md) #7). This feature lands the graveyard for **person** erase only (already-shipped `POST /v1/erasures`).

Order when #7 is built:

1. Postgres `purged_tenants` row for `company_id` (R5 write first).
2. `SADD` the **company** member.
3. **Then** `ListSubjectKeys` and disable/destroy each person.

Ingest after step 2: check **company** first → no new person. Person erase must **not** `SADD` the company.

### 4. New replica / empty Redis — never overwrite

The set is **append-only** from the app’s point of view.

| Allowed | Forbidden |
| ------- | --------- |
| `SADD` one member | `SET` a JSON snapshot from this process |
| If key **missing** or empty after flush: `SADD` every row from Postgres | `DEL` then rewrite from local empty state |
| Two hydrators at once: both `SADD` from DB (union) | Read-modify-write of one blob |

Startup: **read** Redis. If the key exists and is non-empty, do not write it. If it is missing or empty: **heal** (R3) — Postgres rows + `SADD` on top. Same on any later request that sees an empty graveyard.

**Append-only graveyard (pinned).** The Redis set is a **graveyard index**: members are only added. No `SREM`, no `DEL` of a member, no “edit” of a forgotten id. Routine repair is: requery Postgres (`erasure_ledger` / `purged_tenants`) and **`SADD` on top of whatever is already in Redis** (union). Never subtract during hydrate.

The only time we **recalculate** the Redis set (drop the key and `SADD` every current graveyard row) is if a company/tenant (or person) row was **removed from Postgres**. That is a deliberate un-forget / admin edit of the graveyard, not the erase path. Until that happens, Redis may be a **subset** of Postgres (row landed, `SADD` not yet). Routine sync / R3 heal only **adds**. Recalculate is how a removed graveyard row is allowed to disappear from Redis.

**Out of Slice 2c.** Recalculate / un-forget is a **dedicated follow-up feature**, not part of landing 2c. 2c only **appends** (erase → ledger insert → `SADD`). Do not implement shrink in the 2c PR. Do not lose the idea: [Open Questions](../wiki/Open%20Questions.md) #5.

Sidecar replicas are assumed to share **one** Redis. A replica pointed at a different Redis will not see the set; Postgres + hydrate is the fallback, not a second forget-world.

## Races

### R1 — New replica overwrites the set — **approved**

Never replace the key on the erase or hydrate path. Only `SADD`. Tests must forbid a full-key write except the **graveyard-removed recalculate** (admin): then, and only then, rebuild from the current Postgres rows.

### R2 — Check Redis, then use the DEK cache — **ok for 2c; open question #6**

GET checks Redis (Alice not yet there). Erase lands (`SADD`). GET continues, **cache hit**, returns plaintext. One request window. Not closed by a shared set.

**2c accepts this:** forget is honest on the **next** request. Do not take the per-subject lock on read for 2c. Whether we later close the window (lock erase vs open) is [Open Questions](../wiki/Open%20Questions.md) #6 — park it, do not lose it.

### R3 — Redis empty after flush / failover — **heal, then continue**

If a replica sees the graveyard key **missing or empty** while checking: **heal**. Requery Postgres, `SADD` every graveyard row **on top** of Redis (union, same as routine sync). Then continue the request (re-check `SISMEMBER`). Not 503.

> **Review note (2026-09-03, pre-implementation):** with **one global key**, “heal on empty” is unsound if the hydrate query is per-company (`ListErasures(companyID)` — the only listing the store had). The first tenant’s heal makes the set non-empty; every other tenant’s heal never triggers; their forgotten members stay missing and both holes reopen (a warm sibling’s `OpenEvent` succeeds, so the ledger fallback never fires).
>
> **Decided 2026-09-03 ([Open Questions](../wiki/Open%20Questions.md) #8):** keep the **one global key** as pinned in §1. Heal hydrates **all** graveyard rows via a new store method `ListAllErasures` (no company filter). No per-company key split — the forget-list is expected to stay small. If it ever grows big enough that full hydrate hurts, reopen #8 (per-company sharding is the known escape). Details: [Write the Person Graveyard](../wiki/Write%20the%20Person%20Graveyard.md) §5.

Empty after a flush and empty because nobody is forgotten look the same; heal is cheap when Postgres is empty (`SADD` of zero rows). Two replicas healing at once is R4 (approved).

**Residue (R5, after the split):** erase does not `SADD` until the ledger row exists. Heal from Postgres can always rebuild what erase has committed. The leftover window is only **row exists, `SADD` not yet** — siblings may miss Alice until `SADD` or a heal. That is the in-flight erase, same class as R2.

### R4 — Two hydrators at once — **approved**

Same rule as R1. Both only `SADD` → union. `DEL`+rewrite is forbidden.

### R5 — Redis vs Postgres order — **pinned: write Postgres first; read Redis first**

Earlier draft said `SADD` then ledger. That mixed up **read** (always Redis / heal) with **erase write**.

**Erase:** ledger insert → `SADD`. No Redis member without a row. Postgres down → 503, no `SADD`.

**Read / ingest:** `SISMEMBER` Redis before cache. Empty set → heal from Postgres (R3).

## Alternatives considered

- **ADR-0002 nudge + per-process copy** — works; extra channel and a stale-copy problem. Rejected as the primary path now that the list can be the shared Redis the sidecar already requires.
- **ADR-0001 ack-all DEK drops** — stronger RAM-empty bar. Still optional hardening, not this ADR.
- **Redis as the only store (no Postgres row)** — flush loses “forgotten.” Rejected. Ledger already exists for people.
- **JSON `GET`/`SET` of the whole list** — classic lost-update (R1/R4). Rejected.
- **Indicia `events:stream` as notify** — still unnecessary if the set is shared.

## Consequences

- **Positive**: no purge event; no per-replica forget-map; hole 2 is `SISMEMBER` on ingest; hole 1 on the API is `SISMEMBER` before cache. New replica cannot wipe the list if it only `SADD`s. Hydrate from a table we already have.
- **Negative / trade-offs**: every content read/write hits Redis (sidecar already depends on it). R2 (in-flight cache hit) remains, parked as #6. R3 heal adds a Postgres read when Redis is empty (thundering herd is R4 / `SADD` only). Unlock-codes still sit in RAM until a request for that id runs the check-and-drop. We still do not attest “every process zeroized.”
- **Follow-ups:** R2 tighten ([Open Questions](../wiki/Open%20Questions.md) #6). **Un-forget + Redis recalculate** — after this feature ([Open Questions](../wiki/Open%20Questions.md) #5). **Company HTTP door** — out of this feature ([Open Questions](../wiki/Open%20Questions.md) #7).

## Affected code

Nothing shipped yet. Grounding:

| Path | What this decision touches |
| ---- | -------------------------- |
| sidecar Redis client (idempotency) | New set key; `SADD` / `SISMEMBER`; no pub/sub required for forget |
| `internal/sidecar/store/erasure.go` | Still the durable row; hydrate source — needs new `ListAllErasures` (all tenants) for R3 heal ([Open Questions](../wiki/Open%20Questions.md) #8) |
| `internal/sidecar/http/handler.go` | Ingest: Redis member check before `SealEvent` |
| `internal/sidecar/http/read.go` | Read: Redis member check **before** `OpenEvent` |
| `internal/sidecar/http/erasure.go` | Vault, then ledger insert, then `SADD`; no `SADD` if insert fails; drop local cache; stop using `cache_purged` as control |
| `internal/keyvault/keyvault.go` | No `put` after a forgotten check (caller fence) |
| new `purged_tenants` | When the company door is wired; also `SADD` company member |

## Related

- [Decision register](Inveniam%20Indicia%20(INV-42236)/decisions/INDEX.md)
- [ADR-0004 Erasure Ledger as Lifecycle Event Log](ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) — the follow-up §4 promised: un-forget + the one allowed recalculate, on a remodelled ledger
- [ADR-0002 Forget Table Before Cache](ADR-0002%20Forget%20Table%20Before%20Cache.md)
- [ADR-0001 Acknowledged Sidecar Cache Purge](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md)
- [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](../wiki/TOCTOU.md)
- [Open Questions](../wiki/Open%20Questions.md)
- [Write the Person Graveyard](../wiki/Write%20the%20Person%20Graveyard.md) — how-to; code not written
- [ADR-0003 Landing Review Findings](../wiki/ADR-0003%20Landing%20Review%20Findings.md) — pre-implementation review; findings 2–5 still open
- [Wiki Index](../wiki/index.md)
