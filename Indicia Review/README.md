---
name: Indicia Review
date: 2026-10-27T08:10:00.000Z
tags:
  - indicia-review
  - pr-review
  - index
---

# Indicia Review

Pull request reviews of the **Inveniam Indicia API**. One page per PR, one register to scan them, and an immutable copy of what each review was based on.

| Path | Job |
| ---- | --- |
| [map/INDEX.md](map/INDEX.md) | Codebase map — topology, package ownership, and what a diff in each package obliges you to check |
| [reviews/INDEX.md](reviews/INDEX.md) | Register — every PR reviewed, with its verdict |
| [reviews/PR Review Template.md](reviews/PR%20Review%20Template.md) | Copy this to start a review |
| [reviews/log.md](reviews/log.md) | Append-only change log |
| `raw/PR-<number>/` | Immutable artifacts: diff, CI failure log, ticket export |

`map/` is the standing picture of the system. `reviews/` is one page per pull request. A durable fact about how the system is built goes in the map; a finding about one diff goes in a review.

Agent instructions: [AGENTS](AGENTS.md) → [CLAUDE](CLAUDE.md).

## Application

- `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia` (`github.com/inveniamcapital/InveniamIndicia`)

Review scope is the whole repository: two Go services (`cmd/api` and `cmd/sidecar`), the helper scripts in `scripts/`, `deployments/`, `.github/`, and `docs/`. There is no frontend in this repository.

## Start a review

1. `gh pr view <number>` — pin the PR, its author, its base, and the originating ticket.
2. `gh pr diff <number> > "raw/PR-<number>/diff.patch"` — save the diff, then never edit it.
3. `gh pr checks <number>` — and if red, save the failing log beside the diff.
4. Look up each changed package in [map/INDEX.md](map/INDEX.md) and read what a diff there obliges you to check.
5. Copy [reviews/PR Review Template.md](reviews/PR%20Review%20Template.md) to `reviews/PR-<number> Short Title.md` and work the two axes and the gate checklist in [CLAUDE](CLAUDE.md).
6. Add a row to [reviews/INDEX.md](reviews/INDEX.md), newest first, and append [reviews/log.md](reviews/log.md).
7. Reindex qmd.

**Read only, throughout.** The application repository is never written to, `gh` is never used to post, comment, approve, or merge, and findings never carry a proposed fix. The agent drafts the comment text in the review page; a human posts it. The only files written are the markdown pages in this folder. See [AGENTS](AGENTS.md).

## qmd (search)

First-time setup, from this folder:

```bash
qmd collection add "$(pwd)" --name indicia-review --mask "**/*.md"
qmd context add qmd://indicia-review "Indicia PR reviews and codebase map"
qmd embed
qmd update
```

Or run `../_resources/scripts/qmd-sync.sh "$(pwd)"`, which reads `qmd-collection` in this folder. There are no hooks — after each page add or edit, run `qmd update` and `qmd embed -c indicia-review`.

The mask covers every markdown file, so the map and the reviews are both searchable. `raw/` stays out of the index by convention instead: artifacts are saved as `diff.patch`, `ci-failed.log`, and `ticket.txt`, never as markdown.

For application source in Go, TypeScript, or JavaScript, do not expand this mask. Use [Qmd Code Search](../_resources/Qmd%20Code%20Search.md).
