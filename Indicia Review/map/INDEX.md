---
name: Codebase Map
date: 2026-10-27T08:20:00.000Z
tags:
  - indicia-review
  - pr-review
  - architecture
  - index
---

# Codebase map — Inveniam Indicia

**Summary**: Orientation for reviewing pull requests against `github.com/inveniamcapital/InveniamIndicia`. Two deployables, roughly 95,000 lines of Go, no frontend. This page carries the topology and the package ownership table; the three pages below carry the route surface, the event pipeline, and the places where reviews actually land.

**Sources**: the repository at `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia`, read at the commit merging pull request 37.

**Last updated**: 2026-10-27

---

## How to use this during a review

Start from where the diff lands, not from the top. Find the changed package in the ownership table, read the obligation in its right-hand column, and check that obligation against the diff. The obligations are the non-obvious consequences — the things a diff can break in a file it never touches.

Two pages carry the detail a review usually needs next: [Request Paths](Request%20Paths.md) when the diff touches an endpoint or a middleware, and [Event Pipeline](Event%20Pipeline.md) when it touches a worker, a status, or a stream. [Hot Spots](Hot%20Spots.md) carries the churn data and the known-stale standards.

## Two deployables

| Service | Entry point | Listens | Holds content? |
| ------- | ----------- | ------- | -------------- |
| Anchoring core | `cmd/api/main.go` | 8000 | **No.** Hash-only envelopes, never readable payloads |
| Content sidecar | `cmd/sidecar/main.go` | 8081 | **Yes.** The only component that accepts readable content, and it persists only ciphertext |

Two further binaries are not services: `cmd/migrate` applies migrations, and `cmd/eventtypes-eval` evaluates event-type fixtures.

The core also runs the background workers in-process, so `cmd/api` is both the HTTP surface and the pipeline host. The worker set is enabled per config group, which means a deployment can run API-only or worker-only instances from the same binary.

## The invariant that governs everything

The core never sees event content. The sidecar validates a producer's payload, seals it under a per-subject key, and forwards only hashes, non-personal locators, and pseudonyms onward. Stated in `internal/sidecar/http/handler.go` and `internal/core/doc.go`, designed in `docs/plans/SEPARATION_OF_CONCERNS_SPEC.md`.

Three consequences a reviewer should hold:

Payload schema validation happens in the sidecar and nowhere else. There is exactly one validation path, and a second one would be a correctness defect rather than a style problem — `pkg/eventtypes/doc.go` records that the nested envelope validator in `internal/core` was deleted rather than left to drift.

Hashing is a shared contract, not an implementation detail. `pkg/canonical` is imported by the core, the sidecar, and bring-your-own clients alike, so an anchored hash is reproducible by any of them. Both `pkg/` packages sit outside `internal/` precisely so a remote sidecar can import them as its own module.

Anchored hashes are immutable, so an encoding or leaf-derivation change is a **new scheme**, never an in-place edit. A diff that edits existing canonical encoding rules is a Blocker unless it introduces a new scheme number.

## Package ownership

Line counts are approximate and included only to show weight.

