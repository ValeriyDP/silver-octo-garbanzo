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

Knowledge base for **NVNM-Cite (INV-42043)**. How-tos, diagrams, current state, open questions. Start with [Onboarding](NVNM-Cite%20(INV-42043)/wiki/Onboarding.md).

Decisions live in [decisions/INDEX](NVNM-Cite%20(INV-42043)/decisions/INDEX.md). Cross-link; do not copy ADRs here.

## Pages

- [Onboarding](NVNM-Cite%20(INV-42043)/wiki/Onboarding.md) — First-day map: two jobs, what “lock” means, who, how to run.
- [Audience](NVNM-Cite%20(INV-42043)/wiki/Audience.md) — Who the product is for (and who it is not).
- [Prerequisites](NVNM-Cite%20(INV-42043)/wiki/Prerequisites.md) — Invariants, chain picture, tools before you open the code.
- [Run Locally](NVNM-Cite%20(INV-42043)/wiki/Run%20Locally.md) — Boot the web app, CLI check, optional Docker.
- [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md) — Vanilla JS + static HTML/CSS. The `$` helper is not jQuery.
- [Backend](NVNM-Cite%20(INV-42043)/wiki/Backend.md) — Stdlib `ThreadingHTTPServer`. No Flask/FastAPI/Django.
- [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md) — Upload → extract → map to registry + key → keyed `records()` read. Not a chain scan.
- [Canonical Citation](NVNM-Cite%20(INV-42043)/wiki/Canonical%20Citation.md) — Standard key `<volume> <edition> <first-page>` and wild→standard corner cases (`cite-canonical/v1`).
- [Document Hash](NVNM-Cite%20(INV-42043)/wiki/Document%20Hash.md) — SHA-256 binds the exact filing to a receipt. Not used to look up cites.
- [Why Python](NVNM-Cite%20(INV-42043)/wiki/Why%20Python.md) — No language ADR. Inferred from eyecite / Free Law Project stack.
- [Eyecite](NVNM-Cite%20(INV-42043)/wiki/Eyecite.md) — FLP Python library that finds citations in text. Not a citator; not a chain client.
- [Authentication](NVNM-Cite%20(INV-42043)/wiki/Authentication.md) — No app login or API keys. Wallet signs receipts; Check/Verify are open.
- [Uploaded Documents](NVNM-Cite%20(INV-42043)/wiki/Uploaded%20Documents.md) — Stable file types (pdf/docx/txt/md); no per-court form. Lookup keys on the citation, not the case name.
- [Registry Maintenance](NVNM-Cite%20(INV-42043)/wiki/Registry%20Maintenance.md) — Bulk load + incremental updates. The "case name + citation number" quote is this path, not Check uploads.
- [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md) — Open: Q1, Q4, Q6. Closed/withdrawn: Q2, Q3, Q5.
- [GA Events](NVNM-Cite%20(INV-42554)/GA%20Events.md) — INV-42554 (`INV-42554-ga`): required + extra Analytics events for the web page.

## Related

- [Project README](NVNM-Cite%20(INV-42043)/README.md)
- [AGENTS](NVNM-Cite%20(INV-42043)/AGENTS.md)
- [CLAUDE](NVNM-Cite%20(INV-42043)/CLAUDE.md)
