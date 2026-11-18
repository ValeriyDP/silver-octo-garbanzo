---
name: Decision register
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - index
---

# Decision register — Bulk Anchoring (INV-43987)

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

Architecture Decision Records for this investigation. Each note is **context → decision → consequences**.

Knowledge (how it works, how-tos) lives in [wiki/index](../wiki/index.md). Cross-link when a wiki page forces a choice.

## How to use

- One decision per note. `ADR-0001 …`, `ADR-0002 …`.
- Copy [ADR Template](_resources/templates/investigation-project/decisions/ADR%20Template.md), fill it, add a row below.
- Durable reasoning, not a play-by-play.
- Cross-link related ADRs and wiki pages with Markdown links (spaces as `%20`).
- Status: `Proposed` · `Accepted` · `On hold` · `Superseded by [ADR-…](…)` · `Deprecated` · `Rejected`.

## Register

| ADR | Title | Area | Status | Date |
| --- | ----- | ---- | ------ | ---- |
| [ADR-0001](ADR-0001%20Hub%20Postgres%20Bucket.md) | Hub Postgres Bucket | hub-service | On hold (was Proposed) | 2026-11-11 |
| [ADR-0002](ADR-0002%20Portfolio%20Identity%20Queue.md) | Portfolio Identity Queue | hub-service | Superseded by [ADR-0008](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md) | 2026-11-11 |
| [ADR-0003](ADR-0003%20Keep%20Terminal%20Rows.md) | Keep Terminal Rows | hub-service | On hold (was Proposed) | 2026-11-11 |
| [ADR-0004](ADR-0004%20Atomic%20Finish%20and%20Claim.md) | Atomic Finish and Claim | hub-service | On hold (was Proposed) | 2026-11-11 |
| [ADR-0005](ADR-0005%20Unmarked%20In%20Flight%20Holds.md) | Unmarked In Flight Holds | hub-service | On hold (was Accepted) | 2026-11-11 |
| [ADR-0006](ADR-0006%20Read%20Failures%20In%20Postgres.md) | Read Failures In Postgres | hub-service | On hold (was Accepted) | 2026-11-11 |
| [ADR-0007](ADR-0007%20Pluggable%20Bucket%20Sources.md) | Pluggable Bucket Sources | hub-service | On hold (was Proposed) | 2026-11-11 |
| [ADR-0008](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md) | One In Flight Per Organisation | hub-service | Superseded by [ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md) | 2026-11-11 |
| [ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md) | One In Flight Per Signing Wallet | hub-service | On hold (was Proposed) | 2026-11-11 |
| [ADR-0010](ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md) | Hub Advisory Lock Scope Registry | hub-service | On hold (was Proposed) | 2026-11-12 |
| [ADR-0011](ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md) | FIFO Per-Wallet Chain Without Hold | hub-service | Accepted (active; interim serialiser) | 2026-11-16 |
| [ADR-0012](ADR-0012%20Durable%20Workflows%20Engine.md) | Durable Workflows Engine | hub-service | Proposed (active; blocked on upgrade) | 2026-11-16 |
| [ADR-0013](ADR-0013%20Hybrid%20Workflows%20Over%20Hub%20Queue.md) | Hybrid Workflows Over Hub Queue | hub-service | Proposed (active; target architecture) | 2026-11-16 |

ADR-0011, ADR-0012 and ADR-0013 belong to the **active** line, not the on-hold Postgres bucket (ADR-0001…ADR-0010). The direction: THE HUB owns nonce-safety (`wallet_tx_jobs`); ADR-0011 FIFO is the interim per-wallet serialiser on NestJS 8; ADR-0012 names durable workflows as the engine (blocked on a NestJS/cqrs upgrade); ADR-0013 is the hybrid that combines them. The on-hold banner above covers the bucket ADRs only.

## Related

- [Project README](../README.md)
- [Wiki](../wiki/index.md)
