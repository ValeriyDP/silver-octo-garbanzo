---
name: NVNM-Cite (INV-42043) (INV-42043)
date: 2026-08-31T13:15:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - index
---

# NVNM-Cite (INV-42043) (INV-42043)

Investigation workspace. Two folders, two jobs:

| Folder | Job | Modelled on |
| ------ | --- | ----------- |
| [wiki/](INV-42043%20-%20NVNM-Cite/wiki/index.md) | **Knowledge base** — what we know, how things work, how-tos, diagrams, open questions | Smart Accounts |
| [decisions/](INV-42043%20-%20NVNM-Cite/decisions/INDEX.md) | **ADR investigation** — what we chose and why | Hub Keys Everywhere |

They stay separate so a how-to does not become a decision record, and an ADR does not become a dump of source notes. **Cross-link** when a wiki page forces a choice, or when an accepted ADR changes what the wiki says.

Agent instructions: [AGENTS](INV-42043%20-%20NVNM-Cite/AGENTS.md) → [CLAUDE](INV-42043%20-%20NVNM-Cite/CLAUDE.md).

## Application

Code lives at `/Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite`.

## Start here

1. Read [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md).
2. Drop sources into `raw/` (never edit them after).
3. Ingest into `wiki/` (summaries, concept pages, how-tos).
4. When you hit a fork (two ways to build it), open an ADR in `decisions/`.
5. Link both ways. Update [NVNM-Cite (INV-42043)/wiki/index](INV-42043%20-%20NVNM-Cite/wiki/index.md) and [NVNM-Cite (INV-42043)/decisions/INDEX](INV-42043%20-%20NVNM-Cite/decisions/INDEX.md). Append both logs.

## qmd (search)

From this folder:

```bash
qmd collection add "$(pwd)" --name nvnm-cite-inv-42043 --mask "**/*.md"
qmd context add qmd://nvnm-cite-inv-42043 "NVNM-Cite (INV-42043) investigation"
qmd embed
qmd update
```

Or run `_resources/scripts/qmd-sync.sh "$(pwd)"` (reads `qmd-collection` in this folder). There are no hooks — after each page add or edit, the agent must `qmd update` and `qmd embed -c nvnm-cite-inv-42043` (or that script). Exclude `raw/` from the collection if you add it later (sources stay immutable and unindexed).
