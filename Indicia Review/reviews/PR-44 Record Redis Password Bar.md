---
name: PR-44 Record Redis Password Bar
date: 2026-10-29T11:10:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-44
  - inv-43527
---

# PR-44 Record Redis Password Bar

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/44
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43527-redis-password-strength-check`
- **Commits**: 4 · **Files changed**: 5 · **Lines**: +15 / −7
- **CI run**: 40866140829 — success
- **Reviewed**: 2026-10-29 · revised same day
- **Verdict**: Approve with comments · 2 Minor

## Scope

Records that a non-empty `INDICIA_REDIS_PASSWORD` is required in every environment, and that there is no length floor. Requirement INV-43527, parent INV-42087.

Three claims hold against head `e4be655`, which is after pull request 38. `validatePasswords` still rejects `strings.TrimSpace` empty, has no length check, and runs from `validateDeployedDefaults` on every name. Gates pass.

## First pass

11:10Z approved the production-and-staging wording and held the comment until pull request 38 merged. That merge landed at 11:25Z. The saved `raw/PR-44/diff.patch` is that earlier diff.

## Findings

```
Minor · .security/supplement.md:374
defect:  the storage-transport bullet still says immudb TLS is required in production and staging
reason:  internal/config/config.go validateVerifiedTLS — INDICIA_IMMUDB_TLS is required when INDICIA_REQUIRE_VERIFIED_TLS is true, and skipped when that flag is false
impact:  not fixed — the bullet this revision rewrote states the name gate pull request 38 removed, on the immudb clause beside the Redis clause it corrected
```

```
Minor · .security/supplement.md:379
defect:  the supply-chain bullet still names validateProductionConfig
reason:  internal/config/config.go — that function is validateDeployedDefaults, and Validate calls it on every name
impact:  not fixed — the supplement points at a function the merged pull request 38 removed
```

## Draft comment

Approve with comments. `validatePasswords` is unchanged. Empty or whitespace `INDICIA_REDIS_PASSWORD` fails startup in every environment, and a short non-empty password still starts. The environment guide, the config and Redis package docs, the closed `internal-config-1` row, and the security supplement now say there is no minimum length. Redis TLS follows `INDICIA_REQUIRE_VERIFIED_TLS`.

Minor · `.security/supplement.md:374` — the same storage-transport bullet still says immudb TLS is required in production and staging. `validateVerifiedTLS` requires `INDICIA_IMMUDB_TLS` when `INDICIA_REQUIRE_VERIFIED_TLS` is true, and does not require it when that flag is false.

Minor · `.security/supplement.md:379` — the next bullet still names `validateProductionConfig`. That function is `validateDeployedDefaults`, and `Validate` calls it on every name.

## Follow-ups

The pull request description still says the bar is production and staging. The files on this head do not.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-44/`
