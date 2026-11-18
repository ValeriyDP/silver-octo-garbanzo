---
name: Event Pipeline
date: 2026-10-27T08:20:00.000Z
tags:
  - indicia-review
  - pr-review
  - architecture
---

# Event Pipeline

**Summary**: How an event travels from submission to on-chain confirmation, which worker owns each hop, and the concurrency invariants that keep the hops safe. Use this when a diff touches a worker, a status value, a stream, or a batch query.

**Sources**: `internal/workers/`, `internal/storage/postgres/client.go`, `internal/core/hashonly.go`, `cmd/api/main.go`, `docs/standards/CODING_STANDARDS.md` (Resilience Patterns).

**Last updated**: 2026-10-27

---

## The six hops

**1. Submission.** `POST /events` accepts a hash-only envelope. The core validates the envelope shape, confirms the event type is registered, and recomputes the event root with `pkg/canonical`. It validates no payload, because it holds no content. The event is enqueued to the Redis stream `events:stream` and the response returns immediately — storage is asynchronous by design, which is why the pipeline below exists at all.

**2. Persistence.** The event worker consumes `events:stream` through a consumer group, so each message reaches exactly one consumer and workers scale horizontally. It writes to PostgreSQL as the queryable mirror and to immudb as the immutable log, under two keys per event: `event:{id}:raw` and `event:{id}:meta`. It then publishes onward to the anchor stream. Worker count is configurable, and each instance names itself from the process ID and index.

**3. Batching.** The batch worker polls PostgreSQL for companies with pending unbatched events, groups them per company, and builds a Merkle tree. Defaults: 1,024 events per batch, a ten-minute maximum age for the oldest event, a thirty-second poll interval. The batch and its event membership — including each event's leaf index — are written in one transaction, then the batch is pushed to `batches:stream`.

**4. Anchoring.** The anchor worker consumes `batches:stream`, claims a batch atomically, and submits the Merkle root to the chain through the Inveniam Hub, which holds the signing keys so Indicia does not. Encoding is per chain: the Mantra Dukong path encodes `anchor(string,bytes32)`, the NVNM path encodes the `addRecord(tuple)` precompile call.

**5. Confirmation.** The batch status worker polls the Hub for transaction status on anchored batches — every five minutes, twenty batches per iteration, with a one-second pause between each to avoid bursting the Hub — then propagates the final status down to the individual event records.

**6. Trimming.** The stream janitor trims `events:stream` and `batches:stream` back to the oldest identifier still in flight across all consumer groups. It uses `MINID` rather than `MAXLEN` deliberately: `MAXLEN` keeps the N most recent messages regardless of consumer progress and can discard messages a lagging consumer has not read. Dead-letter streams are never trimmed, because they are the audit trail for failed messages.

## Status machines

Two separate status fields, and they are not the same vocabulary.

**Batches**: `pending → anchoring → anchored → confirmed`, with `failed` reachable from the middle of the run.

**Events** (anchor status): `pending → anchored → confirmed`, with `failed`.

The `anchoring` state exists only on batches, and only as a claim marker. An event never sees it.

## Concurrency invariants

These are the properties a reviewer has to verify by reading, because no linter checks them.

**Atomic claims, checked by row count.** A state claim is a single `UPDATE … WHERE status = 'expected'`, and the caller inspects the affected row count to detect a lost race. `ClaimBatchForAnchoring` is the reference implementation: it moves `pending → anchoring` for one batch identifier and reports whether it won. A diff that reads a status and then writes it in a separate statement has introduced a race, whatever the surrounding code looks like.

**Stale claims are swept, not abandoned.** A worker that dies mid-anchor leaves a batch in `anchoring` forever. `ResetStaleAnchoringBatches` returns such batches to `pending` after a threshold, and the anchor worker runs the sweep both at startup and on a periodic loop — the loop matters, because startup-only recovery leaves a stuck batch waiting for the next process restart. The threshold must stay longer than the operational tolerance for an in-flight anchor, or the sweep will reset work that is merely slow.

**Transient and permanent failures are different.** Hub and network errors are classified before a batch is marked failed. A transient error resets state for retry with exponential backoff, from two seconds to a thirty-second cap. Marking a batch permanently failed on what was a timeout is a Major finding; so is retrying forever on what was a malformed request.

**Dead-lettering is bounded and counted.** Delivery counts are tracked per message and seeded from Redis `XPENDING` at startup, so a restart does not reset a message's history. After the retry ceiling the message is dead-lettered and the associated record marked failed. The dead-letter stream is operator-managed through `/ops/dead-letters` and is exempt from trimming.

**Multi-statement work is transactional.** Explicit `Begin` and `Commit`, with a deferred rollback that tolerates an already-closed transaction. `InsertEventBatch` and `CreateBatchWithEvents` are the two to compare a new one against.

**immudb writes are idempotent re-writes.** The same key carries the same bytes, with `immudb.MetaFromPayload` as the single mapping from payload to metadata. This is what makes the audit path's double write safe: the record is written once synchronously at emission, and the event worker's later write is the identical re-write.

## The audit path, which is not the event path

Privileged-action audit records travel differently, and the difference is a security control rather than an optimisation.

`internal/audit` is the only emitter. Records are hash-only events on a reserved system tenant, emitted **in-process and never over HTTP**, so no network caller can forge one. That is enforced rather than merely intended: the network door refuses any envelope claiming the system tenant, and the durable path that is exempt is obtainable exactly once per event service, claimed at construction by the audit emitter.

Emission writes to immudb synchronously inside the same PostgreSQL transaction that allocates the record's sequence number, then enqueues the identical record for anchoring. Any failure aborts the emission and rolls the sequence back.

What a failed emission means for the request that triggered it is policy, not mechanism: administrative routes fail closed, operations routes fail open with an alarm and a retry, and tier-1 approval fails closed unconditionally.

Two review rules follow. A diff adding a second audit constructor or exposing the envelope builder defeats the entire control — the package's shape *is* the enforcement. And a diff that lets an unknown role string reach the claims list poisons every audit emit for that actor, because the audit record enum-validates roles against the same closed vocabulary; on a fail-closed route that means the mutation executed and the caller still got a 500.

## Where the pipeline is configured

Worker behaviour comes from the `Workers` config group, and the stores from `Postgres`, `Immudb`, and `Redis`. Every knob is an `INDICIA_*` environment variable, and each worker family can be disabled independently — which is how an API-only or worker-only deployment is produced from one binary. A diff that adds a knob updates `docs/guides/ENVIRONMENT_VARIABLES.md`; a diff that adds a *default* needs to justify it against the no-silent-fallbacks rule, because a default that masks a missing value is exactly what that rule forbids.

## Integration tests as the specification

`tests/integration/` holds the executable version of most of the above, behind the `integration` build tag and backed by testcontainers: `anchor_worker_test.go`, `batch_worker_test.go`, `batch_status_worker_test.go`, `get_anchored_batches_fifo_test.go`, `retry_batch_test.go`, `immudb_audit_tamper_test.go`, `e2e_test.go`. When a pipeline diff arrives without a corresponding change to these, that is worth a Question at minimum: either the behaviour did not change, or the tests were not exercising it.

## Related pages

- [Codebase Map](INDEX.md)
- [Request Paths](Request%20Paths.md)
- [Hot Spots](Hot%20Spots.md)
