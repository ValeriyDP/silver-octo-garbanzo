---
name: How To New Investigation
date: 2026-09-01T07:38:00.000Z
tags:
  - guide
  - template
---

# How to start a new investigation

Templater command that copies `_resources/templates/investigation-project/` and fills the name / ticket / tag / repo paths. An agent can scaffold the same skeleton; it must ask for the repo path(s) first.

## Agent: ask before you create

When an agent starts a new LLM wiki (this template, not an existing folder):

1. Ask the human for **project name**, optional **ticket**, and **absolute path(s) to the repo(s)** this wiki is about. One wiki may cover several repos. Do not guess a path from the title.
2. Copy `_resources/templates/investigation-project/`, fill the placeholders, write the paths into `CLAUDE.md` and `README.md`.
3. If Application path(s) is later missing or wrong, stop and ask again before investigating code.

## Create the folder (Templater)

1. Open the vault folder where the project should live (usually the vault root).
2. **Templater: Insert template** → **New Investigation Folder**.
3. Enter **project name**, optional **ticket** (`INV-42086`), a **primary tag** (kebab-case), and **application repo path(s)** (absolute; comma-separated if several).
4. Opens `README.md` in the new folder. If paths were left blank, the agent must ask before investigating.

Layout (same idea as Hub Keys Everywhere + Smart Accounts):

```
INV-XXXXX - Project Name/
  README.md          -- human start
  AGENTS.md          -- follow CLAUDE.md; ask for repo paths if unset
  CLAUDE.md          -- agent: wiki vs ADR + cross-links
  qmd-collection     -- qmd name/context for the collection
  .mcp.json
  raw/               -- immutable sources (Smart Accounts)
  wiki/              -- knowledge base (Smart Accounts)
    index.md
    log.md
    Open Questions.md
  decisions/         -- ADR investigation (Hub Keys Everywhere)
    INDEX.md
    log.md
    ADR Template.md
```

## Add pages later

| Need | Template | Put the file in |
| ---- | -------- | --------------- |
| How-to, diagram, current state | **Investigation Wiki Page** | `wiki/` |
| A design choice | **Investigation ADR** | `decisions/` — then add a row to `decisions/INDEX.md` |

Link wiki ↔ decisions with relative Markdown links (`../decisions/ADR-0001%20Title.md`). Do not copy the full argument to both sides.

## Search

`qmd` is installed globally. First-time collection setup is in the project's `README.md`, or run `_resources/scripts/qmd-sync.sh` from the project folder. There are no hooks. After each page add or edit, the agent reindexes (`qmd update` + `qmd embed`, or that script) as required by the project's `CLAUDE.md`.

Wiki collections are `**/*.md` only. To search TS/JS/Python/Go without dumping large files into context, follow [Qmd Code Search](_resources/Qmd%20Code%20Search.md): qmd as a path finder (`--files`), grep to confirm, then read 1–2 files. Do not mix code and wiki in one collection.
