# CLAUDE.md — Hub Keys Everywhere (INV-42086) (isolated LLM wiki)

Agent guidance for maintaining this folder. This is a **self-contained LLM wiki** of **Architecture Decision Records (ADRs)** for the **scoped Hub integration keys** feature (org → portfolio → deal → data room) across `inveniam.io` (`hub-service`) and `inveniam-v2` (Angular UI), searchable with `qmd`. It is scoped to this feature, not the whole project.

> **Scope**: everything here is isolated to this folder. Do not index, read, or write other parts of the vault from this wiki.

## Purpose

Capture **why** the code is the way it is — context, decision, trade-offs — so a future engineer (or agent) understands the reasoning without code archaeology. Good answers are filed back as ADRs so knowledge compounds over time.

## Folder layout

```
AGENTS.md          -- follow CLAUDE.md
CLAUDE.md          -- this guide
.mcp.json          -- qmd MCP server (scoped to this folder)
INDEX.md           -- decision register (table of contents) + conventions
log.md             -- append-only record of every change
ADR Template.md    -- copy this to start a new record
ADR-<n> <Title>.md -- one record per decision (ADR-0001, ADR-0002, …); these are the wiki pages
```

## Writing a new ADR

1. Copy [ADR Template](INV-42086%20-%20Hub%20Keys%20Everywhere/ADR%20Template.md) to `ADR-<next number> <Short Title>.md` (Title Case).
2. Fill in the **frontmatter** (`name`, `date`, `tags` — see below) and the body: **Context → Decision → Alternatives considered → Consequences → Affected code → Related**.
3. Ground it in real code: name the actual types, endpoints, components, and file paths. Verify against the repo (`inveniam.io`, `inveniam-v2`) before writing — do not rely on memory.
4. Add a row to the register table in [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md).
5. Cross-link related ADRs at the bottom with Markdown links (`[Title](Title.md)`, spaces URL-encoded as `%20`).
6. Append an entry to [log](INV-42086%20-%20Hub%20Keys%20Everywhere/log.md) (date + what changed).
7. Reindex qmd in the same turn (`qmd update` and `qmd embed -c hub-keys-everywhere`, or `_resources/scripts/qmd-sync.sh "$(pwd)"`). There are no hooks.

## Frontmatter & tags (required)

Every note (ADRs, `INDEX`, `log`) starts with a YAML frontmatter block so Obsidian can organize and filter by tag, and so search can be scoped by topic:

```yaml
---
name: ADR-0002 Per-Level Hub Key Endpoints
date: 2026-08-21T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - hub-service
  - inveniam-v2
  - architecture
  - adr
---
```

Rules:

- `name` — the human title (usually matches the H1 / filename).
- `date` — ISO 8601 (`YYYY-MM-DDTHH:mm:ss.SSSZ`); use the decision/authoring date.
- `tags` — a YAML list, lowercase, hyphenated, **no `#` prefix** (Obsidian adds it in the tag pane). Reuse existing tags before inventing new ones so the tag graph stays connected.
- Keep the in-body `- **Status/Area/Ticket**` metadata line too — it's for humans reading the rendered note; frontmatter is for Obsidian's tag/search machinery.

**Tag vocabulary** for this wiki (extend deliberately):

- Feature/ticket: `hub-keys`, `inv-42086`
- Area: `hub-service`, `inveniam-v2`, `deals-service`, `iam-service`, `platform`
- Domain: `scoped-keys`, `vault`, `ledger`, `erc-4337`
- Doc type: `adr`, `architecture`, `diagram`, `index`, `log`
- Lifecycle: `not-addressed` (ADR is `Proposed` but not yet implemented), `rejected` (decided against; kept for the record)

Add `date` to frontmatter before editing existing files if it's missing, then re-run `qmd update`.

## Conventions

- **Status**: `Proposed` · `Accepted` · `Superseded by [ADR-XXXX …](ADR-XXXX%20….md)` · `Deprecated`.
- **Never delete an ADR.** If a decision is reversed, mark the old one `Superseded` and link the replacement.
- **Filenames**: Obsidian-style Title Case with spaces. Do **not** add a second `.md` extension (Obsidian appends one — type the name without `.md`).
- **Durable, not a diary**: record reasoning and trade-offs, not a play-by-play.
- Keep secrets out (tokens, keys, credentials).

## Search tool (qmd)

Use `qmd` to search this wiki instead of reading `INDEX.md` by hand. It is a local hybrid BM25/vector search engine over markdown, with an optional LLM reranker, on-device. Prefer the MCP tools (`mcp__qmd__query` / `mcp__qmd__get` / `mcp__qmd__status`) when connected; CLI equivalents below.

Installed globally: `qmd <command>`. MCP server is configured in `.mcp.json` in this folder (`qmd mcp`).

**One-time setup** (run from inside this folder):
```bash
qmd collection add "$(pwd)" --name hub-keys-everywhere --mask "**/*.md"
qmd context add qmd://hub-keys-everywhere "Inveniam - Hub Keys Everywhere (INV-42086) design decisions"
qmd embed
qmd update
```

Or `_resources/scripts/qmd-sync.sh "$(pwd)"`. There are no hooks — reindex after every page add or edit.

**Searching:**
```bash
qmd query  "<question>" -c hub-keys-everywhere   # best quality: hybrid + rerank
qmd search "<keywords>" -c hub-keys-everywhere   # fast BM25-only lookup
qmd vsearch "<question>" -c hub-keys-everywhere   # semantic-only lookup
qmd get    "ADR-0001 Scoped Add HUB Key.md"   # fetch a page by path
```

This collection is the ADR wiki (`**/*.md`). For application source (`inveniam-v2`, `hub-service`), follow [Qmd Code Search](_resources/Qmd%20Code%20Search.md): qmd `--files` → grep those paths → read 1–2 files. Do not add source trees to this collection.

## Question answering

1. Use `mcp__qmd__query` (or `qmd query "<question>" -c hub-keys-everywhere`) to find relevant ADRs.
2. Read those pages and synthesize an answer.
3. Cite the specific ADR(s) in your response.
4. If the answer isn't in the wiki, say so — then offer to capture it as a new ADR.

## When asked to "audit" this wiki

- Numbering gaps or duplicates.
- ADRs missing from the [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md) register (or register rows with no file).
- Broken Markdown links and orphan pages (no inbound links).
- Records not following the [ADR Template](INV-42086%20-%20Hub%20Keys%20Everywhere/ADR%20Template.md) structure.
- `Superseded`/`Deprecated` records that don't link their replacement.
- Stale qmd index (run `qmd update` and `qmd embed` yourself).
