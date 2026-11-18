# Log

Append-only record of wiki operations.

- 2026-08-20: Restructured directory to match `raw/` / `wiki/` layout. Created empty `raw/`. Moved all existing pages (7 top-level Smart Accounts pages, `Anchoring/`, `Debugging/`) into `wiki/`. Created `wiki/index.md` and this log. No source ingestion performed — existing pages predate this structure and have no linked raw source files.
- 2026-08-21: Added the YAML frontmatter (`name`/`date`/`tags`) requirement + tag vocabulary to `CLAUDE.md` (Obsidian tag organization) and updated the page-format template to include frontmatter.
- 2026-09-01: Removed Cursor/Obsidian qmd reindex hooks. CLAUDE.md requires the agent to reindex with qmd. AGENTS.md defers to CLAUDE.md.
- 2026-09-01: CLAUDE.md points at vault-wide [Qmd Code Search](_resources/Qmd%20Code%20Search.md) for TS/JS/Python/Go (qmd `--files` → grep → read 1–2 files). Wiki collection stays markdown-only.
