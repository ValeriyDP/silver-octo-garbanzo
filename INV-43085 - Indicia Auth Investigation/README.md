---
name: Indicia (INV-43085)
date: 2026-10-07T15:26:28.055Z
tags:
  - indicia
  - inv-43085
  - index
---

# Indicia (INV-43085)

Blank investigation workspace. Two folders, two jobs:

| Folder | Job | Modelled on |
| ------ | --- | ----------- |
| [wiki/](INV-43085%20-%20Indicia%20Auth%20Investigation/wiki/index.md) | **Knowledge base** — what we know, how things work, how-tos, diagrams, open questions | Smart Accounts |
| [decisions/](INV-43085%20-%20Indicia%20Auth%20Investigation/decisions/INDEX.md) | **ADR investigation** — what we chose and why | Hub Keys Everywhere |

They stay separate so a how-to does not become a decision record, and an ADR does not become a dump of source notes. **Cross-link** when a wiki page forces a choice, or when an accepted ADR changes what the wiki says.

Agent instructions: [AGENTS](AGENTS.md) → [CLAUDE](CLAUDE.md).

## Application

- `~/work/inveniam/trace-chain/InveniamIndicia`

If this is unset, the agent must ask for the repo path(s) before investigating.

## Start here

1. Drop sources into `raw/` (never edit them after).
2. Ingest into `wiki/` (summaries, concept pages, how-tos).
3. When you hit a fork (two ways to build it), open an ADR in `decisions/`.
4. Link both ways. Update [Indicia Auth Investigation (INV-43085)/wiki/index](INV-43085%20-%20Indicia%20Auth%20Investigation/wiki/index.md) and [Indicia Auth Investigation (INV-43085)/decisions/INDEX](INV-43085%20-%20Indicia%20Auth%20Investigation/decisions/INDEX.md). Append both logs.

## qmd (search)

From this folder:

```bash
qmd collection add "$(pwd)" --name indicia --mask "**/*.md"
qmd context add qmd://indicia "Indicia investigation"
qmd embed
qmd update
```

Or run `_resources/scripts/qmd-sync.sh "$(pwd)"` (reads `qmd-collection` in this folder). There are no hooks — after each page add or edit, the agent must `qmd update` and `qmd embed -c indicia` (or that script). Exclude `raw/` from the collection if you add it later (sources stay immutable and unindexed).

For application source (TS/JS/Python/Go), do not expand this mask. Use [Qmd Code Search](_resources/Qmd%20Code%20Search.md).
