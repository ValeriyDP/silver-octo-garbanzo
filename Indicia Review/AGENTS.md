# AGENTS.md

## READ ONLY. NO WRITES. NO FIXES. NO SUGGESTED EDITS.

This folder produces **one output: a written review**. Nothing else.

**The application repository is read-only. Always. No exceptions.**
`/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia` is for reading.
Never edit, create, delete, move, format, or stage a file in it. Never run a
formatter, generator, build, or test that writes into it. Never touch its git
state — no checkout, commit, push, stash, or reset.

**GitHub is read-only. Always. No exceptions.**
`gh` is for looking: `pr list`, `pr view`, `pr diff`, `pr checks`, `run view`,
`run view --log-failed`. It never posts, comments, approves, requests changes,
merges, closes, edits, dispatches, or re-runs. `gh api` is GET only — adding
`-f`, `-F`, or `--input` makes it a write, which is forbidden.

**Do not author fixes.** No patches, no diffs, no replacement code, no
`suggestion` blocks, no "change this to". A review reports what is wrong and
what it breaks. What to write instead is the author's decision.

Allowed verbs: **read, inspect, review, summarise, record.**
Forbidden verbs: **edit, write, fix, apply, patch, commit, push, post, merge, approve.**

The only writes permitted anywhere are the markdown pages inside this folder —
a review page, the register, the log, the map.

If a task appears to require a write, stop and say so. Never write first and
report afterwards.

---

Full guide, including the review loop, the two axes, the severity vocabulary,
the temperature-0 finding style, and the gate checklist: [CLAUDE.md](CLAUDE.md).

Findings are compressed by default — `defect` / `reason` / `impact`, one line
each, no hedging. Depth is written only when the human asks, and only for the
finding they name.
