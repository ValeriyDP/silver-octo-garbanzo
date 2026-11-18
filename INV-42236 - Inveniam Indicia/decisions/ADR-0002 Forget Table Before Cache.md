---
name: ADR-0002 Forget Table Before Cache
date: 2026-09-03T14:27:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - adr
  - architecture
---

# ADR-0002 Forget Table Before Cache

- **Status**: Superseded by [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- **Date**: 2026-09-03
- **Area**: sidecar / keyvault
- **Deciders**: superseded 2026-09-03 when ADR-0003 was accepted
- **Related**: [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md), [ADR-0001](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md). [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md), [TOCTOU](../wiki/TOCTOU.md), [Open Questions](../wiki/Open%20Questions.md) #2

## Context

Two holes after “forget this person / this company”:

1. **Stale RAM** — another sidecar process still holds a plaintext DEK. `OpenEvent` → `unwrapDEK` serves a cache hit and never talks to Vault or Postgres. Old events can still be opened.
2. **Looks like first-time** — ingest does not consult the ledger. `EnsureSubjectKey` mints a new Transit key. New events can be stored and opened. Old events stay locked. We did not stay forgotten.

`erasure_ledger` already exists: `(company_id, subject_pseudonym)` plus `destroyed_at`, `completion_by`, `cache_purged`. Read uses it only **after** `OpenEvent` fails (`read.go` `resolveUnopenable`). Ingest never calls `GetErasure`. `cache_purged` is set `true` after a **local** cache drop (`EraseSubject`). That flag mixes “forgotten” with “every process wiped RAM.” It is a bad mechanism.

[ADR-0001](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md) proposed Redis purge + wait for every replica to ack DEK drops before attesting `cache_purged`. That is a hard RAM-empty bar. This draft picks a simpler shared truth: a **forget-table**, a **reload nudge**, and **list before cache** on every read and write.

## Decision

**Postgres is the forget-list. The in-memory set is a copy. The bus only says “reload.” Every open/seal checks the list before the DEK (or pseudonym) cache.**

### 1. Forget-table, not `cache_purged`

“Is forgotten?” is a row. It is not a boolean on an attestation.

| Scope | Table | Key |
| ----- | ----- | --- |
| One **person** (already shipped) | `erasure_ledger` | `(company_id, subject_pseudonym)` |
| Whole **company** (2c door, unbuilt) | new `purged_tenants` (name can change) | `company_id` |

Do not use `company_id` alone for “forget Alice.” That would refuse the whole tenant. `client_id` if it means the person is `subject_pseudonym` (HMAC), never raw `user_id`. A replica id does not belong on this list.

`cache_purged` stays a leftover attestation field until we drop or redefine it. It is **not** how replicas decide to refuse work.

### 2. Write the table, then ring the bell

The replica that handles erase / offboard:

1. Destroys or disables keys in Vault (existing library).
2. **Inserts the forget-row** (`InsertErasureIfAbsent` today; tenant row when the door exists).
3. **Emits a control nudge**: “forget-list changed.” Not an Indicia content event. Not `events:stream`. Same Redis the sidecar already requires is enough; payload need not carry the list.
4. Drops its own DEK / pseudonym entries for that person or company.

Every other replica:

1. Hears the nudge.
2. **Reads the table(s) from Postgres** (full set, or since-cursor — implementation).
3. Replaces its in-memory forget-set.
4. Drops cached unlock-codes that are now on the set.

Startup: load the table(s) into the in-memory set. A brand-new process has empty DEK cache anyway; it still needs the set so the first ingest does not remint.

### 3. List before cache (both doors)

On **write** (`POST /v1/events` → `SealEvent` / `subjectDEK` / `EnsureSubjectKey`): if `(company, subject)` or `company` is on the set → refuse. Do not mint. Do not `cache.put`. Forgotten must not look like first-time.

On **read** (`GET` → `OpenEvent` / `unwrapDEK`): if on the set → drop that cache entry if present, do not unwrap, do not `put`, answer `erased` (process-as-is: row and hashes stay). Do this **before** a cache hit.

Same rule for `Pseudonymizer.cached` when the **company** is on `purged_tenants`.

If the in-memory set is not trusted (missed nudge, just connected): read Postgres for that id, or refuse to serve until a reload succeeds. The table remains the source of truth; the set is a cache of the table.

### 4. What this does not claim

Unlock-codes may sit in RAM until that replica reloads and drops them. The **API** will not decipher once the set is fresh. We do **not** wait for every replica to ack a zeroize before the erase HTTP returns. That is the deliberate step down from ADR-0001’s truth rule.

A missed nudge plus a stale set plus a cache hit is hole 1 again. Mitigate with startup load + nudge + a periodic reload (or a DB check when the set might be stale). Do not treat the nudge payload as the list.

Quiesce during a **tenant** destroy loop is still required so a person minted mid-walk is not left off the table ([TOCTOU](../wiki/TOCTOU.md)). The forget-row is the fence **after** the row exists; it does not freeze the walk.

## Alternatives considered

- **ADR-0001: ack every replica’s DEK drop before `cache_purged: true`** — stronger “RAM is empty” claim. Heavier membership/ack. Rejected as the *primary* mechanism: the doors need “forgotten” more than they need a distributed barrier on zeroize. Keep as a later hardening if counsel wants process-memory empty, not only API-honest.
- **`cache_purged` as the forget-list** — already `true` after local purge only. Ambiguous. Rejected.
- **Company-only list for person erase** — blocks the whole tenant. Rejected.
- **Nudge carries the new list, replicas do not read Postgres** — split brain if a replica misses a message. Rejected. Nudge = reload; table = truth.
- **Check ledger only after `OpenEvent` fails** — current read path. Does not stop a cache hit. Rejected as sufficient.
- **Indicia `events:stream` as the nudge** — core workers do not hold DEKs; sidecars do not consume that stream. Rejected.

## Consequences

- **Positive**: one shared fact (“forgotten”) for hole 1 on the API and hole 2 on ingest. Person erase can use the table that already exists. Tenant offboard adds a company row. `cache_purged` is no longer the control plane. Open Question #2 (write fence) is this table on the write path — same delivery as wiring the check, not a second mystery.
- **Negative / trade-offs**: erase returns before every process has zeroized RAM. Periodic reload or “DB if unsure” is mandatory or a missed nudge reopens hole 1. Extra read of the set (memory) on every ingest/read; extra Postgres on reload. Two tables if we do not unify person and company into one schema.
- **Follow-ups**: unify vs two tables; nudge transport (Redis channel vs stream); reload interval; what the erase HTTP returns instead of a lying `cache_purged`; tenant-door HTTP (still D3d); whether we later add ADR-0001-style ack for a stricter memory bar.

## Affected code

Nothing shipped yet. Grounding:

| Path | What this decision touches |
| ---- | -------------------------- |
| `internal/sidecar/store/migrations/002_create_erasure_ledger.up.sql` | Person forget-table already there |
| `internal/sidecar/store/erasure.go` | `GetErasure` / `InsertErasureIfAbsent` — write path must consult this |
| `internal/sidecar/http/handler.go` | Ingest must check forget-set **before** `SealEvent` |
| `internal/sidecar/http/read.go` | Check set **before** `OpenEvent`; today ledger is only in `resolveUnopenable` |
| `internal/sidecar/http/erasure.go` | After insert, nudge + local drop; stop treating `CachePurged` as control |
| `internal/keyvault/keyvault.go` | `unwrapDEK` / `subjectDEK` must not `put` for a forgotten id (caller fence or vault-level) |
| `internal/sidecar/pseudonym/pseudonym.go` | Company-level drop when `purged_tenants` hits |
| new sidecar migration | `purged_tenants` when the tenant door is wired |
| sidecar Redis | Nudge channel only; not the list |

## Related

- [Decision register](Inveniam%20Indicia%20(INV-42236)/decisions/INDEX.md)
- [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- [ADR-0001 Acknowledged Sidecar Cache Purge](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md)
- [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](../wiki/TOCTOU.md)
- [Open Questions](../wiki/Open%20Questions.md)
- [New Developer Onboarding](../wiki/New%20Developer%20Onboarding.md)
- [Wiki Index](../wiki/index.md)
