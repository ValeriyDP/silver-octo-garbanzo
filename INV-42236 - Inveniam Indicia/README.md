---
name: Inveniam Indicia (INV-42236)
date: 2026-09-01T11:54:04.478Z
tags:
  - inveniam-indicia
  - inv-42236
  - index
---

# Inveniam Indicia (INV-42236)

Blank investigation workspace. Two folders, two jobs:

| Folder | Job | Modelled on |
| ------ | --- | ----------- |
| [wiki/](_resources/templates/investigation-project/wiki/index.md) | **Knowledge base** — what we know, how things work, how-tos, diagrams, open questions | Smart Accounts |
| [decisions/](_resources/templates/investigation-project/decisions/INDEX.md) | **ADR investigation** — what we chose and why | Hub Keys Everywhere |

They stay separate so a how-to does not become a decision record, and an ADR does not become a dump of source notes. **Cross-link** when a wiki page forces a choice, or when an accepted ADR changes what the wiki says.

Agent instructions: [AGENTS](_resources/templates/investigation-project/AGENTS.md) → [CLAUDE](_resources/templates/investigation-project/CLAUDE.md).

## Application

- Repo: `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia`
- Docs: `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia/docs`

If this is unset, the agent must ask for the repo path(s) before investigating. Repo docs stay in the repo; they are indexed as `inveniam-indicia-docs`, not copied into this folder.

## Start here

1. Drop sources into `raw/` (never edit them after).
2. Ingest into `wiki/` (summaries, concept pages, how-tos).
3. When you hit a fork (two ways to build it), open an ADR in `decisions/`.
4. Link both ways. Update [_resources/templates/investigation-project/wiki/index](_resources/templates/investigation-project/wiki/index.md) and [_resources/templates/investigation-project/decisions/INDEX](_resources/templates/investigation-project/decisions/INDEX.md). Append both logs.
5. When ADR(s) are ready to implement, write `wiki/Write the <Feature>.md` first (human writes the Go). Contract: [CLAUDE — Implementation how-to](CLAUDE.md#implementation-how-to--after-adrs-are-ready). Canon: [Write the Person Graveyard](wiki/Write%20the%20Person%20Graveyard.md), [Write the Un-forget](wiki/Write%20the%20Un-forget.md).

## qmd (search)

Three collections. Wiki and repo docs stay separate. First-time setup:

```bash
# This investigation (wiki / ADRs)
qmd collection add "$(pwd)" --name inveniam-indicia --mask "**/*.md"
qmd context add qmd://inveniam-indicia "Inveniam Indicia investigation wiki and ADRs"

# Repo docs (live tree)
qmd collection add /Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia/docs \
  --name inveniam-indicia-docs --mask "**/*.md"
qmd context add qmd://inveniam-indicia-docs "Inveniam Indicia upstream repository docs (API, guides, plans, devops)"

# Go source (path finder — do not mix with markdown collections)
qmd collection add /Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia \
  --name inveniam-indicia-code --mask "**/*.go"
qmd context add qmd://inveniam-indicia-code "Inveniam Indicia Go application source"

qmd embed
qmd update
```

Or run `_resources/scripts/qmd-sync.sh "$(pwd)"` for the wiki collection only (reads `qmd-collection`). Config for the others: `qmd-collection-docs`, `qmd-collection-code`. There are no hooks — after each page add or edit **here**, the agent must `qmd update` and `qmd embed -c inveniam-indicia` (or that script). Exclude `raw/` from the wiki collection if you add it later (sources stay immutable and unindexed).

For application source, do not expand the wiki or docs mask. Use [Qmd Code Search](_resources/Qmd%20Code%20Search.md) against `inveniam-indicia-code`.
