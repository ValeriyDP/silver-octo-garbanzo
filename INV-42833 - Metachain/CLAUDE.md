---
name: CLAUDE.md
date: 2026-10-02T13:41:00.000Z
tags:
  - metachain
  - inv-42833
  - guide
---

# CLAUDE.md — Metachain (INV-42833)

Agent guide for this investigation folder. Isolated to this project. Do not index or rewrite other vault projects from here.

**Application path(s):** - `~/work/inveniam/inveniam.io`

If that line is empty, looks like an unfilled template placeholder, or says it is not set: **stop and ask**. One wiki can cover several repos. Record every absolute path the human names. Do not invent a path from the project title. After they answer, write the paths here and in README, then continue. Code search uses those paths and a **separate** qmd code collection — see [Qmd Code Search](_resources/Qmd%20Code%20Search.md). Do not add source trees to this wiki collection.

## Two modes

This project is **two linked wikis**, not one pile of notes.

### 1. Knowledge base — `wiki/`

Use when the work is: understand a system, ingest a spec, write a how-to, draw a flow, capture current state, list open questions.

- Immutable sources live in `raw/`. Never modify `raw/`.
- Pages live in `wiki/`. Table of contents: [_resources/templates/investigation-project/wiki/index](_resources/templates/investigation-project/wiki/index.md). Change log: [_resources/templates/investigation-project/wiki/log](_resources/templates/investigation-project/wiki/log.md).
- One idea per page. Title Case filenames with spaces. YAML frontmatter (`name`, `date`, `tags`).
- Every page: **Summary**, **Sources**, **Last updated**, then body, then **Related pages**.
- Cite sources as `(source: filename)` after factual claims. Mark unverified claims.
- Ingest workflow: read `raw/` → discuss takeaways with the human → write/update wiki pages → update index + log → reindex qmd (required; no hooks).

### 2. ADR investigation — `decisions/`

Use when the work is: choose among options, lock a design, record why the code looks this way.

- One decision per file: `ADR-0001 Short Title.md` (zero-padded). Never delete; supersede instead.
- Copy [_resources/templates/investigation-project/decisions/ADR Template](_resources/templates/investigation-project/decisions/ADR%20Template.md). Fill Context → Decision → Alternatives → Consequences → Affected code → Related.
- Ground ADRs in real paths and types. Do not invent APIs from memory.
- Register every ADR in [_resources/templates/investigation-project/decisions/INDEX](_resources/templates/investigation-project/decisions/INDEX.md). Append [_resources/templates/investigation-project/decisions/log](_resources/templates/investigation-project/decisions/log.md).
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
  - metachain
  - inv-42833
  - <topic>
  - wiki   # or: adr
---
```

- `tags`: lowercase, hyphenated, no `#`. Reuse before inventing.
- Feature tag: `metachain`. Ticket tag if any: listed in frontmatter.
- Doc type tags: `wiki`, `adr`, `architecture`, `diagram`, `guide`, `index`, `log`, `how-to`.

## qmd

There are no reindex hooks. The agent keeps this collection current.

Collection name: `metachain`. Prefer MCP `mcp__qmd__query` / `get` / `status` when connected; otherwise the CLI.

Search this folder with qmd (not vault-wide grep):

```bash
qmd query  "<question>" -c metachain
qmd search "<keywords>" -c metachain
qmd get    "wiki/Open Questions.md"
```

This collection is markdown only. For TS/JS/Python/Go in the application repos, follow [Qmd Code Search](_resources/Qmd%20Code%20Search.md): qmd `--files` to get paths, grep those paths, then read 1–2 files. Do not add source trees to this collection.

After you add or edit any page here, reindex in the same turn:

```bash
qmd update
qmd embed -c metachain
```

Or from this folder: `../_resources/scripts/qmd-sync.sh "$(pwd)"` (reads `qmd-collection`). First-time collection setup is in the project README.

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
- You may edit `wiki/Metachain And NVNM Flow.excalidraw` when facts change. Follow the **current scene structure** — do not regenerate from scratch or revert to an older agent layout. Current structure (human, 2026-10-02): title + `metachain-service` header; **two side-by-side columns** (Action 1 event hash | Action 2 file taxonomy); **each column top → bottom**. Preserve ids, colors, and grouping. Do not embed a replacement scene into `Metachain And NVNM Flow.excalidraw.md` unless you also update the sibling `.excalidraw` the same way.
