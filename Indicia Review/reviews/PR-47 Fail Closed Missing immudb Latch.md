---
name: PR-47 Fail Closed Missing immudb Latch
date: 2026-10-28T11:48:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-47
  - inv-43522
---

# PR-47 Fail Closed Missing immudb Latch

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/47
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43522-missing-immudb-integrity-latch`
- **Commits**: 2 · **Files changed**: 7 · **Lines**: +163 / −40
- **CI run**: 40681786002 — Prioritize main still pending; the other jobs had not started
- **Reviewed**: 2026-10-28
- **Verdict**: Approve

## Scope

Startup exits when immudb cannot connect, and `/ready` is 503 when no integrity latch is attached. Requirement INV-43522, parent INV-42087.

Four claims hold. A nil immudb client makes `storeImmudbBatch` fail, and that failure is what the event worker dead-letters. `markIntegrityFailed` is still the only writer of `indicia_storage_immudb_integrity_failed`. CI had not started past Prioritize main.

## Findings

None.

## Draft comment

Approve. An immudb connect failure closes any client already opened and returns `connect immudb`, so the process exits. Postgres and Redis still stay nil and startup continues when those connects fail. `/ready` is 503 `integrity service not connected` when the latch is nil, and 503 `integrity verification failed` when it has tripped. `/health` stays 200: a missing latch is `degraded` with integrity `error`; a tripped latch stays `verification_failed`. `/health/live` is unchanged. The integrity gauge is still set only from the auditor latch.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-47/`
