---
name: CLAUDE.md
date: 2026-10-27T08:10:00.000Z
tags:
  - indicia-review
  - pr-review
  - guide
---

# CLAUDE.md — Indicia Review

> ## READ ONLY. NO WRITES. NO FIXES. NO SUGGESTED EDITS.
>
> This folder produces **one output: a written review**. Nothing else.
>
> **The application repository is read-only. Always. No exceptions.**
> Do not edit, create, delete, move, format, or stage a single file in it. Do not
> run `go fmt`, `make`, a code generator, or anything that writes to that tree.
> Do not check out, fetch into, stash, reset, or otherwise touch its git state.
>
> **GitHub is read-only. Always. No exceptions.**
> `gh` is for looking. It never posts, never comments, never approves, never
> merges, never dispatches, never closes.
>
> **Do not author fixes.** Not as a patch, not as a diff, not as replacement
> code, not as "here's how I'd write it", not as a `suggestion` block. A review
> reports what is wrong and what it breaks. Deciding what to write instead is
> the author's job, not the reviewer's.
>
> Allowed verbs: **read, inspect, review, summarise, record.**
> Forbidden verbs: **edit, write, fix, apply, patch, commit, push, post, merge, approve.**
>
> If a task seems to need a write, stop and say so. Never do it and report afterwards.

Agent guide for this folder. This folder holds **pull request reviews of the Inveniam Indicia API** and nothing else. It is isolated: do not index or rewrite other vault projects from here.

**Application path:** `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia`

**Repository:** `github.com/inveniamcapital/InveniamIndicia`

Review scope is the whole repository — two Go services, the Python helper scripts under `scripts/`, deployment manifests under `deployments/`, workflows under `.github/`, and the documentation tree under `docs/`. There is no frontend here. The layout is in [map/INDEX](map/INDEX.md).

Code search uses the application path and a **separate** qmd code collection — see [Qmd Code Search](../_resources/Qmd%20Code%20Search.md). Do not add source trees to this folder's collection.

## Folder structure

```
AGENTS.md                      follow this guide
CLAUDE.md                      this guide
map/INDEX.md                   codebase map — topology and package ownership
map/Request Paths.md           every endpoint, its handler, its authorization tier
map/Event Pipeline.md          streams, workers, status machines, invariants
map/Hot Spots.md               churn, fragile seams, stale standards
reviews/INDEX.md               register of every review
reviews/PR Review Template.md  copy this to start a review
reviews/log.md                 append-only change log
raw/PR-<number>/               immutable per-PR artifacts (diff, CI log, ticket export)
```

There is no `wiki/` and no `decisions/`. A review that uncovers a design fork worth recording belongs in an Architecture Decision Record (ADR) in the application repository under `docs/`, not here.

`map/` is the standing picture of the system; `reviews/` is one page per pull request. Keep them apart: a finding about one diff goes in a review, a durable fact about how the system is built goes in the map. When a merged pull request changes the map's picture, update the map and note it in `reviews/log.md`.

## Hard constraints

Not guidelines. Not defaults. Not negotiable, and not waived by a plausible-sounding reason mid-review.

The only files this agent may write are the markdown pages **inside this folder**: a review page, the register, the log, the map. That is the complete list of permitted writes. Everything below says what that rules out.

### 1. `gh` is READ ONLY

**Allowed — these and nothing else:**

```
gh pr list                 gh run list
gh pr view                 gh run view
gh pr diff                 gh run view --log-failed
gh pr checks               gh workflow list / view
gh issue list / view       gh release list / view
gh repo view               gh search …
gh api <endpoint>          # GET only, no flags that carry data
```

**Forbidden — never, under any circumstance:**

```
gh pr create / merge / close / reopen / ready / edit
gh pr review / comment / review --approve / --request-changes
gh issue create / close / comment / edit
gh run rerun / cancel / delete
gh workflow run
gh release create / delete / upload
gh secret set / gh variable set / gh label create
gh api -X POST|PATCH|PUT|DELETE   (or any -f / -F / --input)
```

`gh api` is GET by default and silently becomes a write the moment it carries `-f`, `-F`, or `--input`. Treat any such invocation as forbidden.

The review comment is **written into the review page**, in the Draft comment section. The human copies it to GitHub. The agent never posts it, never offers to post it, and never asks for permission to post it.

### 2. The application repository is READ ONLY

