---
name: PR-48 Anchor Status Missing Batch 404
date: 2026-10-30T12:45:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-48
  - inv-43727
---

# PR-48 Anchor Status Missing Batch 404

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/48
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43727-anchor-status-missing-batch`
- **Commits**: 1 · **Files changed**: 7 · **Lines**: +109 / −16
- **CI run**: 40884947521 — success. Docker Build skipping (same-repo pull request). Dev/QA image build passed
- **Reviewed**: 2026-10-30
- **Verdict**: Approve

## Scope

`GET /events/{id}/anchor/status` returns 404 `not_found` / `Batch not found` when `batch_id` is set and that batch row is absent, and keeps 500 `retrieval_error` for every other failure reading the event or that row. This is the follow-up recorded on [PR 41](PR-41%20Document%20retrieval_error%20on%20Status%20Reads.md).

Four claims hold. Tenant access is still checked on the event before the batch read. `GetBatchByID` returns `ErrBatchNotFound` only for `pgx.ErrNoRows`; a permission error stays wrapped and is still 500. Gates pass.

## Findings

None.

## Draft comment

Approve.

## Follow-ups

`GET /events/{id}/verify` still returns 500 `retrieval_error` when the batch row is absent. `buildBatchVerifyResponse` wraps `ErrBatchNotFound`, and `Verify` maps every error from that function to 500. This pull request states that path is unchanged.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- [PR 41](PR-41%20Document%20retrieval_error%20on%20Status%20Reads.md)
- Artifacts: `raw/PR-48/`
