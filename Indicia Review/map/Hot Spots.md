---
name: Hot Spots
date: 2026-10-27T08:20:00.000Z
tags:
  - indicia-review
  - pr-review
  - architecture
---

# Hot Spots

**Summary**: Where change concentrates, which seams break quietly, which documented standards no longer match the repository, and the complete list of standards sources a review should cite. Read this before the first review; re-read it when a review feels like it is arguing with the wrong rulebook.

**Sources**: `git log` over twelve months, `.cursor/rules/`, `CONTRIBUTING.md`, `docs/standards/CODING_STANDARDS.md`, the repository tree.

**Last updated**: 2026-10-27

---

## Where change lands

Commits touching each file over the last twelve months. The shape matters more than the numbers: the content sidecar and the event-type registry are the active frontier, and configuration is the permanent crossroads.

| Commits | File |
| ------: | ---- |
| 11 | `cmd/sidecar/main.go` |
| 10 | `cmd/api/main.go` |
| 9 | `internal/sidecar/http/handler.go` |
| 9 | `internal/config/config.go` |
| 9 | `tests/integration/sidecar_fulldata_test.go` |
| 8 | `pkg/eventtypes/config.go` |
| 8 | `internal/sidecar/http/erasure.go` |
| 7 | `pkg/eventtypes/types.go`, `pkg/eventtypes/tiers.go` |
| 7 | `internal/core/hashonly.go` |
| 7 | `internal/api/handlers/event_types.go` |
| 7 | `internal/sidecar/config.go` |
| 7 | `pkg/metrics/metrics.go` |

Three readings worth carrying into a review:

**The sidecar is young and moving.** It dominates the churn list, and its tests move with it. A sidecar diff that does not touch `tests/integration/sidecar_fulldata_test.go` or the package's own tests is unusual enough to ask about.

**`internal/config/config.go` is the crossroads.** It changes for every feature that needs a knob, which makes it the most likely place for an unrelated change to hitch a ride. Check that a config diff belongs to the pull request's stated scope, and that `docs/guides/ENVIRONMENT_VARIABLES.md` moved with it.

**`pkg/eventtypes` is a two-sided contract under active edit.** The sidecar validates payloads against it and the core resolves registration against it. A change here has to leave both sides accepting exactly the same events; the package's own documentation calls divergence a correctness defect rather than a style issue.

Separately, `internal/api/handlers` is the largest package in the repository at roughly 13,700 lines. Size alone is not a defect, but it is where a "one logical change per pull request" rule is easiest to violate without anyone noticing.

## Seams that break quietly

Ranked by how expensive the failure is, not by how often it happens.

**Canonical hashing.** `pkg/canonical` defines the byte-identical hashing contract, and anchored hashes are immutable. An encoding or leaf-derivation change must be a new scheme number, never an edit to an existing rule. Watch specifically for JSON decoding that drops `UseNumber()`, which silently turns exact numbers into `float64` and changes hashes for large values only — the worst possible failure shape, because small test fixtures pass.

**Authorization tier membership.** Covered in [Request Paths](Request%20Paths.md). The route-gating test proves a route is classified, not that it is classified correctly.

**The audit emitter's shape.** One entry point, constructed once. A second constructor is not a refactor; it removes the control.

**The role vocabulary.** Five names, closed set, with the audit record's role field validating against the same list. Adding a sixth role, or an alias for an existing one, has consequences two packages away.

**The content boundary.** The core must never gain a content-bearing field, and the sidecar must forward only hashes, locators, and pseudonyms. A new field on the hash-only envelope is the diff to read twice.

**Atomic claims and stale sweeps.** Covered in [Event Pipeline](Event%20Pipeline.md). Read-then-write where the codebase uses conditional-update-and-check-rows is a race regardless of how the code reads.

**immudb verification posture.** Verification strategy is documented in `docs/devops/IMMUDB_VERIFICATION_STRATEGY.md`, and the tamper-detection path has integration coverage. A diff that relaxes a verified read to an unverified one for performance is a Blocker unless the trade is argued explicitly.