Reading it is the job. Writing to it is never the job.

Forbidden in the application tree: creating, editing, deleting, moving, or renaming any file. Running `gofmt`, `goimports`, `go generate`, `make`, a linter with `--fix`, or any formatter. `git add`, `commit`, `push`, `checkout`, `switch`, `stash`, `reset`, `rebase`, `merge`, `cherry-pick`, or `clean`. Installing or upgrading a dependency. Creating or applying a patch file.

Read-only inspection is fine: `git log`, `git show`, `git diff` without writing, `rg`, and reading files.

A build or test run that writes artefacts into the tree counts as a write. If verifying a claim would require running the code, state the claim as unverified instead.

### 3. Report defects. Do NOT author fixes.

A finding says what is wrong and what it breaks. It does not say what to type instead.

Forbidden: replacement code, patches, diffs, GitHub `suggestion` blocks, before-and-after snippets, pseudo-code for the corrected version, or a line beginning "change this to". Naming the mechanism that is violated is the citation, not an instruction — `reason:` points at the rule; it does not rewrite the code.

The distinction in practice:

```
✓ defect:  batch status read, then written in a separate UPDATE
✓ reason:  CODING_STANDARDS.md "Atomic State Transitions" — claims are UPDATE … WHERE status = 'expected', row count checked
✓ impact:  breaks — two workers claim one batch, double Hub submission, duplicate anchor

✗ "Replace lines 261-264 with: claimed, err := w.postgres.ClaimBatchForAnchoring(...)"
✗ "Suggested fix: wrap it in a transaction and check RowsAffected."
```

The author decides what to write. The reviewer decides whether what was written is wrong.

### 4. No secret material in these pages

Never copy an environment variable value, token, key, or credential out of a diff into a review page — not even abbreviated, and not as a realistic-looking placeholder. Reference the variable name only. If a diff contains a committed secret, that is a Blocker finding: name the file and the variable, never the value.

## Review loop

1. **Pin the PR.** `gh pr view <number> --json title,author,baseRefName,headRefName,url,commits,files`. Record the originating ticket if the PR or its commits reference one.
2. **Pull the artifacts into `raw/PR-<number>/`.** `gh pr diff <number> > raw/PR-<number>/diff.patch`. If checks are red, `gh run view <id> --log-failed > raw/PR-<number>/ci-failed.log`. Add the ticket or specification export as `ticket.txt` — a non-markdown extension keeps it out of the search index. Never edit these after writing them.
3. **Locate the diff on the map.** Find each changed package in the ownership table in [map/INDEX](map/INDEX.md) and read its obligation column — the consequences a diff can trigger in files it never touches. Then read the page the change calls for: [Request Paths](map/Request%20Paths.md) for endpoints and middleware, [Event Pipeline](map/Event%20Pipeline.md) for workers, statuses, and streams, [Hot Spots](map/Hot%20Spots.md) for fragile seams.
4. **Read the diff in full** before forming an opinion. For anything the diff does not explain on its own, read the surrounding file in the application repository.
5. **Check CI.** `gh pr checks <number>`. A red or missing run is context for the review, not a substitute for it.
6. **Work the two axes** (below), then the gate checklist.
7. **Write the review** from `reviews/PR Review Template.md` into `reviews/PR-<number> Short Title.md`.
8. **Register and log.** Add a row to `reviews/INDEX.md` (newest first) and append `reviews/log.md`.
9. **Reindex qmd** in the same turn. There are no hooks.

## The two axes

Every finding belongs to one of two axes. Work them separately so neither masks the other — code can follow every convention while implementing the wrong thing, and implement exactly the right thing while breaking every convention. The review page does not need a section per axis; the `reason` line names the rule file or the spec line, which is what identifies the axis.

- **Standards** — does the change conform to the repository's documented standards? The sources are `docs/standards/CODING_STANDARDS.md`, `CONTRIBUTING.md`, and the twelve rule files in `.cursor/rules/` — `error-handling.mdc`, `logging.mdc`, `testing.mdc`, `configuration.mdc`, `type-safety.mdc`, `security.mdc`, `go-style.mdc`, `licensing.mdc`, `ci.mdc`, `git-remotes.mdc`, `project-structure.mdc`, `general.mdc`. Cite the file and the rule rather than an opinion. Skip anything the tooling already enforces; `gofmt` and the linter do not need a human restating them. Check [Hot Spots](map/Hot%20Spots.md) first for the documented standards that no longer match the repository — enforcing those produces findings the author will correctly reject.
- **Spec** — does the change implement what the ticket asked for? Report requirements that are missing or partial, behaviour nobody asked for (scope creep), and requirements that look implemented but are implemented wrongly. Quote the specification line behind each finding. If there is no specification, say so rather than inventing one.

