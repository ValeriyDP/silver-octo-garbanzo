---
name: CLAUDE.md
date: 2026-09-01T07:07:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - guide
---

# CLAUDE.md — NVNM-Cite (INV-42043)

Agent guide for this investigation folder. Isolated to this project. Do not index or rewrite other vault projects from here.

**Application path:** `/Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite`

## Two modes

This project is **two linked wikis**, not one pile of notes.

### 1. Knowledge base — `wiki/`

Use when the work is: understand a system, ingest a spec, write a how-to, draw a flow, capture current state, list open questions.

- Immutable sources live in `raw/`. Never modify `raw/`.
- Pages live in `wiki/`. Table of contents: [NVNM-Cite (INV-42043)/wiki/index](NVNM-Cite%20(INV-42043)/wiki/index.md). Change log: [NVNM-Cite (INV-42043)/wiki/log](NVNM-Cite%20(INV-42043)/wiki/log.md).
- One idea per page. Title Case filenames with spaces. YAML frontmatter (`name`, `date`, `tags`).
- Every page: **Summary**, **Sources**, **Last updated**, then body, then **Related pages**.
- Cite sources as `(source: filename)` after factual claims. Mark unverified claims.
- Ingest workflow: read `raw/` → discuss takeaways with the human → write/update wiki pages → update index + log → reindex qmd (required; no hooks).

### 2. ADR investigation — `decisions/`

Use when the work is: choose among options, lock a design, record why the code looks this way.

- One decision per file: `ADR-0001 Short Title.md` (zero-padded). Never delete; supersede instead.
- Copy [NVNM-Cite (INV-42043)/decisions/ADR Template](NVNM-Cite%20(INV-42043)/decisions/ADR%20Template.md). Fill Context → Decision → Alternatives → Consequences → Affected code → Related.
- Ground ADRs in real paths and types. Do not invent APIs from memory.
- Register every ADR in [NVNM-Cite (INV-42043)/decisions/INDEX](NVNM-Cite%20(INV-42043)/decisions/INDEX.md). Append [NVNM-Cite (INV-42043)/decisions/log](NVNM-Cite%20(INV-42043)/decisions/log.md).
- Status: `Proposed` · `Accepted` · `Superseded by [ADR-…](…)` · `Deprecated` · `Rejected` (kept for the record).

## When to use which

| Situation | Put it in |
| --------- | --------- |
| Spec, diagram, how-to, “how it works today” | `wiki/` |
| Two valid designs, we pick one | `decisions/` |
| Open question with no choice yet | `wiki/Open Questions.md` (or a wiki page). Promote to an ADR when a decision is needed. |
| Accepted decision changes the system story | Update the wiki page **and** leave the ADR as the why. |

If unsure, ask the human. Do not dump an ADR into the wiki or a how-to into the register.

## Cross-linking (required)

Folders stay separate; links connect them.

- From a wiki page that forced a decision: `[ADR-0001 Title](../decisions/ADR-0001%20Title.md)`.
- From an ADR that rests on known facts: `[Happy Flow](../wiki/Happy%20Flow.md)`.
- Spaces in filenames → `%20` in Markdown links (this vault uses Markdown links).
- After linking, mention the pair in both **Related** sections.
- Do not duplicate the full argument on both sides. Wiki = picture. ADR = choice.

## Frontmatter & tags

```yaml
---
name: Page Title
date: YYYY-MM-DDTHH:mm:ss.SSSZ
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - <topic>
  - wiki   # or: adr
---
```

- `tags`: lowercase, hyphenated, no `#`. Reuse before inventing.
- Feature tag: `nvnm-cite-inv-42043`. Ticket tag if any: listed in frontmatter.
- Doc type tags: `wiki`, `adr`, `architecture`, `diagram`, `guide`, `index`, `log`, `how-to`.

## qmd

There are no reindex hooks. The agent keeps this collection current.

Collection name: `nvnm-cite-inv-42043`. Prefer MCP `mcp__qmd__query` / `get` / `status` when connected; otherwise the CLI.

Search this folder with qmd (not vault-wide grep):

```bash
qmd query  "<question>" -c nvnm-cite-inv-42043
qmd search "<keywords>" -c nvnm-cite-inv-42043
qmd get    "wiki/Open Questions.md"
```

This collection is markdown only. For application source under `/Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite`, follow [Qmd Code Search](_resources/Qmd%20Code%20Search.md): qmd `--files` → grep those paths → read 1–2 files. Do not add source trees to this collection.

After you add or edit any page here, reindex in the same turn:

```bash
qmd update
qmd embed -c nvnm-cite-inv-42043
```

Or from this folder: `../_resources/scripts/qmd-sync.sh "$(pwd)"` (reads `qmd-collection`). First-time collection setup is in [README](NVNM-Cite%20(INV-42043)/README.md).

## Question answering

1. Search with qmd (`query` / `get`). If you just wrote pages, reindex first.
2. Read the hits. Cite wiki pages and/or ADRs.
3. If it is not in this folder, say so. Offer to capture it (wiki page vs ADR — see table above).

## Audit

- Numbering gaps / ADRs missing from the register.
- Wiki pages missing from `wiki/index.md`.
- Orphans (no inbound links).
- Wiki ↔ decisions links that should exist but do not.
- Broken Markdown links.
- Stale qmd index.
- Claims in wiki that contradict an Accepted ADR.

## Rules

- Never modify `raw/`.
- Always update the matching index + log after a change, then reindex qmd.
- Keep secrets out.
- Durable notes, not a session diary.
