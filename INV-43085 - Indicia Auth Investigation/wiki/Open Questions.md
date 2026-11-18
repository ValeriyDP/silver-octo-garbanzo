---
name: Open Questions
date: 2026-10-13T09:50:00.000Z
tags:
  - indicia
  - inv-43085-auth-investigation
  - wiki
---

# Open Questions

**Summary**: Parking lot for things we do not know yet. Promote a question to an ADR in `decisions/` when a design choice is required.

**Sources**: `docs/plans/SECURITY_ASSESSMENT_2026-08-14_BACKLOG.md` (`internal-api-3`); `internal/sidecar/router.go` (`RequireWriter` on ingest); [Current Auth Flow](Current%20Auth%20Flow.md).

**Last updated**: 2026-10-13

---

| # | Question | Notes | Status |
| - | -------- | ----- | ------ |
| 1 | Should sidecar ingest stop admitting `global_admin`? | `RequireWriter` lets `global_admin` through `POST /v1/events` when the token also has `company_id`. D5c already keeps that role off the read door. Backlog `internal-api-3` calls the ingest case a design violation and leaves the narrowing conditional on FusionAuth claim shape. See [Current Auth Flow](Current%20Auth%20Flow.md). [ADR-0001](ADR-0001%20Service%20Tokens%20for%20Ingest.md) leaves this open: a service token would be `writer` only, and `company_admin` / `global_admin` user tokens can still ingest until this row is decided. | open |
| 2 | Should ingest producers use client-credentials Entities instead of user tokens? | Postponed. [Service Token Explanation](Service%20Token%20Explanation.md). The design remains [ADR-0001](ADR-0001%20Service%20Tokens%20for%20Ingest.md). The shipped path remains user JWTs. | postponed |

When a row becomes a decision, add the ADR and link it here. Leave the question in place with status `decided` and a link, so the wiki still explains *what we asked*.

## Related pages

- [Current Auth Flow](Current%20Auth%20Flow.md)
- [Wiki Index](Indicia%20Auth%20Investigation%20(INV-43085)/wiki/index.md)
- [Decision register](Indicia%20Auth%20Investigation%20(INV-43085)/decisions/INDEX.md)
- [ADR-0001 Service Tokens for Ingest](ADR-0001%20Service%20Tokens%20for%20Ingest.md)
- [Service Token Explanation](Service%20Token%20Explanation.md)
