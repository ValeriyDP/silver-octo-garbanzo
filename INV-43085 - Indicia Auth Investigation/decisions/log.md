---
name: Decisions Log
date: 2026-10-13T09:50:00.000Z
tags:
  - indicia
  - inv-43085-auth-investigation
  - adr
  - log
---

# Decisions log

Append-only. Newest at the bottom.

- 2026-10-07 — Created ADR investigation (`decisions/`) for Indicia (INV-43085-auth-investigation). Register is empty.
- 2026-10-08 — Proposed [ADR-0001 Service Tokens for Ingest](ADR-0001%20Service%20Tokens%20for%20Ingest.md). Client-credentials Entities for ingest producers; user tokens remain for humans. Not accepted.
- 2026-10-12 — Updated [ADR-0001](ADR-0001%20Service%20Tokens%20for%20Ingest.md). Producer user-token ingest is replaced by the service token. A `company_admin` provisions those credentials for their own company. `RequireWriter` still admits `company_admin` and `global_admin` until open question 1. Not accepted.
- 2026-10-13 — Postponed [ADR-0001](ADR-0001%20Service%20Tokens%20for%20Ingest.md). Explanation: [Service Token Explanation](Service%20Token%20Explanation.md).