### A verified claim can still be the defect

Confirming that the code does what the PR body says is half the Spec axis. The other half is asking whether it should. A PR body is the author's intent, not a specification — it is the thing under review, so treating its claims as the standard to measure against reviews the diff against itself.

For every behavioural claim, ask two questions:

1. **Does the code do this?** Find the file and line that proves it.
2. **Should it?** Name who is served by the behaviour and who is harmed. A claim that introduces a new refusal, a new required variable, a new closed vocabulary, or a new default is a deployment contract change — check it against the platform that has to satisfy it, not only against the code that implements it.

Both questions are asked on every claim; neither answer is written up when it comes back clean. A claim that is implemented and should be implemented produces no text beyond the count in Scope. Question 2 coming back no, or needing the human, is a finding.

Watch for the specific shape that hides here: a change that is correct as code and wrong as policy. Fail-closed validation reads as a security improvement and is one in isolation, yet becomes an outage when the platform legitimately supplies a value outside the new vocabulary. Fail-open gating reads as flexibility and silently skips the checks that matter. Neither is visible from the diff alone.

When question 2 needs knowledge this repository does not hold — cluster names, collector topology, chart values, operational intent — say so in the finding and route it to the human rather than resolving it by assumption. "Verified against the PR body" is not a finding. See [PR 38](reviews/PR-38%20Trace%20The%20Sidecar%20And%20Pass%20Context%20To%20Core.md), where every claim held and one of them was the Major.

## Severity vocabulary

Fixed set. Do not improvise new levels.

| Severity | Meaning |
| -------- | ------- |
| **Blocker** | Must not merge. Committed secret, broken tenant isolation, data loss, prohibited licence, silent failure in a critical path. |
| **Major** | Should not merge as-is. Wrong behaviour, missing error handling, untested critical path, documented standard clearly violated. |
| **Minor** | Merge is acceptable; the author is expected to correct it. Naming, structure, a missing test on a non-critical path. |
| **Nit** | Taste. Explicitly optional, and labelled as such so the author can dismiss it without discussion. |
| **Question** | The reviewer does not understand something yet. Not a defect until answered. |

Verdicts are **Approve**, **Approve with comments**, or **Request changes**. Every verdict is advisory: it is written in the review page for the human, who decides and posts.

## Finding style — write at temperature 0

Findings and draft comments are written compressed and deterministic. No prose, no narration, no hedging. The same defect must always produce the same words.

Three fields per finding, in this order:

```
defect:  what is wrong, at path:line
reason:  the rule or mechanism it violates
impact:  what breaks — or what stays unfixed, or what it already caused
```

`impact` takes whichever form is true: **breaks**, **not fixed**, or **caused**. Pick one; do not write all three.

One line per field. Two lines total is acceptable when a field genuinely needs it. Beyond that, the finding is two findings.

### Required

- Cite `path:line`. Never describe a location in words.
- Name the violated rule by file: `security.mdc`, `CODING_STANDARDS.md`, `canonical/doc.go`. Not "best practice", not "convention".
- State the mechanism, not the feeling. "Read-then-write, no row-count check" — not "this looks racy".
- Use the same term the code uses.

### Forbidden

- Hedging: "might", "perhaps", "consider", "it may be worth", "I think".
- Praise, preamble, acknowledgement, summary of the diff.
- Restating what the diff does. The author wrote it.
- Explaining why the rule exists. Cite it; the reader can read it.
- Softening a Blocker into a suggestion.

### Example

Not this:

> I noticed that in the anchor worker it looks like the batch status is read and then updated in a separate statement, which might potentially allow two workers to pick up the same batch under load. It could be worth considering using the atomic claim pattern here instead, similar to how `ClaimBatchForAnchoring` does it.

This:

```
Blocker · internal/workers/anchor_worker.go:261
defect:  batch status read, then written in a separate UPDATE
reason:  CODING_STANDARDS.md "Atomic State Transitions" — claims are UPDATE … WHERE status = 'expected', row count checked
impact:  breaks — two workers claim one batch, double Hub submission, duplicate anchor
```

