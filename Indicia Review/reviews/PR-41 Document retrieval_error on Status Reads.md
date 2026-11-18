---
name: PR-41 Document retrieval_error on Status Reads
date: 2026-10-28T10:07:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-41
  - inv-43525
---

# PR-41 Document retrieval_error on Status Reads

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/41
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43525-retrieval-error-status-reads`
- **Commits**: 1 · **Files changed**: 5 · **Lines**: +16 / −11
- **CI run**: 39918620187 — Lint, Test, Integration Tests, Build & Checks pass. Docker Build skipping
- **Reviewed**: 2026-10-28
- **Verdict**: Approve

## Scope

Documents the existing 500 `retrieval_error` on `GET /events/{id}/anchor/status` and `GET /batches/{id}` in the API spec and swagger. Requirement INV-43525, parent INV-42087.

Three claims hold. The handler is unchanged, and the annotations match the generated spec. CI is green.

## Findings

None.

## Draft comment

Approve. The spec and swagger now name the 500 `retrieval_error` these two reads already return. Handler codes are unchanged.

## Follow-ups

- Separate PR. `GetAnchorStatus` returns 500 `retrieval_error` for a missing batch row (`events.go:372`), the same status it uses when the store cannot `SELECT` the second table (`status_reads_test.go:150`). `GetBatch` already returns 404 for `ErrBatchNotFound` (`events.go:768`). A missing joined row is 4xx. A store failure stays 5xx. Not this PR: it documents the current contract.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-41/`