| Package | Lines | Owns | A diff here obliges you to check |
| ------- | ----: | ---- | -------------------------------- |
| `internal/api` | 1,850 | Router, middleware order, dependency injection | Which authz group the route joined. A route in the wrong group is a silent privilege change, invisible in the handler diff. See [Request Paths](Request%20Paths.md) |
| `internal/api/handlers` | 13,700 | Every HTTP handler. Largest package in the repo | Error shape against `docs/api/API_SPECIFICATION.md`; tenant scoping applied from claims, not from a request field |
| `internal/api/middleware` | 4,600 | Auth, audit, idempotency, rate limiting (in-memory and Redis), company validation, metrics | Ordering. These are cross-cutting; a reordering changes behaviour everywhere at once |
| `internal/api/docs` | 4,400 | Generated OpenAPI specification | That it was regenerated via `scripts/swagger.sh` and not hand-edited |
| `internal/core` | 3,800 | Domain model, hash-only ingestion service, company service, validation, batch accumulator | That no content-bearing field crept into the envelope; that the audit write capability is still obtainable only once |
| `internal/workers` | 4,700 | Event, batch, anchor, and batch-status workers; stream janitor; worker pool | Atomic state claims, delivery counting, dead-lettering, startup sweeps. See [Event Pipeline](Event%20Pipeline.md) |
| `internal/storage/postgres` | 4,400 | Queryable mirror, migrations, operations store, tenant event types, audit sequences | A schema change ships a migration; multi-statement work runs in an explicit transaction |
| `internal/storage/immudb` | 1,500 | Immutable audit log, sharded router, verified reads, tamper detection | Key naming (`event:{id}:raw` and `:meta`) and that writes stay idempotent re-writes of identical bytes |
| `internal/storage/redis` | 300 | Stream enqueue adapter for the ingestion queue | Nothing structural; anchor and batch streams are driven directly by the workers |
| `internal/blockchain` | 3,900 | Hub client for anchor writes, keyless `RecordsReader` for anchor reads, per-chain encoders | That readback stays keyless and off the Hub. A readback through our own infrastructure can only restate our database, which defeats the purpose |
| `internal/keyvault` | 4,200 | Sealing and opening per-event blobs, Vault Transit subject keys, crypto-shred, tenant offboard | That the package still persists nothing — it is a stateless library by design |
| `internal/sidecar` | 12,000 | The content door: classify, derive, pseudonymise, seal, store, quarantine, forget, sweep | Payload validation happens before anything irreversible; the forget set is consulted before seal and before open |
| `internal/audit` | 1,000 | The **only** emitter of privileged-action audit records | That no second constructor or envelope builder appeared. One entry point, constructed once at wiring time, is the whole control |
| `internal/auth` | 2,200 | The five-role vocabulary, JWT validation for static and FusionAuth | That the role vocabulary did not grow a sixth name or an alias. Two names for one power level is where authorization bugs breed |
| `internal/config` | 2,300 | Loading and validating thirteen `INDICIA_*` config groups | `docs/guides/ENVIRONMENT_VARIABLES.md` updated; no silent default masking a missing value |
| `internal/operations` | 2,200 | Substrate for long-running async admin tasks, with a persisted lifecycle | Cooperative cancellation observed; startup recovery flips stale rows back to queued |
| `internal/registrysync` | 1,600 | Event-type registry synchronisation and watch | Health wiring, which reads the watch handle at startup |
| `internal/merkle` | 1,000 | Merkle tree construction for batch anchoring | Leaf ordering and the batch size cap enforced by this layer |
| `pkg/canonical` | 1,600 | The byte-identical hashing contract: canonical JSON encoding, leaf derivation, event-root fold | New scheme rather than in-place edit; numbers decoded with `UseNumber()` so they arrive as `json.Number` and never `float64` |
| `pkg/eventtypes` | 5,200 | Event-type schema registry, YAML loader, validator, field tiers | Both sides still accept exactly the same events. The sidecar and the core consume this registry differently and deliberately so |
| `pkg/metrics` | 1,100 | Prometheus metrics in the `indicia` namespace, organised by subsystem | New metrics registered in the right subsystem; label cardinality bounded |
| `pkg/retry`, `pkg/tracing`, `pkg/logger` | 1,100 | Backoff, OpenTelemetry setup, zerolog construction | Context cancellation honoured through retries |
| `internal/testimages` | 200 | Pinned container images for tests | Image pins move deliberately, not incidentally |

## Storage, and what each store is for

Three stores, each with one job, and conflating them is a design error worth flagging.

**immudb** is the immutable audit log and the source of cryptographic truth. Writes are unverified for throughput; reads are verified with proof checking; a periodic verified read audits for tampering. Supports sharding by company through `ShardedRouter`.

**PostgreSQL** is the queryable mirror — the index you can filter and paginate. It also holds batches, companies, operations, tenant event types, and audit sequences. Twenty-one migrations in `internal/storage/postgres/migrations`, applied by `cmd/migrate` or at API startup.

**Redis** is the buffer and queue. Two primary streams, `events:stream` and `batches:stream`, with consumer groups for horizontal scaling, plus dead-letter variants that are never trimmed because they are an audit trail.

## Notable direct dependencies

Gin for HTTP, pgx for Postgres, go-redis for Redis, the immudb client, zerolog for logging, golang-migrate for migrations, `hashicorp/vault/api` for Transit, `defiweb/go-eth` for chain encoding, `golang-jwt` and `MicahParks/keyfunc` for tokens, Prometheus for metrics, OpenTelemetry for tracing, swaggo for the generated specification, and testcontainers for integration tests.

Two carry licence history worth remembering: `codenotary/immudb` is BSL-1.1 under a commercial licence, and `hashicorp/golang-lru` is an MPL-2.0 release that predates HashiCorp's move to BUSL. Both are approved; a *new* HashiCorp dependency is not.

## Related pages

- [Request Paths](Request%20Paths.md) — every endpoint, its handler, and its authorization tier
- [Event Pipeline](Event%20Pipeline.md) — streams, workers, status machine, and the invariants that hold it together
- [Hot Spots](Hot%20Spots.md) — where change concentrates, which seams are fragile, and which documented standards are stale
- [Review register](../reviews/INDEX.md)