### Depth on request only

The compressed form is the finished product, not a summary of something longer. Do not pre-emptively expand, do not attach a "detail" or "background" subsection, do not offer one.

The human asks when a specific finding needs more. Only then, and only for that finding, write the long form: the mechanism, the call path, the exact input that triggers it, the blast radius. Still no proposed fix — depth means a fuller account of the defect, never a prescription for the code.

### Draft comment

Same style. Verdict on line one, then the findings in severity order, nothing else. No greeting, no thanks, no closing offer to help. Nits marked `(optional)` so the author can drop them without a reply.

## Gate checklist

Work this list against the diff. It is a checklist for the reviewer, not a section in the review page — a gate that passes or does not apply produces no text. Scope carries one line saying the gates ran and naming the ones that failed, or `gates pass`; each failure becomes a finding citing the file. Every item below is grounded in a real file in the repository.

### Build and continuous integration

- `make check-all` (format, vet, lint) and `make test` both pass locally. `CONTRIBUTING.md` requires this before push.
- `golangci-lint` is pinned to **v2.14.0** (`GOLANGCI_VERSION` in the `Makefile`). If the PR bumps it, four coordinates must move in the same commit: `.github/workflows/ci.yml` (both the `golangci/golangci-lint-action` version and the lint version), `.pre-commit-config.yaml` (`rev:`), the `Makefile`, and the documentation that quotes the version. The action must be v7 or later for a v2.x linter.
- A change to `GO_VERSION` in `.github/workflows/ci.yml` (currently `1.27`) or to the `golang:` builder tag in the `Dockerfile` drags the linter pin with it. A linter built against an older Go cannot read newer export data, and every package fails `typecheck`.
- CI jobs that must be green: **Lint**, **Test** (`-race`, CGO enabled), **Integration Tests** (`-tags=integration`, testcontainers), **Build & Checks** (which carries `go build`, `./scripts/license-check.sh`, and `govulncheck`), and **Docker Build**.
- Never approve a PR stacked on a red `main`.

### Dependency licensing

- Every new Go module needs its licence confirmed before it lands. There is no frontend in this repository — no `admin-ui/`, no `package.json`, no TypeScript — so the npm half of the policy has nothing to check here, and the Docker base-image half applies only when a diff actually touches `Dockerfile` or `deployments/`.
- Hard refusal: `GPL-2.0`, `GPL-3.0`, and above all `AGPL-3.0` — network use counts as distribution, which is fatal for an HTTP API.
- Case-by-case, requiring the human's explicit approval: `LGPL`, `BUSL-1.1` / `BSL-1.1`, `SSPL-1.0`, `Elastic-2.0`, `Commons-Clause`, `Confluent-Community-1.0`. HashiCorp packages published after August 2023 are BUSL; their older `MPL-2.0` releases such as `golang-lru` and `hcl` remain allowed.
- Two approved exceptions already exist and need no re-litigation: `github.com/codenotary/immudb` v1.11.x, and the `hashicorp/vault` Community Edition Docker image scoped strictly to local development. The canonical table lives in the repository's `.cursor/rules/licensing.mdc`; the machine-readable form is `.lichen.yaml`.
- Transitive dependencies count. A permissive direct dependency pulling in a GPL transitive is still a violation.

### Type safety

- No new `interface{}` or untyped `map[string]interface{}` in production code without a stated justification.
- Payload and event types move toward structs with `json` tags, not wider untyped maps.
- Exported API surfaces stay fully typed.

### Failure behaviour

- Fail fast. No silent default that masks a missing or malformed configuration value.
- No fallback that turns a dependency outage into a wrong answer. A clear failure beats false robustness.
- Errors are checked and wrapped with `%w`.
- For workers: context cancellation respected, resources released, transient and permanent errors distinguished, dead-letter handling intact.

### Security

- No secret, key, or credential in the diff. `git diff --cached --name-only` must never include a secret file, and `.gitignore` rules must not be weakened for convenience.
- Logs never carry passwords, signing keys, or complete bearer tokens. Authentication failures log reason codes.
- All SQL is parameterized.
- Every data endpoint validates tenant access from JWT claims, with company scoping applied consistently.
- HTTP payloads are size-limited and validated.

### Tests

