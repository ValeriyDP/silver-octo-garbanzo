---
name: Decision register
date: 2026-09-03T15:12:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - adr
  - index
---

# Decision register — Inveniam Indicia (INV-42236)

Architecture Decision Records for this investigation. Each note is **context → decision → consequences**.

Knowledge (how it works, how-tos) lives in [wiki/index](../wiki/index.md). Cross-link when a wiki page forces a choice.

## How to use

- One decision per note. `ADR-0001 …`, `ADR-0002 …`.
- Copy [ADR Template](_resources/templates/investigation-project/decisions/ADR%20Template.md), fill it, add a row below.
- Durable reasoning, not a play-by-play.
- Cross-link related ADRs and wiki pages with Markdown links (spaces as `%20`).
- Status: `Proposed` · `Accepted` · `Superseded by [ADR-…](…)` · `Deprecated` · `Rejected`.

## Register

| ADR | Title | Area | Status | Date |
| --- | ----- | ---- | ------ | ---- |
| [ADR-0001](ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md) | Acknowledged Sidecar Cache Purge | sidecar / keyvault | Superseded by [ADR-0003](ADR-0003%20Shared%20Redis%20Forget%20Set.md) | 2026-09-02 |
| [ADR-0002](ADR-0002%20Forget%20Table%20Before%20Cache.md) | Forget Table Before Cache | sidecar / keyvault | Superseded by [ADR-0003](ADR-0003%20Shared%20Redis%20Forget%20Set.md) | 2026-09-03 |
| [ADR-0003](ADR-0003%20Shared%20Redis%20Forget%20Set.md) | Shared Redis Forget Set | sidecar / keyvault | Accepted | 2026-09-03 |
| [ADR-0004](ADR-0004%20Erasure%20Ledger%20as%20Lifecycle%20Event%20Log.md) | Erasure Ledger as Lifecycle Event Log | sidecar / record store | Proposed | 2026-09-08 |

## Related

- [Project README](../README.md)
- [Wiki](../wiki/index.md)
