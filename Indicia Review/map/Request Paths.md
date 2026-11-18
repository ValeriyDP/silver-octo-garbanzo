---
name: Request Paths
date: 2026-10-27T08:20:00.000Z
tags:
  - indicia-review
  - pr-review
  - architecture
---

# Request Paths

**Summary**: Every registered endpoint on both services, the handler behind it, and the authorization tier that gates it. Use this when a diff adds a route, moves a route between groups, or changes a middleware — the three changes whose blast radius is invisible in the handler itself.

**Sources**: `internal/api/router.go`, `internal/api/middleware/auth.go`, `internal/auth/roles.go`, `internal/sidecar/router.go`.

**Last updated**: 2026-10-27

---

## Middleware chain, in order

Order is behaviour here, so a reordering in a diff deserves the same scrutiny as a logic change.

1. `gin.Recovery()`
2. OpenTelemetry instrumentation, when tracing is enabled
3. Metrics
4. Request logger
5. Rate limiting — the Redis limiter when Redis is available, otherwise the in-memory token bucket
6. **Authentication**, applied to the protected group only: static JWT validation or FusionAuth validation, selected by provider
7. Registered-company validation, when `Companies.RequireRegistered` is set
8. The group's role checker — one of the seven below
9. Idempotency, on event submission only
10. Audit wrapping, on mutating administrative and operations routes

Everything from step 6 down hangs off a single `protected` group. A route registered on the engine instead of that group is unauthenticated, which is the specific mistake the route-gating test below exists to catch.

## Role vocabulary

Five roles, and the set is closed. `internal/auth/roles.go` is the trust boundary where role strings enter the process; a role outside the vocabulary is dropped per request at both JWT ingress paths and rejected at boot for static credentials.

| Role | Grants |
| ---- | ------ |
| `reader` | Own-tenant reads, and verify |
| `writer` | Own-tenant submission **only** |
| `company_admin` | Everything within the own tenant, including user management |
| `global_admin` | Cross-tenant customer lifecycle, and operations for now |
| `operator` | Cross-tenant pipeline operations, operations routes only |

Two properties are load-bearing and easy to break by being helpful:

**`writer` is deliberately not a `reader`.** The roles claim is a list, so a producer that only appends gets `writer` alone. A compromised producer token must be able to append and never to exfiltrate. Admitting `writer` to `RequireReader` would quietly undo that.

**`operator` is assigned to nobody today**, and `global_admin` retains operational reach. The role exists now so that separating the two duties later is a role-assignment change rather than a re-architecture of every operations route. A diff that grants `operator` on a lifecycle or tenant-data surface breaks the separation the role was created to enable.

## Authorization tiers

| Checker | Admits |
| ------- | ------ |
| `RequireReader` | `reader`, `company_admin`, `global_admin` |
| `RequireVerifyReader` | `reader`, `company_admin`, `global_admin` |
| `RequireWriter` | `writer`, `company_admin`, `global_admin` |
| `RequireEventTypeLister` | `reader`, `writer`, `company_admin`, `operator`, `global_admin` |
| `RequireOperator` | `operator`, `global_admin` |
| `RequireAdmin` | `company_admin`, `global_admin` |
| `RequireGlobalAdmin` | `global_admin` |

`RequireVerifyReader` admits exactly what `RequireReader` admits, and the duplication is deliberate. Verify is an exception argued on its own terms — a tenant reader may call it because verification must stay caller-orchestrated, where the answer can contradict the operator. Keeping the checker separate means a future edit to `RequireReader` cannot widen the verify surface by accident. **Do not collapse these two into one**, and treat a diff that does as a Major finding with the comment in `internal/api/middleware/auth.go` as the citation.

## Core service, port 8000

### Public

No authentication, by design, so probes keep working.

| Method | Path | Handler |
| ------ | ---- | ------- |
| GET | `/` | `health.go` — Root |
| GET | `/health` | `health.go` — Health |
| GET | `/health/live` | `health.go` — Live |
| GET | `/health/workers` | `health.go` — Workers |
| GET | `/ready` | `health.go` — Ready |
| GET | `/info` | `health.go` — Info |
| POST | `/auth/token` | `auth.go` — Token. Registered only under the static auth provider |
| GET | `/docs/*any` | Swagger UI. Registered only when `Swagger.Enabled`, default off, because the UI enumerates every route |

`GET /health/metrics` is **not** public. It sits on the `/health` prefix but behind `RequireOperator`, because Prometheus exposition is operational intelligence — queue depths, per-route latency, worker liveness. It keeps the `/health` prefix only so existing scrape configuration does not break. When no auth provider is configured it is not registered at all, which is the correct direction to fail.

### Tenant surface

