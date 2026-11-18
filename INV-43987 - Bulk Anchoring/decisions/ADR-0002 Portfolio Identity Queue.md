---
name: ADR-0002 Portfolio Identity Queue
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0002 Portfolio Identity Queue

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: Superseded by [ADR-0008 One In Flight Per Organisation](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md), [ADR-0008 One In Flight Per Organisation](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

> Superseded. THE HUB serves one request at a time per organisation, so the queue key is `organisationId` ([ADR-0008](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md)). Sources are adapters on one core instead of `identity` / `organisation` strategies ([ADR-0007](ADR-0007%20Pluggable%20Bucket%20Sources.md)). Kept for the record.
>
> Later: [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md) supersedes ADR-0008. THE HUB queues writes per signing wallet, so `client_dlt` is again keyed by portfolio Identity, this time as a source adapter key (`identity:{portfolioId}`).

## Context

The bucket needs a queue boundary: which files must wait for each other. `ClientDLTTransactionPayload` has `dealId` and `organisationId` and no portfolio id (source: `shared-modules/Events/Hub/Onboarding/client-dlt-transaction.event.ts`).

The Identity the chain signs with is `measurablIdentityEmail(portfolioId)` (source: `apps/hub-service/src/organisation-provisioning/domain/measurabl-identity.ts`). The portfolio id comes from `resolveProvisioningPortfolioId`: `portfolioId` when `parentPortfolioIds` is empty, otherwise `parentPortfolioIds[0]` (source: `apps/hub-service/src/deal-anchoring/domain/resolve-provisioning-portfolio-id.ts`). `EnsureHubIdentityStep` already uses that function.

Later bulk anchoring and autosync are expected to share one in-flight file per organisation. That intake is not this slice. The code has to be ready to add it without rewriting the bucket.

## Decision

For `ClientDLTTransaction`, `queue_scope = 'identity'` and `queue_key` is the portfolio id from `resolveProvisioningPortfolioId`. One `in_flight` row per that key. FIFO by `received_at` among `waiting` rows of that key. Other portfolio keys run in parallel.

`queue_scope = 'organisation'` is a legal value on the column. No intake writes it in this slice. The key resolver is a strategy: identity is called, organisation is present and unwired. When regular anchoring joins, its key is `organisationId` and its queue is one in-flight file per organisation.

If `resolveProvisioningPortfolioId` returns nothing: do not insert, do not start `RunPortfolioProvisioningCommand`, log and stop. Today's chain would fail later inside `EnsureHubIdentityStep` with `portfolioId is missing for identity email`. This slice stops at intake instead, and still does not call THE HUB.

## Alternatives considered

- **One in-flight file per organisation for Measurabl now.** Rejected for this slice. Measurabl concurrency is per portfolio Identity. Organisation is the later anchoring boundary.
- **One in-flight file per deal.** Files on two deals that share a portfolio Identity would run together. The Identity is the shared signer.
- **One global queue.** Unrelated portfolios would wait on each other.
- **Start the existing chain when the portfolio is missing, so the current exception still fires.** Rejected. The event cannot be placed on an identity queue, and the chain must not start.

## Consequences

- **Positive**: Files that share an Identity are serial. Files that do not share one still run together. The organisation strategy can be switched on later by a new intake.
- **Negative / trade-offs**: Intake reads `deal_anchors` before any chain step. A missing deal projection never becomes a bucket row, so it will not show up in a "not synced" query of this table.
- **Follow-ups / open threads**: Wiring `HubDocumentSyncingRequestedEvent` to the organisation strategy.

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | `queue_scope`, `queue_key`, identity resolver, unused organisation resolver |
| `apps/hub-service/src/deal-anchoring/domain/resolve-provisioning-portfolio-id.ts` | Called at intake. The function itself stays |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [Anchoring Bucket Diagrams](../wiki/Anchoring%20Bucket%20Diagrams.md)
- [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md)
