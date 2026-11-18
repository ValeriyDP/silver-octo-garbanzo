# Vault documentation rules

Read this file before writing or editing any page under `docs-vault/`. Cursor rules in `.cursor/rules/` repeat the same constraints.

Project-local `AGENTS.md` / `CLAUDE.md` (wiki vs ADR, qmd collection, application paths) still apply inside that investigation folder. These vault rules govern **how** pages are written.

## Voice

- Formal register. No chapter asides.
- Linear: top to bottom. Do not send the reader to another section for a fact they need now. Place the type, payload, or policy at the step that uses it.
- Current state only. Do not narrate earlier drafts, “originally requested”, or closed investigation leftovers.

## Names

- **THE HUB** — third-party signer. Not part of IO. Black box. Do not change it unless the page is explicitly about a THE HUB change.
- **IO Hub Service** — IO `inv-hub-ms` / `apps/hub-service`.
- Keep source identifiers as in code (`EnsureHubOrg`, event classes, env vars, table names).
- Expand an abbreviation on first use: `Chain of Responsibility (CoR)`. Add it to Terminology when the page has that table.

## Body

- No ticket IDs in the page body. Frontmatter tags and `wiki/log.md` may use them.
- Event payloads: TypeScript types in fenced blocks, not field tables.
- Environments: **live** vs **non-live**. Do not name concrete overlays.
- Ground claims in real files (migrations, `helm_env_configs`, exported types). Do not invent APIs.
- Standalone handoff: no outbound wiki or ADR links. Embed what the next reader needs.

## After every wiki edit

1. Register a new page on that project’s `wiki/index.md`.
2. Append `wiki/log.md`.
3. Reindex: from the project folder, `../_resources/scripts/qmd-sync.sh "$(pwd)"`.

Never modify `raw/`. Keep secrets out of pages.
