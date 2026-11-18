---
name: ADR-0006 Read Failures In Postgres
date: 2026-11-11T15:00:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0006 Read Failures In Postgres

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Accepted)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation
- **Related**: [ADR-0003 Keep Terminal Rows](ADR-0003%20Keep%20Terminal%20Rows.md), [Open Questions](../wiki/Open%20Questions.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

## Context

Hub has no screen for this flow. `sync_failed` rows stay in `anchoring_bucket` with a reason so the files that did not sync can be found ([ADR-0003](ADR-0003%20Keep%20Terminal%20Rows.md)). An outbound event that listed those rows, for a later manual resync in the data room, was discussed and is not part of this feature.

## Decision

Out of scope. This feature does not emit a list of `sync_failed` files and does not add a hub API or a screen. A person connects to the hub Postgres database and reads `anchoring_bucket`.

`status = 'sync_failed'` is the failed set. The partial index `(received_at) WHERE status = 'sync_failed'` is there for that read. Rows that are not `sync_success` are the wider not-synced set (`waiting`, `in_flight`, and `sync_failed`).

## Alternatives considered

- **Hub emits an event listing `sync_failed` rows so someone can resync them by hand in the data room.** Rejected for this feature. The rows are already in Postgres.

## Consequences

- **Positive**: No new event, no data-room change, no hub UI.
- **Negative / trade-offs**: Finding a failed file is a database read, not a product screen.
- **Follow-ups / open threads**: None for this question. Closed.

## Affected code

Nothing is changed yet. No new event type.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | The `sync_failed` partial index from [ADR-0003](ADR-0003%20Keep%20Terminal%20Rows.md). No publisher. |

## Related

- [Decision register](INDEX.md)
- [Open Questions](../wiki/Open%20Questions.md)
- [ADR-0003 Keep Terminal Rows](ADR-0003%20Keep%20Terminal%20Rows.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
