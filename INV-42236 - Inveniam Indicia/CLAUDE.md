---
name: CLAUDE.md
date: 2026-09-09T06:54:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - guide
---

# CLAUDE.md — Inveniam Indicia (INV-42236)

Agent guide for this investigation folder. Isolated to this project. Do not index or rewrite other vault projects from here.

**Application path(s):** `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia`

**Application docs:** `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia/docs`

If that line is empty, looks like an unfilled template placeholder, or says it is not set: **stop and ask**. One wiki can cover several repos. Record every absolute path the human names. Do not invent a path from the project title. After they answer, write the paths here and in README, then continue. Code search uses those paths and a **separate** qmd code collection — see [Qmd Code Search](_resources/Qmd%20Code%20Search.md). Do not add source trees to this wiki collection. Do not copy repo `docs/` into this folder; query them via `inveniam-indicia-docs`.

## Two modes

This project is **two linked wikis**, not one pile of notes.

### 1. Knowledge base — `wiki/`

Use when the work is: understand a system, ingest a spec, write a how-to, draw a flow, capture current state, list open questions. Implementation how-tos (`Write the …`) wait until ADR(s) are ready — see [Implementation how-to](#implementation-how-to--after-adrs-are-ready).

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
| Spec, diagram, “how it works today” | `wiki/` |
| Two valid designs, we pick one | `decisions/` |
| Open question with no choice yet | `wiki/Open Questions.md` (or a wiki page). Promote to an ADR when a decision is needed. |
| ADR(s) locked enough to type | `wiki/Write the <Feature>.md` — see [Implementation how-to](#implementation-how-to--after-adrs-are-ready). Do **not** start the app-repo Go unless asked. |
| Ticket a stranger can file | `wiki/JIRA Tasks.md` — copy-paste block only; no vault ADR ids, no “graveyard”. |
| Accepted decision changes the system story | Update the wiki page **and** leave the ADR as the why. |

If unsure, ask the human. Do not dump an ADR into the wiki or a how-to into the register.

## Implementation how-to — after ADR(s) are ready

The human writes the code to learn the stack. The agent writes the how-to, teaches, and reviews. **Do not implement the sidecar (or paste the finished feature) unless explicitly asked.**

Canon — copy the skeleton, not the content:

- [Write the Person Graveyard](wiki/Write%20the%20Person%20Graveyard.md) — first landing (ADR-0003). Language habits live here.
- [Write the Un-forget](wiki/Write%20the%20Un-forget.md) — follow-on change (ADR-0004). Primer is *only* what is new on top of the previous how-to; model questions sit before Step 0.

Optional companion (curl, not Go): [QA Person Graveyard](wiki/QA%20Person%20Graveyard.md). Filename `QA <Feature>.md`.

### Ready gate — do not open the how-to yet

All of these, or stop and finish the ADR / Open Question first:

1. The design is one change. If two ADRs must ship as one PR, **one** how-to. If they must be separate PRs, two how-tos. Do not write a how-to for an interim shape the next ADR will delete (the `unforgotten_at` dead end).
2. Open questions that would change the file map, iron rules, kinds, door verbs, or HTTP codes are **decided**.
3. Names are locked (package, types, event kinds, routes). Door word and ledger kind may differ — pin both and say why.
4. File map is **grep-verified** against the live app repo (every `Deps` constructor, every reader of the table you will replace). Do not invent paths.
5. ADR status may still be `Proposed` if the leftover “confirm” items do not change the file map. List those leftovers in the ADR, not as live forks in the how-to.

### Split of labor (do not mix)

| Artifact | Job | May cite ADRs? |
| -------- | --- | -------------- |
| ADR | Why this design, alternatives, schema/HTTP pins | it *is* the ADR |
| How-to | Order of work, teach at point of use, cognitive-debt questions | yes |
| [JIRA Tasks](wiki/JIRA%20Tasks.md) copy-into-JIRA block | Ticket a stranger files | **no** — no ADR ids, no decision links, no vault metaphor |
| App-repo `docs/` (last how-to step) | Spec / playbook / finding closure the code ships with | **no** vault ADR ids |
| QA page | curl / Taskfile script for a tester | no |

The how-to **links** the ADR and the JIRA task. It does not re-argue the ADR. A reviewer who wants “why not UPDATE” goes to the ADR; a reviewer who wants “which file this week” stays on the how-to.

### Page contract

Filename `Write the <Feature>.md`. Title Case, spaces. Tags: `inveniam-indicia`, `inv-42236`, `wiki`, `how-to`, plus language (`go`). Standard wiki header: **Summary**, **Sources**, **Last updated**.

Required sections, in this order:

1. **How to read this page.** Read once without typing. Prerequisite: any earlier how-to’s Check yourself, if this change sits on that code. `FILE:` snippets name the destination; *pattern only* is a shape, not paste-and-ship. “When stuck, ask — teach, do not paste the finished sidecar.”
2. **What you are building and why.** The hole, in product language. Diagram immediately after (PlantUML or mermaid) — the happy path the steps will type. If the model is new (a `cycle`, a new kind pair), a walkthrough with a growing table *before* any step: one subject, two acts, what `Latest` / forgotten-set / “destroyed since” each say.
3. **Iron rules.** Five or fewer. A reviewer will check every one. Every later step serves at least one.
4. **Check yourself before Step 0** — required when the model is new; skip only if the previous how-to already owns the model (graveyard skipped this). See [Cognitive-debt questions](#cognitive-debt-questions).
5. **Already decided — do not re-litigate while coding.** Table: Question / Answer / Details (step or ADR). Includes naming, codes, out-of-scope. No open forks.
6. **Primer.** First how-to in a thread: the language habits every step uses. Later how-to: **only** the new idioms (`INSERT … SELECT … ON CONFLICT`, `DISTINCT ON`, `*time.Time` for SQL NULL, the one allowed `DEL`). Do not repeat the first primer.
7. **The change at a glance.** Absolute app path. `NEW` / `MOD` / `DEL` file map with step numbers. “If you edit outside this list, stop.” Name what you are **not** touching (Vault, core API, a table you must not `UPDATE`).
8. **Steps 0–N** in compile order: schema/store → package → unit tests → doors / interfaces / stubs → wiring → integration → lint + app-repo docs. Each step:
   - **Files** / **What**
   - **The Go (or SQL) here** — teach the idiom at the point of use, with the gotcha that shapes the design
   - A `FILE:` snippet (imports shown; existing files list what is already imported) **or** a *pattern only* block
   - **Done when** — a real command (`go test -run …`, `go build ./…`, `make lint`). Last step’s Done when also requires the PR Check yourself from memory.
9. **Blast radius** — who reads the old surface today, what is additive vs what fail-closes for the first time, what a wrong feed would corrupt.
10. **Out of this work** — parked Open Questions and forbidden shapes (`UPDATE` the log, `SREM` one member, vault-ADR text in repo docs).
11. **Check yourself before the PR** — always. See below.
12. **Toolbox** — one line of iterate commands.
13. **Related pages** — ADR(s), JIRA task, previous how-to, Open Questions, findings.

Do not invent a second parallel structure (idioms §A–F *and* steps 0–N). One walk.

### Cognitive-debt questions

Purpose: the reader proves they have the model **before** they type, and the code **before** they open a PR. If they can answer from memory, they understood the design. **Questions only — every answer is already on the page.** Same voice as the graveyard how-to: walk a race, name the one wrong answer, say what breaks.

**Before Step 0** (the model). Typical prompts: name kinds vs door verbs and why they are not the same words; why a status is not a kind; walk one subject through latest / forgotten-set / “since this record”; why the next act is a new row, not an `UPDATE`; which `MAX`/`WHERE` the insert uses. If you cannot write five of these, the “what you are building” section is still an ADR dump — tighten it, then write the questions.

**Before the PR** (the code). Typical prompts: two racing statements, why one row and the same dates; heal/recalculate feed vs “any row exists”; remint + unwrap-fail = which status, which argument; fail-closed `(bool, error)` or 503-after-commit; clocks vs `(cycle, kind)`; what a forbidden field/claim would lie about.

Do not answer the questions under the heading. Do not turn them into a quiz key in another file.

### After the how-to exists

Same turn, always:

- Link from the ADR **Related** and from the JIRA task’s vault (not copy-into-JIRA) section.
- Mark decided Open Questions; do not leave a live fork that the how-to already pinned.
- [wiki/index.md](INV-42236%20-%20Inveniam%20Indicia/wiki/index.md) + [wiki/log.md](INV-42236%20-%20Inveniam%20Indicia/wiki/log.md), then `qmd update && qmd embed -c inveniam-indicia`.
- If a QA companion is needed, it is a **new** page, not a section stuffed into the how-to.

When the human is implementing: review against the file map and the iron rules; teach; do not apply the fix unless asked.

## Cross-linking (required)

Folders stay separate; links connect them.

- From a wiki page that forced a decision: `[ADR-0001 Title](../decisions/ADR-0001%20Title.md)`.
- From an ADR that rests on known facts: `[Happy Flow](../wiki/Happy%20Flow.md)`.
- From a how-to that implements a decision: ADR in **Related** and in Sources; JIRA task in Related only (never in copy-into-JIRA text).
- Spaces in filenames → `%20` in Markdown links (this vault uses Markdown links).
- After linking, mention the pair in both **Related** sections.
- Do not duplicate the full argument on both sides. Wiki = picture. ADR = choice. How-to = order of work.

## Frontmatter & tags

```yaml
---
name: Page Title
date: YYYY-MM-DDTHH:mm:ss.SSSZ
tags:
  - inveniam-indicia
  - inv-42236
  - <topic>
  - wiki   # or: adr
---
```

- `tags`: lowercase, hyphenated, no `#`. Reuse before inventing.
- Feature tag: `inveniam-indicia`. Ticket tag if any: listed in frontmatter.
- Doc type tags: `wiki`, `adr`, `architecture`, `diagram`, `guide`, `index`, `log`, `how-to`.

## qmd

There are no reindex hooks. The agent keeps these collections current. Three collections, three jobs — do not merge them.

| Collection | What | On-disk root | Config |
| ---------- | ---- | ------------ | ------ |
| `inveniam-indicia` | This investigation: `wiki/`, `decisions/`, README | this folder | `qmd-collection` |
| `inveniam-indicia-docs` | Upstream repo docs (API, guides, plans, devops) | `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia/docs` | `qmd-collection-docs` |
| `inveniam-indicia-code` | Application Go source | `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia` | `qmd-collection-code` |

Prefer MCP `mcp__qmd__query` / `get` / `status` when connected; otherwise the CLI. Scope every query with `-c`.

```bash
# Investigation wiki / ADRs
qmd query  "<question>" -c inveniam-indicia
qmd search "<keywords>" -c inveniam-indicia
qmd get    "wiki/Open Questions.md"

# Repository docs (live tree — not copied here)
qmd query  "<question>" -c inveniam-indicia-docs
qmd search "<keywords>" -c inveniam-indicia-docs

# Go source — path finder only (see Qmd Code Search)
qmd vsearch "<question>" --files -n 8 -c inveniam-indicia-code
qmd search  "<symbol>"  --files -n 8 -c inveniam-indicia-code
```

`inveniam-indicia` and `inveniam-indicia-docs` are markdown only. For Go, follow [Qmd Code Search](_resources/Qmd%20Code%20Search.md): qmd `--files` to get paths, grep those paths, then read 1–2 files. Do not add source trees to the wiki or docs collections.

Repo `docs/` map (from `docs/README.md`): `api/` (spec + architecture), `guides/`, `standards/`, `devops/`, `feature_summaries/`, `plans/`, `handoffs/`, `new ideas/`. Index in place; do not copy into `wiki/` or `raw/`.

After you add or edit any page **here**, reindex the wiki collection in the same turn:

```bash
qmd update
qmd embed -c inveniam-indicia
```

Or from this folder: `../_resources/scripts/qmd-sync.sh "$(pwd)"` (reads `qmd-collection` only). First-time collection setup is in the project README.

Reindex `inveniam-indicia-docs` and `inveniam-indicia-code` after large pulls or when hits look stale — not after every wiki edit:

```bash
qmd update
qmd embed -c inveniam-indicia-docs
qmd embed --chunk-strategy auto -c inveniam-indicia-code
```

## Question answering

1. Search with qmd (`query` / `get`), scoped: wiki first (`inveniam-indicia`), then repo docs (`inveniam-indicia-docs`). If you just wrote pages, reindex first.
2. Read the hits. Cite wiki pages, ADRs, and/or repo docs (`docs/…`).
3. If it is not in this folder and not in the repo docs collection, say so. Offer to capture it (wiki page vs ADR — see table above).

## Audit

- Numbering gaps / ADRs missing from the register.
- Wiki pages missing from `wiki/index.md`.
- Orphans (no inbound links).
- Wiki ↔ decisions links that should exist but do not.
- Broken Markdown links.
- Stale qmd index.
- Claims in wiki that contradict an Accepted ADR.
- Implementation-ready ADR with no `Write the …` how-to, or a how-to that re-argues the ADR / has no Check yourself / has an unverified file map.
- JIRA copy-into-JIRA or app-repo docs that name a vault ADR id or “graveyard”.

## Rules

- Never modify `raw/`.
- Always update the matching index + log after a change, then reindex qmd.
- Keep secrets out.
- Durable notes, not a session diary.
- After ADR(s) are ready to implement: write the how-to first. Do not implement app-repo Go unless asked.
- Never put vault ADR ids or the vault metaphor “graveyard” in JIRA copy-paste text or in app-repo `docs/`.
- **Logs vs public response.** `Msg(…)` and wrap prefixes that surface via `.Err(err)` keep operator vocabulary (Redis commands, store names). HTTP `message` / `reason` must not leak infrastructure — no `SADD`, Redis, Postgres, Vault, FusionAuth, or key names. Two crash windows that share an error code share one HTTP body. How-to `FILE:` snippets follow the same split.
