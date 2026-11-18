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

Decisions live in [decisions/INDEX](INV-43085%20-%20Indicia%20Auth%20Investigation/decisions/INDEX.md). Cross-link; do not copy ADRs here.

## Pages

- [Current Auth Flow](Current%20Auth%20Flow.md) — Producer → sidecar and sidecar → core: one FusionAuth JWT, forwarded. PlantUML sequences.
- [Auth Doors](Auth%20Doors.excalidraw.md) — Door-by-role map (who is admitted, refused, or blocked for lack of `company_id`).
- [Open Questions](INV-43085%20-%20Indicia%20Auth%20Investigation/wiki/Open%20Questions.md) — Questions that are not decisions yet.
- [Service Token Explanation](Service%20Token%20Explanation.md) — What was considered, what was found, and why the service-token change is postponed.

Postponed: [ADR-0001 Service Tokens for Ingest](ADR-0001%20Service%20Tokens%20for%20Ingest.md). The shipped path stays [Current Auth Flow](Current%20Auth%20Flow.md).

## Related

- [Project README](INV-43085%20-%20Indicia%20Auth%20Investigation/README.md)
- [CLAUDE](INV-43085%20-%20Indicia%20Auth%20Investigation/CLAUDE.md)
