---
name: ADR-0005 Unmarked In Flight Holds
date: 2026-11-11T15:00:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0005 Unmarked In Flight Holds

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Accepted)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation
- **Related**: [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [Open Questions](../wiki/Open%20Questions.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

> Since [ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md) the queue is per signing wallet: the portfolio Identity for `client_dlt`, the organisation for `regular`. "Portfolio" below is the `client_dlt` case. The decision is unchanged. The finish exits that do clear `in_flight` are listed in [ADR-0003](ADR-0003%20Keep%20Terminal%20Rows.md).

## Context

`in_flight` ends when `HubDocumentSyncingSucceededEvent` or `HubDocumentSyncingFailedEvent` matches `taxonomy_id`, or when the running command throws and the finish transaction writes `sync_failed`. A crash after the claim commits, or a document result that never arrives, leaves the row `in_flight`. That portfolio then has a running file, so the next `waiting` row is not claimed. See [ADR-0004](ADR-0004%20Atomic%20Finish%20and%20Claim.md).

## Decision

The row stays `in_flight` and holds that portfolio queue. There is no timeout and no reaper. A crash after claim and before `RunPortfolioProvisioningCommand` is the same shape.

The row is visible in `anchoring_bucket`. Nothing in this feature moves it.

## Alternatives considered

- **After a timeout, mark `sync_failed` and claim the next waiting file.** Rejected. A late document event could then meet a row that is no longer `in_flight`, and the next file would start while the first write might still be in flight at THE HUB.

## Consequences

- **Positive**: One portfolio cannot run two files because a timer fired.
- **Negative / trade-offs**: One unmarked row blocks that portfolio until someone deals with the row outside this feature. Other portfolios are unaffected.
- **Follow-ups / open threads**: None for this question. Closed.

## Affected code

Nothing is changed yet. The bucket must not add a timer or a sweeper.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | No timeout column and no reaper when the module is built |

## Related

- [Decision register](INDEX.md)
- [Open Questions](../wiki/Open%20Questions.md)
- [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
