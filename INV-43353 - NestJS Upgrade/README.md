---
name: NestJS Upgrade (INV-43353)
date: 2026-11-18T08:06:44.542Z
tags:
  - nestjs-upgrade
  - inv-43353
  - index
---
# NestJS Upgrade (INV-43353)

Blank investigation workspace. Two folders, two jobs:

| Folder | Job | Modelled on |
| ------ | --- | ----------- |
| [wiki/](_resources/templates/investigation-project/wiki/index.md) | **Knowledge base** — what we know, how things work, how-tos, diagrams, open questions | Smart Accounts |
| [decisions/](_resources/templates/investigation-project/decisions/INDEX.md) | **ADR investigation** — what we chose and why | Hub Keys Everywhere |

They stay separate so a how-to does not become a decision record, and an ADR does not become a dump of source notes. **Cross-link** when a wiki page forces a choice, or when an accepted ADR changes what the wiki says.

Agent instructions: [AGENTS](_resources/templates/investigation-project/AGENTS.md) → [CLAUDE](_resources/templates/investigation-project/CLAUDE.md).

## Application

- `/Users/valeriyilihmetov/work/inveniam/inveniam.io`

If this is unset, the agent must ask for the repo path(s) before investigating.

## Start here

1. Drop sources into `raw/` (never edit them after).
2. Ingest into `wiki/` (summaries, concept pages, how-tos).
3. When you hit a fork (two ways to build it), open an ADR in `decisions/`.
4. Link both ways. Update [_resources/templates/investigation-project/wiki/index](_resources/templates/investigation-project/wiki/index.md) and [_resources/templates/investigation-project/decisions/INDEX](_resources/templates/investigation-project/decisions/INDEX.md). Append both logs.

## qmd (search)

From this folder:

```bash
qmd collection add "$(pwd)" --name nestjs-upgrade --mask "**/*.md"
qmd context add qmd://nestjs-upgrade "NestJS Upgrade investigation"
qmd embed
qmd update
```

Or run `_resources/scripts/qmd-sync.sh "$(pwd)"` (reads `qmd-collection` in this folder). There are no hooks — after each page add or edit, the agent must `qmd update` and `qmd embed -c nestjs-upgrade` (or that script). Exclude `raw/` from the collection if you add it later (sources stay immutable and unindexed).

For application source (TS/JS/Python/Go), do not expand this mask. Use [Qmd Code Search](_resources/Qmd%20Code%20Search.md).
