---
name: Wiki Index
date: 2026-10-13T09:50:00.000Z
tags:
  - indicia
  - inv-43085-auth-investigation
  - wiki
  - index
---

# Wiki Index

Knowledge base for **Indicia (INV-43085-auth-investigation)**. How-tos, diagrams, current state, open questions.

Decisions live in [decisions/INDEX](Indicia%20Auth%20Investigation%20(INV-43085)/decisions/INDEX.md). Cross-link; do not copy ADRs here.

## Pages

- [Current Auth Flow](Current%20Auth%20Flow.md) — Producer → sidecar and sidecar → core: one FusionAuth JWT, forwarded. PlantUML sequences.
- [Auth Doors](Auth%20Doors.excalidraw.md) — Door-by-role map (who is admitted, refused, or blocked for lack of `company_id`).
- [Open Questions](Indicia%20Auth%20Investigation%20(INV-43085)/wiki/Open%20Questions.md) — Questions that are not decisions yet.
- [Service Token Explanation](Service%20Token%20Explanation.md) — What was considered, what was found, and why the service-token change is postponed.

Postponed: [ADR-0001 Service Tokens for Ingest](ADR-0001%20Service%20Tokens%20for%20Ingest.md). The shipped path stays [Current Auth Flow](Current%20Auth%20Flow.md).

## Related

- [Project README](Indicia%20Auth%20Investigation%20(INV-43085)/README.md)
- [CLAUDE](Indicia%20Auth%20Investigation%20(INV-43085)/CLAUDE.md)
