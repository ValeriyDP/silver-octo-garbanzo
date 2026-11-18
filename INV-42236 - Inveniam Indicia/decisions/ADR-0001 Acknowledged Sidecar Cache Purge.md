---
name: ADR-0001 Acknowledged Sidecar Cache Purge
date: 2026-09-02T13:50:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - adr
  - architecture
---
# ADR-0001 Acknowledged Sidecar Cache Purge

- **Status**: Superseded by [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- **Date**: 2026-09-02
- **Area**: sidecar / keyvault
- **Deciders**: superseded 2026-09-03 when ADR-0003 was accepted
- **Related**: [ADR-0003 Shared Redis Forget Set](ADR-0003%20Shared%20Redis%20Forget%20Set.md), [ADR-0002 Forget Table Before Cache](ADR-0002%20Forget%20Table%20Before%20Cache.md). [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md), [TOCTOU](../wiki/TOCTOU.md), [Open Questions](../wiki/Open%20Questions.md) #1 #2, [Core and Sidecar](../wiki/Core%20and%20Sidecar.md)

## Context

Crypto-shred is a Vault operation plus a memory operation. `EraseSubject` / `OffboardTenant` / `PurgeTenant` destroy or disable Transit keys globally. Each sidecar process also keeps plaintext in two maps:

- `keyvault.keyCache` — write DEK, wrapped DEK, read DEK (`wdek` / `wwrap` / `rdek`). `OpenEvent` → `unwrapDEK` serves a cache hit with **no Vault round-trip** (source: `internal/keyvault/keyvault.go`).
- `sidecar/pseudonym.Pseudonymizer.cached` — per-tenant HMAC secret, documented as valid until process restart (source: `internal/sidecar/pseudonym/pseudonym.go`).

2a shipped `keyvault.Invalidator.BroadcastPurge(tenantID, subjectID string)` so 2c would not need a refactor. Every build installs `NoopInvalidator`. Local purge zeroizes this process; siblings are never told. `EraseSubject` still returns `CachePurged: true` and the ledger stores it (source: `keyvault.go`, `internal/sidecar/http/erasure.go`). That is DATA-PROTECTION-001 / `internal-keyvault-2`. It is already reachable: per-subject erase shipped in 2b (D3).

Repo plans already name “Redis pub/sub” as the 2c bus. That sentence is not a contract. Fire-and-forget `PUBLISH` still lets a warm replica that missed the message open a sidecar envelope. A truthful `cache_purged: true` needs more than a yell.

A drop that is not the last write to the map is also a lie: ingest `SealEvent` → `subjectDEK` → three `cache.put`s, or a racing `unwrapDEK` that `put`s after the drop, re-warms the key (`internal-keyvault-3`, [TOCTOU](../wiki/TOCTOU.md)).

The audience is **sidecar HTTP replicas** (`cmd/sidecar`). Core stream workers (`events:stream`) never hold a DEK. Picture: [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md) diagram 2.

## Decision

Treat cache purge as a **sidecar control-plane command with acknowledgement**, not as an Indicia event and not as an un-acked Redis publish.

1. **Bus.** Use the Redis the sidecar already requires (`INDICIA_SIDECAR_REDIS_ADDR`). A dedicated control channel — not `events:stream`, not the hash-only core door. 2c owns this bus; later schema-cache invalidation reuses it (source: `TENANT_EVENT_TYPE_REGISTRATION_DESIGN.md`).
2. **Command.** Keep the existing seam: `BroadcastPurge(tenantID, subjectID)`. Empty `subjectID` means the whole tenant (`purgeTenant` today). Subject erase may send subject scope or, conservatively, tenant scope. One message must drop **both** local maps in the receiving process. `Pseudonymizer` gains an invalidation hook; it does not have one now (`internal-sidecar-1`).
3. **Truth rule.** `cache_purged: true` only after (a) Vault disable/destroy succeeded, (b) this process dropped its maps, (c) every **live** sidecar replica acknowledged the same drop. Timeout or missing ack → do not attest true. Prefer failing the erase/offboard (or returning `cache_purged: false`) over a green lie. This replaces the current `EraseSubject` hard-coded `CachePurged: true` after local purge only.
4. **Order.** Fence writes for the target (subject or tenant) → Vault disable/destroy → local purge + broadcast → wait for acks → attest. The fence is in this change: without it a `put` after the drop re-creates the hole (`internal-keyvault-3`). New replicas that start after destroy are safe (empty cache, unwrap fails). The dangerous replica is the one that was already warm and missed the command, or re-warmed after it.
5. **Until this lands.** Pin the sidecar to one replica. Do not treat a deploy that omitted a replica count as “pinned” ([Open Questions](../wiki/Open%20Questions.md) #1).

**Ack membership (proposed shape, still to lock in implementation):** each sidecar process heartbeats a replica id into a Redis set with TTL. The publisher waits for acks from that set (self already purged locally) with a timeout. A replica that is not in the set is treated as dead, not as purged. Exact Redis verbs (pub/sub + reply stream vs a short-lived stream per purge) are an implementation choice under this contract — they must not weaken the truth rule.

## Pattern name

There is no single Gang-of-Four name. The sequence is four textbook moves stacked. Call the stack **quiesce–shred–invalidate-ack** (then resume only what is still allowed to write).

| Step you named | Pattern | Here |
| -------------- | ------- | ---- |
| Freeze queue | **Write quiesce** / **write fence** | Refuse ingest / remint for the target so `cache.put` cannot race the drop. |
| Delete | **Crypto-shred** | Disable or destroy the Transit key. Ciphertext rows stay; they become inert. |
| ACK | **Synchronous invalidation-ack** + **barrier** (directory cache-coherence; cousin of 2PC) | Invalidate, wait for every live replica to vote “dropped,” then commit `cache_purged: true`. |
| Unfreeze | **Resume** — but not for the shredded subject | Other traffic may proceed. That subject (or tenant) stays fenced. A durable **tombstone** is the fence that survives the call (`internal-keyvault-3`). Unfreezing *that* subject is the bug. |
| Unreadable after shred | **Process-as-is** (inert artifact) + **tombstone** | Do not retry decrypt. Do not delete the row. Finish the path with what remains: ciphertext, hashes, ledger. Verify is `200` + `erased` (“absence after erasure is not a verification failure”). A key gone *without* a ledger row is `content_mismatch` (alarm), not this case (source: `read.go` `resolveUnopenable`). |

Do not name this “just cache invalidation.” Invalidation without quiesce and without ack is the status quo (`NoopInvalidator`).

## Alternatives considered

- **Fire-and-forget Redis `PUBLISH` only** — matches the one-line 2a/2b note; cheapest. Rejected: a restarting or partitioned replica never sees the message; `cache_purged: true` stays a lie. That is `NoopInvalidator` with extra traffic.
- **Indicia event / `events:stream`** — “broadcast an event widely.” Rejected: core workers index hashes; they do not open envelopes. Sidecar replicas do not consume that stream. Erasure is not a content event.
- **Shared Redis DEK cache** — one place to delete. Rejected: moves plaintext key material onto the network and into Redis. Worse than today’s process-local maps.
- **No in-process cache** — every `OpenEvent` hits Vault. Closes the sibling hole. Rejected as the *only* fix: still need a fence so ingest cannot mint after shred; still need the pseudonym map addressed; load on Transit is the reason the cache exists (`INDICIA_KEYVAULT_CACHE_SIZE`).
- **Stay single-replica forever** — honest today. Rejected as the launch posture: HA is the reason 2c is launch-gating (source: `SECURITY_ASSESSMENT_2026-08-17.md` top priority 1).
- **Redis Streams as the product contract** — durable replay for late subscribers. Not rejected as an *implementation* of the ack path. Rejected as a reason to skip acknowledgements: replay does not by itself tell the attestor that every **currently live** process dropped.

## Consequences

- **Positive**: `cache_purged` becomes a claim a regulator can be shown. Subject erase (already live) and tenant offboard (unbuilt door) share one contract. The `Invalidator` seam stays. Schema registration later rides the same bus.
- **Negative / trade-offs**: erase/offboard latency includes a wait; Redis is now on the erasure truth path (sidecar already refuses to start without it). Heartbeat membership can drop a replica from the set and treat it as dead while it still holds a DEK — TTL must be shorter than we are willing to leave a corpse warm, and a process that missed heartbeats must drop caches on reconnect or refuse to serve reads until it has caught up. This is the remaining sharp edge of “live replica.”
- **Follow-ups / open threads**: concrete ack transport; heartbeat TTL; whether subject erase always broadcasts tenant scope; HTTP shape of the tenant door (not this ADR — D3d); whether `internal-keyvault-3` is a separate PR if someone wants to split ([Open Questions](../wiki/Open%20Questions.md) #2 — this draft keeps the fence in the same change).

## Affected code

Nothing shipped yet. Grounding for the first implementation:

| Path | What this decision touches |
| ---- | -------------------------- |
| `internal/keyvault/cache.go` | `Invalidator`, `NoopInvalidator`, `purgeSubject` / `purgeTenant` |
| `internal/keyvault/keyvault.go` | `New` always installs `NoopInvalidator`; `EraseSubject` / `OffboardTenant` / `PurgeTenant` set `CachePurged: true` after local purge; `unwrapDEK` / `subjectDEK` `put` |
| `internal/keyvault/config.go` | `NewFromConfig` never calls `WithInvalidator` |
| `internal/sidecar/pseudonym/pseudonym.go` | `cached` has no invalidation hook |
| `internal/sidecar/http/erasure.go` | surfaces `cache_purged` from the attestation |
| sidecar Redis wiring | already required for ingest idempotency; new control channel |

## Related

- [Decision register](Inveniam%20Indicia%20(INV-42236)/decisions/INDEX.md)
- [ADR-0002 Forget Table Before Cache](ADR-0002%20Forget%20Table%20Before%20Cache.md)
- [Slice 2c Tenant Offboard](../wiki/Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](../wiki/TOCTOU.md)
- [Open Questions](../wiki/Open%20Questions.md)
- [Core and Sidecar](../wiki/Core%20and%20Sidecar.md)
- [New Developer Onboarding](../wiki/New%20Developer%20Onboarding.md)
- [Wiki Index](../wiki/index.md)
