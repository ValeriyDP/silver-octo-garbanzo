---
name: ADR-0008 One In Flight Per Organisation
date: 2026-11-11T15:10:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0008 One In Flight Per Organisation

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: Superseded by [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Supersedes**: [ADR-0002 Portfolio Identity Queue](ADR-0002%20Portfolio%20Identity%20Queue.md)
- **Related**: [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md), [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

> Superseded. THE HUB queues writes per signing wallet. Regular organisations sign with organisation-level HubKeys; known organisations sign with an Identity wallet per portfolio. The key follows the wallet ([ADR-0009](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)). Kept for the record.

## Context

THE HUB serves one request at a time per organisation. Each file needs preparation and blockchain calls before `addRecord`, and they must not overlap with another file of the same organisation.

Hub already serialises two organisation-scoped resources with a session-scoped Postgres advisory lock keyed by `organisationId`: the parent wallet nonce (`ParentWalletNonce`, used by `identity-wallet-top-up.ts`) and the identity HD counter (`IdentityHdLeaf`, used by `ensure-hub-identity-wallet.step.ts`). A waiter polls every 500 ms and throws `Timed out waiting for the organisation provisioning lock` after 150 s (source: `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`). A burst of files for one organisation queues chains on that lock; the late ones fail.

`ClientDLTTransactionPayload` carries `organisationId` (source: `shared-modules/Events/Hub/Onboarding/client-dlt-transaction.event.ts`). `HubDocumentSyncingRequestedEvent` carries it as well, so the future `regular` source has the same key.

[ADR-0002](ADR-0002%20Portfolio%20Identity%20Queue.md) keyed the queue by portfolio Identity. Two portfolios of one organisation would still call THE HUB at the same time.

## Decision

`queue_key = organisationId` for every source. One `in_flight` row per `queue_key`. FIFO among `waiting` rows of that key. Different organisations run in parallel.

Intake does not read `deal_anchors` to build the key. `resolveProvisioningPortfolioId` stays inside `EnsureHubIdentityStep` and is not called by the bucket.

The bucket lock does not replace `OrganisationProvisioningLock`. Those locks stay. With one file per organisation they are no longer contended by files of that organisation.

## Alternatives considered

- **One in-flight file per portfolio Identity** ([ADR-0002](ADR-0002%20Portfolio%20Identity%20Queue.md)). Two portfolios of one organisation reach THE HUB at once.
- **One global queue.** Unrelated organisations wait on each other.
- **Rely on `OrganisationProvisioningLock` only.** It covers two read-modify-write spots, not the whole file, and its waiters time out after 150 s.

## Consequences

- **Positive**: Matches THE HUB's one-request boundary. The key is on the payload, so intake makes no extra read for it. The same key works for the `regular` source.
- **Negative / trade-offs**: All portfolios of one organisation are serial. A busy organisation drains at THE HUB's pace for one file at a time. An unmarked `in_flight` row holds the whole organisation ([ADR-0005](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)).
- **Follow-ups / open threads**: None for the key.

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | `queue_key` from `organisationId` |
| `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts` | Unchanged |
| `apps/hub-service/src/deal-anchoring/domain/resolve-provisioning-portfolio-id.ts` | Not called by the bucket |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [ADR-0002 Portfolio Identity Queue](ADR-0002%20Portfolio%20Identity%20Queue.md)
- [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md)
- [ADR-0005 Unmarked In Flight Holds](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
