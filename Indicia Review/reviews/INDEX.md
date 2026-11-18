---
name: Review register
date: 2026-10-27T08:10:00.000Z
tags:
  - indicia-review
  - pr-review
  - index
---

# Review register — Indicia

Every pull request reviewed in this folder. **Newest first.**

## How to use

- One page per pull request: `PR-<number> Short Title.md`, using the number GitHub assigned, not zero-padded.
- Copy [PR Review Template](PR%20Review%20Template.md), fill it, then add a row below.
- Verdict is one of `Approve`, `Approve with comments`, `Request changes`. It is advisory — the human posts it to GitHub.
- Never delete a review. A re-review after changes gets a new dated section inside the same page, so the page keeps the whole history of what was asked and what came back.
- The review loop, the two axes, the severity vocabulary, and the gate checklist are in [CLAUDE](../CLAUDE.md).
- Orient the diff first with the [codebase map](../map/INDEX.md), whose ownership table says what a change in each package obliges you to check.

## Register

| PR | Title | Author | Reviewed | Verdict | Blockers |
| -- | ----- | ------ | -------- | ------- | -------- |
| [49](PR-49%20Stop%20Leaking%20Database%20Errors%20on%20Reads.md) | Stop leaking database errors on read endpoints | mykhailonovak-devpro | 2026-10-30 | Approve | 0 |
| [48](PR-48%20Anchor%20Status%20Missing%20Batch%20404.md) | Return 404 when the anchor-status batch row is missing | mykhailonovak-devpro | 2026-10-30 | Approve | 0 |
| [44](PR-44%20Record%20Redis%20Password%20Bar.md) | Record the non-empty Redis password bar | mykhailonovak-devpro | 2026-10-29 | Approve with comments | 0 |
| [47](PR-47%20Fail%20Closed%20Missing%20immudb%20Latch.md) | Fail closed when the immudb integrity latch is missing | mykhailonovak-devpro | 2026-10-28 | Approve | 0 |
| [43](PR-43%20Erase%20Seal%20Race%20Test%20Slow%20Path.md) | Fix the erase/seal race test so it exercises the slow path | mykhailonovak-devpro | 2026-10-28 | Approve with comments | 0 |
| [42](PR-42%20Classify%20immudb%20Integrity%20Errors.md) | Classify immudb integrity errors on pinned sentinel text | mykhailonovak-devpro | 2026-10-28 | Approve | 0 |
| [41](PR-41%20Document%20retrieval_error%20on%20Status%20Reads.md) | Document the 500 retrieval_error on GetAnchorStatus and GetBatch | mykhailonovak-devpro | 2026-10-28 | Approve | 0 |
| [40](PR-40%20API%20Spec%20Admin%20Role%20References.md) | Remove remaining admin role references from the API specification | mykhailonovak-devpro | 2026-10-28 | Approve with comments | 0 |
| [39](PR-39%20Stop%20Tracing%20Kubernetes%20Health%20Probes.md) | Stop tracing Kubernetes health probes | mykhailonovak-devpro | 2026-10-28 | Approve | 0 |
| [38](PR-38%20Trace%20The%20Sidecar%20And%20Pass%20Context%20To%20Core.md) | Trace the sidecar and pass context to core | mykhailonovak-devpro | 2026-10-27 | Request changes | 2 |

## Related

- [Project README](../README.md)
- [Change log](log.md)