| Tier | Method | Path | Handler |
| ---- | ------ | ---- | ------- |
| Writer | POST | `/events` | `events_hashonly.go` — CreateHashOnly, with idempotency |
| Writer | POST | `/batches/:id/retry` | `events.go` — RetryBatch |
| Event-type lister | GET | `/event-types` | `event_types.go` — List |
| Reader | GET | `/events` | `events.go` — Query |
| Reader | GET | `/events/:id` | `events.go` — Get |
| Reader | GET | `/events/:id/anchor/status` | `events.go` — GetAnchorStatus |
| Reader | GET | `/batches` | `events.go` — ListBatches |
| Reader | GET | `/batches/:id` | `events.go` — GetBatch |
| Verify reader | GET | `/events/:id/verify` | `events.go` — Verify |

### Administrative surface, `/admin`

Gated by `RequireAdmin`, with a narrower checker on the company group. Mutating routes are audit-wrapped.

| Tier | Method | Path | Handler |
| ---- | ------ | ---- | ------- |
| Global admin | GET, POST | `/admin/companies` | `companies.go` |
| Global admin | GET, PUT, DELETE | `/admin/companies/:id` | `companies.go` |
| Admin | GET, POST | `/admin/users` | `users.go` |
| Admin | GET, PUT, DELETE | `/admin/users/:id` | `users.go` |
| Admin | GET | `/admin/events/:id/trace` | `admin_trace.go` — EventTrace |
| Admin | POST | `/admin/event-types` | `event_types.go` |
| Admin | POST | `/admin/event-types/promote`, `/deprecate`, `/withdraw` | `event_types.go` |

### Operations surface, `/ops`

All gated by `RequireOperator`. Mutating routes are audit-wrapped.

| Method | Path | Handler |
| ------ | ---- | ------- |
| GET | `/ops/alerts` | `health.go` — Alerts |
| GET | `/ops/dead-letters` | `health.go` — DeadLetters |
| POST | `/ops/dead-letters/replay` | `health.go` |
| DELETE | `/ops/dead-letters` | `health.go` |
| POST | `/ops/batches/retry-all-failed` | `admin_pipeline.go` |
| GET | `/ops/batches/trouble` | `admin_pipeline.go` — TroubleBatches |
| GET | `/ops/batches/:id/investigate` | `events.go` — InvestigateBatch |
| POST | `/ops/batches/:id/rebatch` | `events.go` |
| GET | `/ops/batches/:id/trace` | `admin_trace.go` — BatchTrace |
| GET | `/ops/pipeline/lag` | `admin_pipeline.go` — PipelineLag |
| POST | `/ops/maintenance/reconcile-event-status` | `admin_pipeline.go` |
| GET | `/ops/hub` | `admin_hub.go` — HubOverview |
| GET | `/ops/operations`, `/ops/operations/:id` | `admin_operations.go` |
| DELETE | `/ops/operations/:id` | `admin_operations.go` |

## Sidecar service, port 8081

The content door. Validation happens here before anything irreversible.

| Group | Method | Path | Handler |
| ----- | ------ | ---- | ------- |
| Public | GET | `/health`, `/ready` | inline in `router.go` |
| Ingest | POST | `/events` | `http/handler.go` — CreateEvent |
| Read | GET | `/events/:id` | `http/read.go` — GetEvent |
| Read | GET | `/events/:id/verify` | `http/read.go` — VerifyEvent |
| Read | GET | `/quarantine`, `/quarantine/:id` | `http/quarantine.go` |
| Burn | DELETE | `/quarantine/:id` | `http/quarantine.go` — DeleteQuarantine |
| Erasure | POST | `/erasure` | `http/erasure.go` — EraseSubject |
| Erasure | POST | `/erasure/preview` | `http/erasure.go` — PreviewErasure |
| Erasure | POST | `/erasure/unforget` | `http/erasure.go` — UnforgetSubject |
| Erasure | GET | `/erasure` | `http/erasure.go` — ListErasures |

## The safety net, and why you still read the diff

`TestEveryRegisteredRouteIsGatedOrPublic` in `internal/api/router_authz_test.go` walks the entire registered route table and fails when a route appears in neither the gate map nor the public allowlist. A new route therefore cannot merge unclassified.

What the test cannot tell you is whether the *chosen* gate is the right one. It is satisfied by a tenant-data route declared as public with a reason, or by a lifecycle route handed to `operator`. So when a diff adds a route, the review question is not "is it classified" — CI answers that — but "is it classified correctly, and does the reason hold".

## Related pages

- [Codebase Map](INDEX.md)
- [Event Pipeline](Event%20Pipeline.md)
- [Hot Spots](Hot%20Spots.md)
