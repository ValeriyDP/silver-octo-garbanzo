---
name: PR-38 Trace The Sidecar And Pass Context To Core
date: 2026-10-27T09:55:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-38
  - inv-43587
---

# PR-38 Trace The Sidecar And Pass Context To Core

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/38
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43587-sidecar-trace-context-to-core`
- **Commits**: 2 · **Files changed**: 14 · **Lines**: +619 / −40
- **CI run**: 40484490987 — Lint, Test, Integration Tests, Build & Checks pass. Docker Build skipped (PR path)
- **Reviewed**: 2026-10-27 · revised same day
- **Verdict**: Request changes · 2 Major, 2 Minor, 1 Question

## Scope

OpenTelemetry tracing for the sidecar, trace context forwarded on both outbound paths to the core, so one request is one trace. Reuses the core's tracing config validation instead of copying it. Requirement INV-43587, parent INV-43103.

All seven PR-body claims verified as implemented; the `INDICIA_ENVIRONMENT` one is the first Major. Gates checked, all pass except fail-fast, which is the two Majors and the second Minor below.

## Findings

```
Major · internal/config/config.go:14, internal/sidecar/config.go
defect:  INDICIA_ENVIRONMENT is a closed four-name set, and this PR makes an unrecognised name fail sidecar startup where the sidecar previously ignored the variable
reason:  the same string is the deployment.environment attribute at pkg/tracing/tracing.go:101 — open-ended telemetry identity and a closed security enum in one value
impact:  breaks — devus01 cannot start the sidecar, and naming it development collapses every dev cluster into one deployment.environment value behind the single Grafana Alloy consumer, so per-cluster grouping is impossible
```

```
Major · internal/config/config.go:444
defect:  validateProductionConfig runs only when Environment is production or staging, so any name outside the enum skips it
reason:  general.mdc fail-fast — posture is inferred from a name instead of taken as input. Six of its checks only test whether a shipped default survived: config.go:535 Postgres host localhost, passwords indicia and immudb, auth provider static
impact:  breaks — a production-grade environment under any other name starts with storage host, password, JWT secret, auth provider, Hub and audit-interval checks skipped, gin in debug mode at internal/api/router.go:79, and INDICIA_OTEL_INSECURE permitted. Precondition for the Major above: the enum cannot widen while the gate keys on the name
```

```
Minor · cmd/sidecar/main.go:238, cmd/sidecar/main.go:271
defect:  initTracing and shutdownTracer duplicate cmd/api/main.go:164 and cmd/api/main.go:194, differing only in ServiceName, logger receiver, and wrap text
reason:  internal/config/config.go:113 — "cmd/api and cmd/sidecar both call this so the two processes cannot drift" — applied to validation, not to this wiring
impact:  not fixed — resource attributes, shutdown timeout, or the insecure-warn rule must change twice or the services diverge
```

```
Minor · internal/config/config.go:118, internal/sidecar/router.go:79
defect:  INDICIA_TRACING_ENABLED=true with an empty INDICIA_OTEL_ENDPOINT starts with no tracing, no error, and no log line
reason:  general.mdc fail-fast — Validate returns nil early on an empty endpoint, tracing.Setup returns the no-op provider, and the "tracing enabled" log requires OTLPEndpoint != ""
impact:  breaks — otelgin mounts on the no-op provider, nothing exports, no operator signal. Pre-existing in cmd/api; this PR puts it on both services
```

```
Question · PR body test plan
defect:  "One traced request through the sidecar shows a single trace that includes the core span" is unchecked
reason:  the only end-to-end item in the test plan
impact:  not fixed — parentage is asserted in-process; collector-side joining is unverified
```

The other unchecked box, `pre-commit run golangci-lint --all-files`, is answered by CI: Lint green on the pinned v2.14.0.

## Draft comment

Request changes. CI green, and content is kept off spans and headers with tests that fail if it leaks. The blocker is `INDICIA_ENVIRONMENT`, per the two inline comments.

Major · `internal/config/config.go:14`, `internal/sidecar/config.go` — `INDICIA_ENVIRONMENT` is a closed four-name set, and this PR makes an unrecognised name fail sidecar startup where the sidecar previously ignored it. The same string becomes the `deployment.environment` attribute at `pkg/tracing/tracing.go:101`. We run many dev clusters (`devus01`, `devus02`, …) behind one Grafana Alloy consumer, so that attribute has to carry the real cluster name. `devus01` will not start; `development` collapses every cluster into one value. One string cannot be both an open-ended label and a closed security enum.

Major · `internal/config/config.go:444` — `validateProductionConfig` runs only for `production` and `staging`, so any other name skips storage host, password, JWT secret, auth provider, Hub and audit-interval checks, leaves gin in debug mode (`internal/api/router.go:79`), and permits `INDICIA_OTEL_INSECURE`. Fail-open, and the reason the enum cannot simply be widened. Pre-existing structure — say whether you would rather handle it here or in a follow-up, but the two are coupled.

Six of that gate's checks only test whether a shipped default survived (`config.go:535` Postgres host still `localhost`, passwords still `indicia`/`immudb`, auth provider still `static`). We want every environment setting everything explicitly — no defaults, no environment branches. Which direction do you want?

Minor · `cmd/sidecar/main.go:238`, `:271` — `initTracing` and `shutdownTracer` duplicate `cmd/api/main.go:164` and `:194`, differing only in ServiceName, logger receiver, and wrap text. `internal/config/config.go:113` argues the opposite for validation ("so the two processes cannot drift"). Resource attributes, shutdown timeout, or the insecure-warn rule now change twice.

Minor · `internal/config/config.go:118`, `internal/sidecar/router.go:79` — `INDICIA_TRACING_ENABLED=true` with an empty `INDICIA_OTEL_ENDPOINT` starts with no tracing, no error, no log: `Validate` returns nil early, `tracing.Setup` hands back the no-op provider, and the "tracing enabled" log needs a non-empty endpoint. otelgin still mounts. Pre-existing in `cmd/api`, now on both services.

Question — the test plan's end-to-end box is unchecked. Has one request been run through a real collector?

## Follow-ups

- Enabled-without-endpoint predates this PR in `cmd/api`. Own ticket.
- Removing the defaults is the root fix behind both Majors and far larger than this PR: 79 default-supplying call sites in `internal/config/config.go`, 14 raw `os.Getenv` calls in `internal/sidecar/config.go` with no helper layer, plus `.env.example`, `docker-compose.yml`, `make dev-setup`, and every test that builds a `Config`. About a dozen are the dangerous kind the gate exists to catch; the rest are tuning. Own ticket.
- Env-name branching outside `internal/config/config.go` is two sites: `internal/api/router.go:79` and the gate at `config.go:444`. `pkg/tracing/tracing.go:45` is a default value, not a branch.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-38/`
