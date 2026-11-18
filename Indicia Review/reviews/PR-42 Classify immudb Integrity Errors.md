---
name: PR-42 Classify immudb Integrity Errors on Pinned Sentinel Text
date: 2026-10-28T10:48:00.000Z
tags:
  - indicia-review
  - pr-review
  - pr-42
  - inv-43523
---

# PR-42 Classify immudb Integrity Errors on Pinned Sentinel Text

- **Pull request**: https://github.com/inveniamcapital/InveniamIndicia/pull/42
- **Author**: mykhailonovak-devpro
- **Base ← Head**: `main` ← `INV-43523-immudb-integrity-error-classification`
- **Commits**: 2 · **Files changed**: 3 · **Lines**: +129 / −2
- **CI run**: 40675046605 — Prioritize main still pending; the other jobs had not started
- **Reviewed**: 2026-10-28
- **Verdict**: Approve

## Scope

The immudb auditor latches on a server corruption status whose message contains the pinned sentinel text, so a wrap no longer leaves `/ready` healthy. Requirement INV-43523, parent INV-42087.

Three claims hold. `mapServerError` in immudb v1.11.2 returns `ErrCorruptedData` and `ErrCorruptedTxData` unchanged, and those sentinels are `"data is corrupted"` and `"tx data is corrupted"`. The status text is not copied onto `/ready`.

## Findings

None.

## Draft comment

Approve. A server corruption status now trips the integrity latch when a whole `": "` segment equals the pinned sentinel, including a prefix wrap. A substring, a reword, and any code other than `Unknown` or `Internal` do not. Client-local sentinels are unchanged.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-42/`
