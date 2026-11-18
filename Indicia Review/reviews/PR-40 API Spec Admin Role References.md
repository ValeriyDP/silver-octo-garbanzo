---
name: PR-40 API Spec Admin Role References
date: 2026-10-28T09:57:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-40
  - inv-43524
---

# PR-40 API Spec Admin Role References

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/40
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43524-api-spec-admin-role-references`
- **Commits**: 2 · **Files changed**: 1 · **Lines**: +15 / −15
- **CI run**: 40668329119 — Prioritize main still pending; the other jobs had not started
- **Reviewed**: 2026-10-28
- **Verdict**: Approve with comments · 1 Minor

## Scope

Replaces bare "admin" wording in `docs/api/API_SPECIFICATION.md` with the D5 roles each line admits. Requirement INV-43524, parent INV-42087.

Four PR-body claims hold. Gates pass. CI had not started past Prioritize main.

## Findings

```
Minor · docs/api/API_SPECIFICATION.md:841
defect:  the heading still says Operations Endpoints require the global_admin role
reason:  internal/api/router.go:537 applies RequireOperator to the whole /ops group, and GET/DELETE /ops/operations are registered on that group at router.go:663. RequireOperator admits operator or global_admin (middleware/auth.go:243)
impact:  not fixed — operator is admitted to those routes and the heading says they are not. The paragraph under the heading was edited in this PR
```

## Draft comment

Approve with comments. The three sentences match the gates: `RequireWriter` is `writer`, `company_admin`, `global_admin` (`middleware/auth.go:213`); `validateTenantAccess` lets only `global_admin` cross tenants (`events.go:180`); sidecar `POST /v1/events` uses that same writer gate (`sidecar/router.go:119`) while read, quarantine, and erasure do not admit `global_admin` or `operator`. A case-sensitive `admin` search leaves only `company_admin`, `global_admin`, and `/admin` paths.

Minor · `docs/api/API_SPECIFICATION.md:841` — the heading still says Operations Endpoints require `global_admin`. Those routes sit on the `/ops` group, which is `RequireOperator`: `operator` or `global_admin` (`internal/api/router.go:537`, operations at `:663`). `operator` is admitted and the heading says they are not.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-40/`
