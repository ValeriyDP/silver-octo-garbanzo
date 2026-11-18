---
name: Wiki Log
date: 2026-08-31T13:15:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - log
---

# Wiki log

Append-only. Newest at the bottom.

- 2026-08-31 — Created knowledge base (`wiki/`) for NVNM-Cite (INV-42043) (INV-42043). Starter page: [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md).
- 2026-08-31 — Onboarding set: [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md), [Audience](INV-42043%20-%20NVNM-Cite/wiki/Audience.md), [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md), [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md). Sourced from the app README, CLAUDE.md, web-demo, brief-for-firms, DEPLOYMENT.
- 2026-08-31 — [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md): first-class Docker path from the repo `Dockerfile` (build this checkout); GHCR pull is the published-image alternative. [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md) updated: uv **or** Docker.
- 2026-08-31 — [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md): no-framework static page; `$` is `getElementById`, not jQuery.
- 2026-08-31 — [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md) Q1: could we use a modern frontend framework? Status open. Linked from [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md).
- 2026-08-31 — [Uploaded Documents](INV-42043%20-%20NVNM-Cite/wiki/Uploaded%20Documents.md): file types are stable; no per-court form; existence key is the canonical citation. [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md) Q2: source of "only the case name and citation number are required."
- 2026-08-31 — Ingested [raw/Registry Maintenance Excerpt](INV-42043%20-%20NVNM-Cite/raw/Registry%20Maintenance%20Excerpt.md). New page [Registry Maintenance](INV-42043%20-%20NVNM-Cite/wiki/Registry%20Maintenance.md). Q2 updated (applies to registry bot, not Check). Q3: does `update.py` supersede the two-field / 50-cases-per-week bot?
- 2026-08-31 — [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md): keyed lookup, not a scan. Q3 parked (bot out of scope for now).
- 2026-08-31 — [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md) Q4: CourtListener API key (paid vs free)? Crawler vs official API/bulk? Hide-parse service? Gathering only.
- 2026-08-31 — [Why Python](INV-42043%20-%20NVNM-Cite/wiki/Why%20Python.md): no language-choice ADR; eyecite is the inferential reason. Q5 added.
- 2026-08-31 — [Eyecite](INV-42043%20-%20NVNM-Cite/wiki/Eyecite.md): what the library is and how this repo wraps it.
- 2026-09-01 — [Eyecite](INV-42043%20-%20NVNM-Cite/wiki/Eyecite.md): Check/normalizer is built around eyecite; the chain/receipt product is not.
- 2026-09-01 — [Authentication](INV-42043%20-%20NVNM-Cite/wiki/Authentication.md): no user auth; wallet + chain ACL only.
- 2026-09-01 — [Backend](INV-42043%20-%20NVNM-Cite/wiki/Backend.md): stdlib HTTP only; no web framework.
- 2026-09-01 — [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md) Q6: well-known web framework + SQLAlchemy instead of stdlib server and raw `sqlite3` SQL. Cites `server.py` (“No frameworks, no new deps.”).
- 2026-09-01 — Closed Q3 (update/crawl bot later) and Q5 (locked to eyecite). New Closed section; numbers kept.
- 2026-09-01 — Q2 withdrawn (source known; citation path understood). Number not reused.
- 2026-09-01 — Renumbered questions: Open 1–3 (frontend, CourtListener, backend+SQLAlchemy). Closed 1–3 (quote withdrawn, bot later, locked to eyecite).
- 2026-09-01 — Reverted numbering. Open Q1, Q4, Q6. Closed Q2, Q3, Q5. Gaps kept.
- 2026-09-01 — [Canonical Citation](INV-42043%20-%20NVNM-Cite/wiki/Canonical%20Citation.md): ingested cite-canonical/v1 key shape and wild→standard corner cases. The wiki only had a one-line example before.
- 2026-09-01 — [Document Hash](INV-42043%20-%20NVNM-Cite/wiki/Document%20Hash.md): why the file is hashed (receipt / provenance), not for citation lookup.
- 2026-09-01 — [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md): first paragraph is the two lawyer jobs (Check vs Record) and the common misreads.
- 2026-09-01 — [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md): Check-then-Record sequence and what “lock” does and does not mean.
- 2026-09-01 — [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md): rephrased the lock section so it stands alone (dropped the chat-reply opener).
- 2026-09-01 — Removed Cursor/Obsidian qmd reindex hooks. [CLAUDE](INV-42043%20-%20NVNM-Cite/CLAUDE.md) now requires the agent to search and reindex with qmd. [AGENTS](INV-42043%20-%20NVNM-Cite/AGENTS.md) defers to CLAUDE.md.
- 2026-09-01 — [CLAUDE](INV-42043%20-%20NVNM-Cite/CLAUDE.md) points at vault-wide [Qmd Code Search](_resources/Qmd%20Code%20Search.md) for `nvnm-cite` source: qmd `--files` → grep those paths → read 1–2 files. This collection stays markdown-only.
- 2026-09-11 — [GA Events](INV-42554%20-%20NVNM-Cite/GA%20Events.md) (INV-42554, branch `INV-42554-ga`): required + extra Analytics events for the web page. Linked from [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md) and this index.
