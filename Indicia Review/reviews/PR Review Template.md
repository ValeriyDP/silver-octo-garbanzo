---
name: PR-XXX Short Title
date: YYYY-MM-DDTHH:mm:ss.SSSZ
tags:
  - indicia-review
  - pr-review
  - pr-xxx
---

# PR-XXX Short Title

- **Pull request**: <url>
- **Author**: <handle>
- **Base ← Head**: `main` ← `INV-<key>-<slug>`
- **Commits**: <n> · **Files changed**: <n> · **Lines**: +<n> / −<n>
- **CI run**: <id> — <success | failure | not run>
- **Reviewed**: YYYY-MM-DD
- **Verdict**: Approve | Approve with comments | Request changes

## Scope

One line: what the PR changes. One line: the requirement behind it, or `no spec` — which bounds what the Spec axis can claim.

One line recording that the checks ran: how many PR-body claims were verified, and which gates failed, or `gates pass`. The checks are not written out — only what they turned up.

## Findings

Severity is one of **Blocker**, **Major**, **Minor**, **Nit**, **Question**. Axis is **Standards** or **Spec**. Skip anything the tooling already enforces.

Temperature 0: `defect` / `reason` / `impact`, one line each, no hedging, no narration. `impact` is **breaks**, **not fixed**, or **caused** — one of the three. The full rule is in [CLAUDE](../CLAUDE.md).

```
<Severity> · <path:line>
defect:  
reason:  the rule file and rule, or the spec line — "<quote>"
impact:  
```

## Draft comment

Text ready for a human to paste into GitHub. Lead with the verdict and the blocking items, then the rest in severity order. Nits marked optional. No secret values, no environment variable contents.

## Follow-ups

Anything deferred, and where it is tracked. A design fork worth recording belongs in an Architecture Decision Record in the application repository, not here.

## Related

- [Review register](INDEX.md)
- [Codebase map](../map/INDEX.md)
- Artifacts: `raw/PR-XXX/`