## Standards sources

The repository documents more than `CONTRIBUTING.md` and `docs/standards/CODING_STANDARDS.md`. There are twelve rule files in `.cursor/rules/`, and several carry rules a reviewer would otherwise supply from memory — which means citing the file instead of an opinion:

| Rule file | Covers |
| --------- | ------ |
| `error-handling.mdc` | Always check errors; wrap with `%w`; stable API error shapes; no broad `recover()` |
| `logging.mdc` | zerolog via `pkg/logger`; no `log.Printf` in production paths; never log full tokens or keys; chained fields over concatenation |
| `testing.mdc` | Test expectations for touched packages |
| `configuration.mdc` | `INDICIA_*` conventions |
| `type-safety.mdc` | No new `interface{}` or untyped maps; narrow payloads toward structs |
| `security.mdc` | Secret handling, input validation, tenant isolation, transport |
| `go-style.mdc` | Formatting, naming, godoc on exported symbols |
| `licensing.mdc` | The full licence policy and the approved exception table |
| `ci.mdc` | The linter pin, its coupled coordinates, and post-push verification |
| `git-remotes.mdc` | `origin` as canonical remote; hooks are not bypassed with `--no-verify` |
| `project-structure.mdc` | Layout and common commands — **partly stale, see below** |
| `general.mdc` | Fail-fast, no silent fallbacks, no defensive programming by default |

## Documented standards that no longer match the repository

Each of these is a trap: enforcing them produces findings the author will correctly reject, and that is how a review loses credibility.

**There is no `admin-ui/`.** No `package.json`, no TypeScript, nothing in git history. The repository is Go with a handful of Python helper scripts under `scripts/`. `project-structure.mdc` lists an Angular admin dashboard, `CONTRIBUTING.md` asks for design-system CSS variables, and `licensing.mdc` instructs an npm licence check — none of which apply here. Treat the npm and Docker-base-image licence gates as not applicable until a frontend or a new image actually appears in a diff.

**Branch naming follows the ticket key, not `feat/`.** `CONTRIBUTING.md` documents `feat/<description>` and conventional commit subjects. Every recent branch uses `INV-<key>-<slug>`, and titles read `INV-<key> - <description>`. Dependabot branches use their own `dependabot/...` form. Review against observed practice; raise the documentation mismatch once as a Minor finding against `CONTRIBUTING.md` rather than against each pull request.

**`project-structure.mdc` predates most of the codebase.** It omits the content sidecar, `internal/keyvault`, `internal/audit`, `internal/operations`, `internal/registrysync`, `pkg/canonical`, and `pkg/eventtypes` — between them the majority of recent work. Use [Codebase Map](INDEX.md) for layout and that rule only for the command list.

**The CI job list is grouped differently than the rule describes.** There is no standalone `License Check` job; `scripts/license-check.sh` and `govulncheck` are steps inside **Build & Checks**, folded onto one runner. The jobs are Lint, Test, Integration Tests, Build & Checks, Docker Build, plus the main-priority gate and the re-run job.

## Current pull request backlog

A snapshot, not a durable fact: nine pull requests were open on 2026-10-27, numbered 38 to 47. The themes were immudb integrity classification and fail-closed behaviour, Redis password strength recording, an erasure and seal race condition in test, tracing changes for health probes and the sidecar, API specification corrections, and two Dependabot bumps.

Two implications for the first few reviews. The immudb integrity work and the erasure race touch the seams listed above, so those reviews are the ones to take slowly. And several pull requests are documentation-only corrections to `docs/api/API_SPECIFICATION.md` — for those, the Spec axis is the whole review and the gate checklist is mostly not applicable.

## Related pages

- [Codebase Map](INDEX.md)
- [Request Paths](Request%20Paths.md)
- [Event Pipeline](Event%20Pipeline.md)
- [Review register](../reviews/INDEX.md)
