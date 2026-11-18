---
name: CLAUDE.md
date: 2026-08-20T07:04:51.681Z
tags:
  - smart-accounts
  - wiki
  - guide
---
# LLM Wiki
A personal knowledge base maintained by Claude Code.

## Purpose
This wiki is a structured, interlinked knowledge base for planning a trip to Japan.
Claude maintains the wiki. The human curates sources, asks questions, and guides the analysis.

## Folder structure

```
AGENTS.md -- follow CLAUDE.md
CLAUDE.md -- this guide
raw/ -- source documents (immutable -- never modify these) 
wiki/ -- markdown pages maintained by Claude
wiki/index.md -- table of contents for the entire wiki
wiki/log.md -- append-only record of all operation
```

## Ingest workflow
When the user adds a new source to `raw/` and asks you to ingest it:

1. Read the full source document
2. Discuss key takeaways with the user before writing anything
3. Create a summary page in `wiki/` named after the source
4. Create or update concept pages for each major idea or entity
5. Add Markdown links (`[Page Name](Page%20Name.md)`) to connect related pages
6. Update `wiki/index.md` with new pages and one-line descriptions
7. Append an entry to `wiki/log.md` with the date, source name, and what changed
8. Reindex qmd (`qmd update` and `qmd embed -c wiki`). There are no hooks. See [Search tool (qmd)](#search-tool-qmd) below.

A single source may touch 10-15 wiki pages. That is normal.

## Frontmatter & tags (required)

Every wiki page starts with a YAML frontmatter block so Obsidian can organize and filter by tag, and so search can be scoped by topic:

```yaml
---
name: Smart Accounts Diagram
date: 2026-08-08T20:14:00.000Z
tags:
  - smart-accounts
  - zerodev
  - erc-4337
  - architecture
  - diagram
---
```

Rules:

- `name` — the human title (usually matches the H1 / filename).
- `date` — ISO 8601 (`YYYY-MM-DDTHH:mm:ss.SSSZ`); use the creation/last-updated date.
- `tags` — a YAML list, lowercase, hyphenated, **no `#` prefix** (Obsidian adds it in the tag pane). Reuse existing tags before inventing new ones so the tag graph stays connected.
- Keep the in-body **Summary / Sources / Last updated** block too (see Page format) — that's for humans reading the rendered note; frontmatter is for Obsidian's tag/search machinery.

**Tag vocabulary** for this wiki (extend deliberately):

- Domain: `smart-accounts`, `zerodev`, `erc-4337`, `account-abstraction`, `paymaster`, `bundler`
- Doc type: `architecture`, `diagram`, `guide`, `index`, `log`, `source-summary`

Add frontmatter to any page that's missing it before editing, then re-run `qmd update`.

## Page format

Every wiki page should follow this structure:

```markdown
---
name: Page Title
date: YYYY-MM-DDT00:00:00.000Z
tags:
  - smart-accounts
  - <topic-tags>
---

# Page Title

**Summary**: One to two sentences describing this page.

**Sources**: List of raw source files this page draws from.

**Last updated**: Date of most recent update.

---

Main content goes here. Use clear headings and short paragraphs.

Link to related concepts using Markdown links (`[Concept](Concept.md)`) throughout the text.

## Related pages

- [Related Concept 1](Related%20Concept%201.md)
- [Related Concept 2](Related%20Concept%202.md)
```

## Citation rules

- Every factual claim should reference its source file
- Use the format (source: filename.pdf) after the claim
- If two sources disagree, note the contradiction explicitly
- If a claim has no source, mark it as needing verification

## Search tool (qmd)

Use `qmd` to search the wiki instead of reading `wiki/index.md` by hand. It is a local hybrid BM25/vector search engine over markdown, with an optional LLM reranker, on-device.

Installed globally: `qmd <command>`. MCP server configured in `.mcp.json` at project root (`qmd mcp`).

Setup (one-time):
```bash
qmd collection add "$(pwd)/wiki" --name wiki --mask "**/*.md"   # mask must be recursive to catch subfolders (Anchoring/, Debugging/)
qmd context add qmd://wiki "LLM Wiki for Smart Accounts"
qmd embed
qmd update
```

Or `_resources/scripts/qmd-sync.sh "$(pwd)"`. There are no hooks — reindex after every page add or edit.

Searching (prefer the MCP tools `mcp__qmd__query` / `mcp__qmd__get` / `mcp__qmd__status` when connected; CLI equivalents below):
```bash
qmd query "<question>" -c wiki       # best quality: hybrid + rerank
qmd search "<keywords>" -c wiki      # fast BM25-only lookup
qmd vsearch "<question>" -c wiki     # semantic-only lookup
qmd get "wiki/<page>.md"             # fetch a page by path
```

This collection is the wiki (`**/*.md`). For application source (TS/JS/Python/Go), follow [Qmd Code Search](_resources/Qmd%20Code%20Search.md): qmd `--files` → grep those paths → read 1–2 files. Do not add source trees to this collection.

## Question answering

When the user asks a question:

1. Use `mcp__qmd__query` (or `qmd query "<question>" -c wiki`) to find relevant pages
2. Read those pages and synthesize an answer
3. Cite specific wiki pages in your response
4. If the answer is not in the wiki, say so clearly
5. If the answer is valuable, offer to save it as a new wiki page

Good answers should be filed back into the wiki so they compound over time.

## Lint

When the user asks you to lint or audit the wiki:

- Check for contradictions between pages
- Find orphan pages (no inbound links from other pages)
- Identify concepts mentioned in pages that lack their own page
- Flag claims that may be outdated based on newer sources
- Check that all pages follow the page format above
- Report findings as a numbered list with suggested fixes

## Rules

- Never modify anything in the `raw/` folder
- Always update `wiki/index.md` and `wiki/log.md` after changes
- Name pages naturally, Obsidian-style: Title Case with spaces (e.g. `Machine Learning.md`), matching existing pages
- Write in clear, plain language
- When uncertain about how to categorize something, ask the user