- Table-driven tests with `t.Run` subtests, covering both success and error paths.
- External dependencies (Redis, Postgres, THE HUB) are mocked in unit tests.
- New critical-path code without a test is a Major finding.
- Production data is never faked or mocked into a test fixture.

### Documentation and migrations

- API surface changes update `docs/api/API_SPECIFICATION.md`.
- Configuration changes update `docs/guides/ENVIRONMENT_VARIABLES.md`. Configuration arrives through `INDICIA_*` environment variables.
- Schema changes ship with a migration, and the migration is reversible or its irreversibility is stated.

### Pull request hygiene

- One logical change per PR. A dependency on another PR is noted in the description. `internal/api/handlers` is the largest package in the repository, and the easiest place to violate this unnoticed.
- Branch and title follow observed practice: branch `INV-<key>-<slug>`, title `INV-<key> - <description>`, with Dependabot keeping its own `dependabot/...` form. `CONTRIBUTING.md` still documents `feat/<description>` and conventional commits, which no recent PR follows — review against practice and raise the mismatch once against `CONTRIBUTING.md`, not against each PR.
- First line of a commit under 72 characters, body explaining why rather than what.
- The content boundary holds: the core gains no content-bearing field, and the sidecar forwards only hashes, locators, and pseudonyms.
- Separation of concerns respected across `internal/api`, `internal/core`, `internal/storage`, and `internal/workers`.

## Page conventions

Review pages are named `PR-<number> Short Title.md`, using the number GitHub assigned. Do not zero-pad: the register sorts by the row order in `reviews/INDEX.md`, and padding a GitHub number invites mismatches with what the PR is actually called.

Frontmatter on every page:

```yaml
---
name: PR-123 Short Title
date: YYYY-MM-DDTHH:mm:ss.SSSZ
tags:
  - indicia-review
  - pr-review
  - pr-123
---
```

Tags are lowercase and hyphenated, with no `#` prefix. Reuse before inventing. Doc-type tags in use here: `pr-review`, `guide`, `index`, `log`, `raw`.

Write in a formal register and linear order: top to bottom, with the fact placed at the step that needs it rather than cross-referenced from elsewhere. Record current state only — not what an earlier draft of the PR did. Keep ticket identifiers out of page bodies; frontmatter tags and `reviews/log.md` may carry them.

Markdown links, with spaces encoded as `%20`.

## Naming

- **THE HUB** — the third-party signer. Not part of Inveniam. A black box; do not describe changes to it unless the PR genuinely changes it.
- Keep source identifiers exactly as they appear in code: function names, event classes, environment variables, table names.
- Expand an abbreviation on first use.

## qmd

Collection name: `indicia-review`. Markdown only. Prefer the MCP tools `mcp__qmd__query`, `get`, and `status` when connected; otherwise the command line.

```bash
qmd query  "<question>" -c indicia-review
qmd search "<keywords>" -c indicia-review
qmd get    "reviews/INDEX.md"
```

After adding or editing any page, reindex in the same turn:

```bash
qmd update
qmd embed -c indicia-review
```

Or from this folder, `../_resources/scripts/qmd-sync.sh "$(pwd)"`, which reads `qmd-collection`. First-time setup is in the project [README](README.md).

The collection covers every markdown file in this folder, so the map pages and the review pages are both searchable. `raw/` stays effectively unindexed by convention rather than by mask: artifacts are saved with non-markdown extensions (`diff.patch`, `ci-failed.log`, `ticket.txt`), so a saved diff never competes with a review page in search results. Keep that convention when adding an artifact.

## Question answering

1. Search with qmd. If pages were just written, reindex first.
2. Read the hits and cite the review pages behind the answer.
3. If the answer is not in this folder, say so plainly, then offer to capture it.

## Audit

When asked to audit this folder, check for:

- Reviews missing from `reviews/INDEX.md`.
- Register rows pointing at files that do not exist.
- Map claims contradicted by a merged pull request, or by the repository as it stands today.
- Reviews whose verdict is `Request changes` where the PR has since merged.
- Review pages with no corresponding `raw/PR-<number>/` artifacts.
- Findings with a severity outside the fixed vocabulary.
- Broken Markdown links.
- A stale qmd index.

## Rules

- Never modify `raw/`.
- Never modify the application repository from here.
- Always update `reviews/INDEX.md` and `reviews/log.md` after a change, then reindex qmd.
- Keep secrets out.
- Durable review records, not a session diary.
