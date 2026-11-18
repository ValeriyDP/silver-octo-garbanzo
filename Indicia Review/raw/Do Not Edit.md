---
name: Do Not Edit
date: 2026-10-27T08:10:00.000Z
tags:
  - indicia-review
  - raw
---

# raw/

Immutable artifacts for each review, one directory per pull request:

```
raw/PR-123/diff.patch       gh pr diff 123 > …
raw/PR-123/ci-failed.log    gh run view <id> --log-failed > …   (only when checks are red)
raw/PR-123/ticket.txt       ticket or specification export, if one exists
```

**Never edit anything in this folder** once written. The point is that a review stays readable after the branch is deleted and the pull request is squashed away: the diff on file is the diff the review was actually based on.

Interpretation goes in `reviews/`; the standing picture of the system goes in `map/`.

Use non-markdown extensions, as above. The qmd collection masks every markdown file in this folder, so a `ticket.md` would be indexed and would compete with real review pages in search results. `ticket.txt` will not.

Keep secrets out. If a diff contains a committed credential, that is a Blocker finding in the review — name the file and the variable, never the value.
