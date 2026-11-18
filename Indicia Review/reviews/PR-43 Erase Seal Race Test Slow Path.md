---
name: PR-43 Erase Seal Race Test Slow Path
date: 2026-10-28T11:32:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-43
  - inv-43526
---

# PR-43 Erase Seal Race Test Slow Path

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/43
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43526-erase-seal-race-test`
- **Commits**: 1 · **Files changed**: 3 · **Lines**: +149 / −37
- **CI run**: 39944672194 — success
- **Reviewed**: 2026-10-28
- **Verdict**: Approve with comments · 1 Minor

## Scope

The erase and purge race tests take the slow path through `withMaxSealsPerDEK(1)` and fail if the shard lock is free across `DestroySubjectKey`. Requirement INV-43526, parent INV-42087.

Four claims hold. `tryLock` is called only from `requireShardHeldDuringDestroy`. `reserveWrite` at `seals >= limit` is the miss that sends `subjectDEK` into `v.locks.lock`. Gates pass.

## Findings

```
Minor · internal/keyvault/offboard_test.go:144
defect:  comment says each concurrent seal runs after the purge finished and finds an empty cache
reason:  keyvault.go:414 — "the shard lock is released as soon as that subject's own destroy completes"; cache.purgeTenant runs at keyvault.go:430, after destroySubjectLocked returns
impact:  not fixed — the seals required to succeed at offboard_test.go:146 are that window, and the comment places them after the purge
```

## Draft comment

Approve with comments. The shard lock blocks a concurrent slow-path seal of that subject only while it is held. `withMaxSealsPerDEK(1)` forces these seals onto that path. While `DestroySubjectKey` is blocked, `tryLock` fails the test if the shard is free, and a provision fails it if it runs before the gate opens. After the gate opens, each concurrent seal must succeed and `WriteMisses` must be the priming seal plus those seals. `tryLock` has no production caller.

Minor · `internal/keyvault/offboard_test.go:144` — the comment says each concurrent seal runs after the purge finished and finds an empty cache. The lock blocks those seals only inside `destroySubjectLocked`. That hold ends when `DestroySubjectKey` returns (`keyvault.go:450`). `cache.purgeTenant` runs after the loop (`keyvault.go:430`), with the lock already released, so the waiting seals run before the purge finishes. That is the re-provision at `keyvault.go:414`.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-43/`
