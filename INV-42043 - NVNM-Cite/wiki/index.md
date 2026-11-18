---
name: Wiki Index
date: 2026-08-31T13:15:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - index
---

# Wiki Index

Knowledge base for **NVNM-Cite (INV-42043)**. How-tos, diagrams, current state, open questions. Start with [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md).

Decisions live in [decisions/INDEX](INV-42043%20-%20NVNM-Cite/decisions/INDEX.md). Cross-link; do not copy ADRs here.

## Pages

- [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md) — First-day map: two jobs, what “lock” means, who, how to run.
- [Audience](INV-42043%20-%20NVNM-Cite/wiki/Audience.md) — Who the product is for (and who it is not).
- [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md) — Invariants, chain picture, tools before you open the code.
- [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md) — Boot the web app, CLI check, optional Docker.
- [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md) — Vanilla JS + static HTML/CSS. The `$` helper is not jQuery.
- [Backend](INV-42043%20-%20NVNM-Cite/wiki/Backend.md) — Stdlib `ThreadingHTTPServer`. No Flask/FastAPI/Django.
- [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md) — Upload → extract → map to registry + key → keyed `records()` read. Not a chain scan.
- [Canonical Citation](INV-42043%20-%20NVNM-Cite/wiki/Canonical%20Citation.md) — Standard key `<volume> <edition> <first-page>` and wild→standard corner cases (`cite-canonical/v1`).
- [Document Hash](INV-42043%20-%20NVNM-Cite/wiki/Document%20Hash.md) — SHA-256 binds the exact filing to a receipt. Not used to look up cites.
- [Why Python](INV-42043%20-%20NVNM-Cite/wiki/Why%20Python.md) — No language ADR. Inferred from eyecite / Free Law Project stack.
- [Eyecite](INV-42043%20-%20NVNM-Cite/wiki/Eyecite.md) — FLP Python library that finds citations in text. Not a citator; not a chain client.
- [Authentication](INV-42043%20-%20NVNM-Cite/wiki/Authentication.md) — No app login or API keys. Wallet signs receipts; Check/Verify are open.
- [Uploaded Documents](INV-42043%20-%20NVNM-Cite/wiki/Uploaded%20Documents.md) — Stable file types (pdf/docx/txt/md); no per-court form. Lookup keys on the citation, not the case name.
- [Registry Maintenance](INV-42043%20-%20NVNM-Cite/wiki/Registry%20Maintenance.md) — Bulk load + incremental updates. The "case name + citation number" quote is this path, not Check uploads.
- [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md) — Open: Q1, Q4, Q6. Closed/withdrawn: Q2, Q3, Q5.
- [GA Events](INV-42554%20-%20NVNM-Cite/GA%20Events.md) — INV-42554 (`INV-42554-ga`): required + extra Analytics events for the web page.

## Related

- [Project README](INV-42043%20-%20NVNM-Cite/README.md)
- [AGENTS](INV-42043%20-%20NVNM-Cite/AGENTS.md)
- [CLAUDE](INV-42043%20-%20NVNM-Cite/CLAUDE.md)
