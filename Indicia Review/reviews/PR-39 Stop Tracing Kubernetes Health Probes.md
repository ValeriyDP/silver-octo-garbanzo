---
name: PR-39 Stop Tracing Kubernetes Health Probes
date: 2026-10-28T08:38:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-39
  - inv-43586
---

# PR-39 Stop Tracing Kubernetes Health Probes

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/39
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43586-stop-tracing-kubernetes-health-probes`
- **Commits**: 2 · **Files changed**: 2 · **Lines**: +91 / −14
- **CI run**: 40658267798 — still pending at review (Lint, Test, Integration Tests, Build & Checks). Docker Build skipping. Prioritize main passed
- **Reviewed**: 2026-10-28
- **Verdict**: Approve

## Scope

`otelgin` on the core skips the same seven operational paths request logging already skips, so probe traffic stops filling Tempo. Requirement INV-43586, parent INV-43103.

Three PR-body claims hold. Gates pass. CI had not finished.

## Findings

None.

## Draft comment

Approve. Probe and operational paths now share the request-log skip list, and `TestRouter_QuietPathsAreNotTraced` checks both directions: those seven paths emit no spans, a path outside the list still does.

## Follow-ups

- The Tempo box in the test plan is a post-deploy check. The span decision is already pinned in-process.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-39/`
