---
name: PR-49 Stop Leaking Database Errors on Reads
date: 2026-10-30T12:55:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-49
  - inv-43726
---

# PR-49 Stop Leaking Database Errors on Reads

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/49
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43726-database-error-read-leaks`
- **Commits**: 1 · **Files changed**: 6 · **Lines**: +217 / −31
- **CI run**: 40897805752 — success. Docker Build skipping (same-repo pull request). Dev/QA image build passed
- **Reviewed**: 2026-10-30
- **Verdict**: Approve

## Scope

Read endpoints stop putting database driver text in the JSON body. `GET /events` and `GET /batches` return 500 `internal_error` / `Failed to resolve external_id` when an `external_id` lookup fails for a reason other than a missing company. `GET /ops/operations` and `GET /ops/operations/{id}` keep 500 and replace `err.Error()` with a fixed string. A missing company and a missing operation stay 400 and 404.

Three claims hold. `GetCompanyByExternalID` returns `ErrCompanyNotFound` only for `pgx.ErrNoRows`; any other lookup error is wrapped and is not that sentinel, so `writeResolveCompanyIDError` keeps it off the 400 arm. `AdminOperationsHandler.Get` still returns 404 `operation not found` before the store-failure arm. Gates pass.

## Findings

None.

## Draft comment

Approve.

## Follow-ups

The pull request states these paths are unchanged, and they still put the driver text in the body:

- `POST /events` — `internal/api/handlers/events_hashonly.go:76` writes `resolveErr.Error()`. `resolvePayloadCompanyID` still wraps `GetByExternalID` as `failed to resolve external_id: %w`.
- `POST /admin/users` — `internal/api/handlers/users.go:241` writes `err.Error()`. `UsersHandler.resolveCompanyID` wraps the same lookup.
- Company admin default arm — `internal/api/handlers/companies.go:421` writes `Operation failed: ` plus `err.Error()`.

`DELETE /ops/operations/{id}` is unchanged and already returns `msgFailedCancelOperation`.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-49/`
