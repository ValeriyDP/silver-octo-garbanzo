---
name: Open Questions
date: 2026-09-01T06:22:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Open Questions

**Summary**: Parking lot for things we do not know yet. Closed questions stay on this page so we still see *what we asked*. Promote a still-open fork to an ADR in `decisions/` when a design choice is required.

**Sources**: [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md), [Backend](NVNM-Cite%20(INV-42043)/wiki/Backend.md), [Uploaded Documents](NVNM-Cite%20(INV-42043)/wiki/Uploaded%20Documents.md), [Registry Maintenance](NVNM-Cite%20(INV-42043)/wiki/Registry%20Maintenance.md), [raw/Registry Maintenance Excerpt](NVNM-Cite%20(INV-42043)/raw/Registry%20Maintenance%20Excerpt.md), `src/nvnm_cite/webapp/server.py`

**Last updated**: 2026-09-01

---

## Open

| #   | Question                                                                                                                                                                                                                 | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Status |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1   | Could we use a modern frontend framework (React, Vue, Svelte, …) instead of the raw `app.js` page?                                                                                                                       | Today: no-framework static HTML/CSS + one vanilla JS file. `$` is `getElementById`, not jQuery. Trust constraints that any rewrite must keep: no JS ABI, no private keys in the page, `textContent` only (never `innerHTML`), CSP `script-src 'self'`. See [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md). Promote to an ADR when we pick stay / rewrite / hybrid.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | open   |
| 4   | Where do we get a CourtListener API key ([courtlistener.com](https://www.courtlistener.com/))? Is it paid? Or would a crawler fetch the data — and if so, would we use a third-party service that hides the fetch/parse? | **Gathering only; not choosing yet.** Shipped paths are official, not a hidden crawler: (1) quarterly **bulk CSVs** from `storage.courtlistener.com` (no token in the loader), (2) REST v4 incremental (`loader/update.py`) which **requires** `COURTLISTENER_TOKEN`. Repo says "free account at courtlistener.com" (source: `.env.example`). Paid tier / current rate limits: **unverified** — confirm on CL's API docs before any ADR. The **Check upload does not call CourtListener**; it reads NVNM Chain. See [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md) and [Registry Maintenance](NVNM-Cite%20(INV-42043)/wiki/Registry%20Maintenance.md). A stealth-crawler / "hide our parsing" path is not in the code (CL already bot-protects some HTML with HTTP 202 — source: DECISIONS.md). Promote to an ADR if we lock API-only vs crawl. | open   |
| 6   | Use a well-known **backend** web framework (Flask / FastAPI / Django / …) instead of the stdlib server, and **SQLAlchemy** as the ORM instead of raw SQL in methods?                                                     | **Stated preference (this investigation), not an ADR yet.** Today: `server.py` docstring — *“Stdlib HTTP server for the web demo. No frameworks, no new deps.”* See [Backend](NVNM-Cite%20(INV-42043)/wiki/Backend.md). SQL is `sqlite3` + handwritten SQL in `loader/*`, `chain/indexer.py`, `webapp/localindex.py`, `verifier/telemetry.py`. The **public Check path does not need a DB** (chain is the authority; SQLite is optional cache / loader / telemetry). Related frontend question: Q1. Promote to an ADR when we pick stay / framework+SQLAlchemy / split.                                                                                                                                                                                                                                                                                                                       | open   |

## Closed

Numbers stay. Do not reuse them.

| # | Question | Closed because | Status |
| - | -------- | -------------- | ------ |
| 2 | Where did "only the case name and citation number are required" come from? | **Removed.** Source is known; Check citation path is understood. See [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md) and [Registry Maintenance](NVNM-Cite%20(INV-42043)/wiki/Registry%20Maintenance.md). Number 2 is not reused. | withdrawn 2026-09-01 |
| 3 | Is the "automated bot / case name + citation number / ≤50 cases per week" path still the intended near-term update, or has `loader/update.py` (CourtListener incremental) superseded it? | Update / crawl bot can be designed at later stages. Not in scope for this investigation. Notes remain on [Registry Maintenance](NVNM-Cite%20(INV-42043)/wiki/Registry%20Maintenance.md). | closed 2026-09-01 |
| 5 | Why was Python chosen? Were other languages considered? | This project is **locked to the eyecite library** (and thus to Python for the normalizer). No language bake-off in this investigation. Background: [Why Python](NVNM-Cite%20(INV-42043)/wiki/Why%20Python.md), [Eyecite](NVNM-Cite%20(INV-42043)/wiki/Eyecite.md). | closed 2026-09-01 |

When a still-open row becomes a decision, add the ADR and move it here with a link, so the wiki still explains *what we asked*.

## Related pages

- [Backend](NVNM-Cite%20(INV-42043)/wiki/Backend.md)
- [Why Python](NVNM-Cite%20(INV-42043)/wiki/Why%20Python.md)
- [Registry Maintenance](NVNM-Cite%20(INV-42043)/wiki/Registry%20Maintenance.md)
- [Uploaded Documents](NVNM-Cite%20(INV-42043)/wiki/Uploaded%20Documents.md)
- [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md)
- [Onboarding](NVNM-Cite%20(INV-42043)/wiki/Onboarding.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
- [Decision register](NVNM-Cite%20(INV-42043)/decisions/INDEX.md)
