---
name: Qmd Code Search
date: 2026-09-01T10:25:00.000Z
tags:
  - qmd
  - guide
  - how-to
  - search
---

# Qmd Code Search

**Summary**: Use qmd as a path finder over TS/JS/Python/Go, then confirm with grep. That pairing cuts token spend only when it replaces exploratory file reads — not when it stacks on top of them.

**Sources**: [tobi/qmd](https://github.com/tobi/qmd); vault wiki workflow in project `CLAUDE.md` files.

**Last updated**: 2026-09-01

---

Wiki collections stay on `**/*.md`. Code is a **separate** collection. Do not mix them: a prose query over the monorepo drowns in source hits; a code query over the wiki returns notes instead of types.

QMD already chunks `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.go`, and `.rs` with tree-sitter when AST mode is on. Markdown and other types stay on regex chunking. Default mask is `**/*.md`, so code is invisible until you add a collection.

## When to use which

| Situation | Tool |
| --------- | ---- |
| Known identifier (`resolveHubKey`, a filename, an error string) | Skip qmd. `rg` that string. |
| Natural-language question, no symbol yet (“where is scoped hub key resolution?”) | qmd → grep in those paths → read 1–2 files. |
| Go-to-def / find-refs / rename | Not qmd. LSP / Serena / the IDE. |
| Structural pattern (`function $X($Y: HubKey)`) | Not qmd. [ast-grep](https://ast-grep.github.io/). |

`inveniam-v2` is ~6,600 TS/JS files. A 40KB service is ~10k tokens if you `Read` the whole file. QMD chunks are ~900 tokens. The win is “5 paths” instead of “open 8 large files.”

## Token rule

qmd saves tokens when it **replaces** exploratory reads. It costs tokens when it **precedes** the same reads you would have done anyway.

**Spends less**

1. `qmd search` or `qmd vsearch` with `--files` (paths only, no bodies).
2. `rg` **only inside those paths** for the symbol you now have.
3. `Read` 1–2 files, or a line range, only if you will edit or the match is not enough.

**Spends more**

- `qmd query` (hybrid + rerank) dumping 5×900-token chunks, **then** repo-wide grep, **then** reading the same files.
- The same snippet appearing three times in the thread.
- Pasting `qmd update` / `qmd embed` logs into the chat. Local compute is free; log spam is not.

The local reranker does not bill extra model tokens. It still dumps more text into the agent context than `search --files`. Prefer `--files` for code path-finding. Use `qmd query` on wiki collections, not as the first step over source.

## Protocol

```text
unknown symbol  →  qmd vsearch "…" --files -n 8 -c <code-collection>
known symbol    →  skip qmd, rg the identifier
qmd suggested paths  →  rg in those files only
need the body        →  Read those 1–2 files (or stay on the chunk)
```

Scope every query with `-c`. Do not run unscoped `qmd query` over the whole machine.

```bash
# Path finder (preferred for code)
qmd vsearch "where is scoped hub key resolution?" --files -n 8 -c inveniam-v2
qmd search "HubKey" --files -n 8 -c inveniam-v2

# Confirm inside the hits only
rg -n "resolveHubKey|scopedHubKey" <path1> <path2> <path3>

# Wiki (unchanged): hybrid + rerank, then read the page
qmd query "scoped hub key promotion" -c hub-keys-everywhere
```

`--files` is the token-saving flag. Default `qmd query` returns ranked chunks (~900 tokens each, default 5; `--json` / `--files` default 20 — cap with `-n`).

## One-time code collections

`node_modules`, `.git`, `dist`, `build`, and `vendor` are built-in excludes. Keep wiki reindex (`qmd-sync.sh` after page edits) off these collections.

```bash
qmd collection add /Users/valeriyilihmetov/work/inveniam/inveniam-v2 \
  --name inveniam-v2 \
  --mask "**/*.{ts,tsx,js,jsx}"
qmd context add qmd://inveniam-v2 "Inveniam v2 Angular/TS UI"

qmd collection add /Users/valeriyilihmetov/work/inveniam/nvnm \
  --name nvnm \
  --mask "**/*.{py,go,ts}"
qmd context add qmd://nvnm "NVNM Python/Go/TS"

qmd embed --chunk-strategy auto
```

`--chunk-strategy auto` is required for AST break points. Without it, code is regex-sliced like prose. If tree-sitter grammars are missing, qmd falls back to regex and does not fail.

Suggested names: `inveniam-v2`, `nvnm`. Add more repos the same way. Do not point a code collection at `docs-vault`.

Reindex a code collection after large pulls or when hits look stale:

```bash
qmd update
qmd embed --chunk-strategy auto -c inveniam-v2
```

Do not reindex code after every function edit. Do reindex the **wiki** collection after every vault page add or edit (see the project `CLAUDE.md`).

## Related pages

- [How To New Investigation](_resources/templates/How%20To%20New%20Investigation.md) — wiki/ADR qmd setup
- [Resources](Resources.md) — qmd upstream
- Project `CLAUDE.md` — wiki collection name and reindex duty
