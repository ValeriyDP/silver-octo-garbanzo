---
name: Review log
date: 2026-10-27T08:10:00.000Z
tags:
  - indicia-review
  - pr-review
  - log
---

# Review log

Append-only. Newest at the bottom.

- 2026-10-27 — Folder repurposed from the generic investigation template into a pull request review workspace for the Inveniam Indicia API. Register is empty.
- 2026-10-27 — Built the codebase map from the repository at the commit merging pull request 37: [map/INDEX](../map/INDEX.md), [Request Paths](../map/Request%20Paths.md), [Event Pipeline](../map/Event%20Pipeline.md), [Hot Spots](../map/Hot%20Spots.md). Corrected two gates in CLAUDE.md that the repository contradicts — there is no frontend to run an npm licence check against, and branch naming follows the ticket key rather than the `feat/` form documented in `CONTRIBUTING.md`.
- 2026-10-27 — Dependabot PRs 45 and 46 checked for merge readiness only. Both ready; 45 carries a stale `Dockerfile:26` refresh instruction as a non-blocking Minor. No review pages filed — dependabot is technical.
- 2026-10-27 — Reviewed [PR 38](PR-38%20Trace%20The%20Sidecar%20And%20Pass%20Context%20To%20Core.md) (sidecar tracing, trace context to core): Approve with comments, 0 blockers, 2 Minor, 1 Question.
- 2026-10-27 — Revised [PR 38](PR-38%20Trace%20The%20Sidecar%20And%20Pass%20Context%20To%20Core.md) to Request changes, 2 Major. The author-side inline comments on `internal/config/config.go:14` and `:444` are correct and I had missed both: I verified "unknown `INDICIA_ENVIRONMENT` fails sidecar startup" as faithful to the PR body without asking whether the claim should hold. Lesson for the loop — a verified spec claim can still be the defect. The environment string is simultaneously the `deployment.environment` telemetry label (must be open-ended; one Grafana Alloy consumer fronts many dev clusters) and a closed security enum (the production gate fails open on any name outside it).
- 2026-10-27 — Encoded the PR 38 lesson as a rule: CLAUDE.md gains "A verified claim can still be the defect" under the two axes, and the review template's Spec section now requires two columns per claim — "Does the code do this?" and "Should it?", the second carrying `needs human:` when the answer is outside this repository.
- 2026-10-27 — Stripped the PR 38 page from 1,770 to ~1,000 words and dropped its Gates and Spec sections. New output rule: gates and PR-body claims are still checked on every review, but a pass produces no text — Scope carries one line that the checks ran, and only failures become findings. Template and CLAUDE.md updated to match; the axis subheaders are gone, since the `reason` line already names the rule file or the spec line.
- 2026-10-28 — Reviewed [PR 39](PR-39%20Stop%20Tracing%20Kubernetes%20Health%20Probes.md) (stop tracing Kubernetes health probes): Approve, no findings. CI run 40658267798 was still pending.
- 2026-10-28 — Reviewed [PR 40](PR-40%20API%20Spec%20Admin%20Role%20References.md) (API spec admin role wording): Approve with comments, 1 Minor. The four claims match RequireWriter, validateTenantAccess, and the sidecar ingest gate. The Operations heading still says global_admin only while /ops is RequireOperator.
- 2026-10-28 — Reviewed [PR 41](PR-41%20Document%20retrieval_error%20on%20Status%20Reads.md): Request changes, 1 Major. The published 500 covers both a store failure and a missing batch row. The missing row is wrong data and belongs in 4xx; the SELECT-denied sub-lookup stays 5xx.
- 2026-10-28 — Revised [PR 41](PR-41%20Document%20retrieval_error%20on%20Status%20Reads.md) to Approve. The 500-vs-4xx split on a missing batch row is a separate change; this PR documents the contract the handler already has.
- 2026-10-28 — Reviewed [PR 42](PR-42%20Classify%20immudb%20Integrity%20Errors.md): Approve, no findings. CI run 40675046605 had not started past Prioritize main. The sentinel text stays off /ready.
- 2026-10-28 — Reviewed [PR 43](PR-43%20Erase%20Seal%20Race%20Test%20Slow%20Path.md) (INV-43526, erase/seal race test slow path): Approve with comments, 0 blockers, 1 Minor. CI run 39944672194 succeeded. The purge-test comment places the concurrent seals after `cache.purgeTenant`; `destroySubjectLocked` releases the shard lock first.
- 2026-10-28 — Revised the PR 43 draft comment. The shard lock blocks concurrent slow-path seals only while held; `PurgeTenant` releases it when `DestroySubjectKey` returns, before `cache.purgeTenant`. Not posted.
- 2026-10-28 — Reviewed [PR 47](PR-47%20Fail%20Closed%20Missing%20immudb%20Latch.md) (INV-43522, fail closed on a missing immudb latch): Approve, no findings. CI run 40681786002 had not started past Prioritize main. Startup exits when immudb cannot connect; a nil latch is `/ready` 503 and is not an integrity-gauge trip.
- 2026-10-29 — Reviewed [PR 44](PR-44%20Record%20Redis%20Password%20Bar.md) (INV-43527, non-empty Redis password bar): Approve, no findings. CI run 40689732547 succeeded. Docs only. `validatePasswords` still rejects a trimmed-empty password and has no length floor.
- 2026-10-29 — PR 44 is held until PR 38 merges. PR 38 requires `INDICIA_REDIS_PASSWORD` in every environment and drops the production and staging wording this pull request documents. The no-minimum-length sentence is re-applied after that merge. Not posted.
- 2026-10-29 — Re-reviewed [PR 44](PR-44%20Record%20Redis%20Password%20Bar.md) at head e4be655, after PR 38 merged. Approve with comments, 2 Minor. The Redis sentences now say every environment and no minimum length. `.security/supplement.md:374` still says immudb TLS is required in production and staging, and `:379` still names `validateProductionConfig`. CI run 40866140829 succeeded.
- 2026-10-30 — Reviewed [PR 48](PR-48%20Anchor%20Status%20Missing%20Batch%20404.md) (INV-43727, anchor-status missing batch is 404): Approve, no findings. CI run 40884947521 succeeded. Closes the PR 41 follow-up. `Verify` still maps a missing batch row to 500; this pull request leaves that path unchanged. Not posted.
- 2026-10-30 — Reviewed [PR 49](PR-49%20Stop%20Leaking%20Database%20Errors%20on%20Reads.md) (INV-43726, stop leaking database errors on read endpoints): Approve, no findings. CI run 40897805752 succeeded. The read excerpt holds. `POST /events`, `POST /admin/users`, and the company admin default arm still put driver text in the body. `DELETE /ops/operations/{id}` already uses a fixed message. Not posted.
