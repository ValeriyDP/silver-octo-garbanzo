---
name: ADR-0009 One In Flight Per Signing Wallet
date: 2026-11-11T17:45:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0009 One In Flight Per Signing Wallet

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Proposed)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Supersedes**: [ADR-0008 One In Flight Per Organisation](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md)
- **Related**: [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md), [ADR-0002 Portfolio Identity Queue](ADR-0002%20Portfolio%20Identity%20Queue.md), [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

## Context

THE HUB queues ledger writes per signing wallet and processes them one by one. Hub sends `POST /ledgers/write` (v1) or `POST /ledgers/v3/write` (v3, returns a job id polled at `GET /ledgers/v3/jobs/:id`), chosen by `HUB_WRITE_API_VERSION`. A 503 from the write is surfaced as `Hub wallet transaction queue is full` (source: `apps/hub-service/src/tokenization/hub-tokenization.provider.ts`, `apps/hub-service/src/config/environment.ts`).

The signing wallet differs by kind of organisation:

- **Regular organisation**: signs with HubKeys at organisation level. One wallet per organisation.
- **Known organisation** (Measurabl-like): signs with an Identity wallet per portfolio on THE HUB side, user `{portfolioId}@measurabl.com` (source: `apps/hub-service/src/organisation-provisioning/domain/measurabl-identity.ts`, `measurabl-tx-payload.ts`).

For NVNM, `LedgerFactoryProvider.resolveHubCredentials` climbs deal → portfolio → organisation using `dealAnchor.rootPortfolioId()` (source: `apps/hub-service/src/transactions/application/providers/ledger-factory.provider.ts`, `nvnm-scoped-candidates.ts`). `rootPortfolioId()` is `resolveProvisioningPortfolioId` (source: `apps/hub-service/src/deal-anchoring/domain/models/deal-anchor.model.ts`), the same function `EnsureHubIdentityStep` uses for the Identity email. The portfolio that names the Identity is the portfolio whose credentials sign.

[ADR-0008](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md) serialised a known organisation as a whole. That waits on files that go to different THE HUB wallet queues.

Hub-side preparation that is shared across portfolios of one organisation is already serialised by `OrganisationProvisioningLock`: the parent wallet nonce for Identity top-ups and the identity HD counter (source: `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`).

## Decision

One `in_flight` row per **signing wallet**. Each source adapter ([ADR-0007](ADR-0007%20Pluggable%20Bucket%20Sources.md)) supplies the key of the wallet it signs with:

| Source | Signing wallet | `queue_key` |
| --- | --- | --- |
| `client_dlt` | Portfolio Identity wallet | `identity:{portfolioId}`, `portfolioId = resolveProvisioningPortfolioId(deal_anchors row for dealId)` |
| `regular` (stub) | Organisation HubKeys wallet | `org:{organisationId}` |

The prefix keeps the two key spaces apart. FIFO among `waiting` rows of one key. Different portfolios and different organisations run in parallel.

`client_dlt` intake reads `deal_anchors` for `dealId`. No row, or no portfolio resolved: log and stop. No bucket row, no chain, THE HUB is not called. This is checked after the `io_hub_organisation_map` guard.

`OrganisationProvisioningLock` stays as is. It covers the organisation-wide spots inside the chain; the bucket covers the whole file per wallet.

## Alternatives considered

- **One in-flight file per organisation** ([ADR-0008](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md)). Correct for regular organisations. For a known organisation it serialises portfolios whose writes go to separate THE HUB wallet queues.
- **One in-flight file per deal.** Two deals of one portfolio sign with the same Identity wallet and would overlap in THE HUB's queue for it.
- **One global queue.** Unrelated wallets wait on each other.
- **Key by the credentials path that matched (deal, portfolio, or organisation).** That path decides the API credentials. The wallet that signs a `client_dlt` write is chosen by the Identity user email, which is per portfolio.

## Consequences

- **Positive**: Hub never has two files in one THE HUB wallet queue. Three or more simultaneous streams spread over their own wallets. The key matches the signer by construction, through the same resolver.
- **Negative / trade-offs**: `client_dlt` intake reads `deal_anchors` before any chain step. A file whose deal projection has not arrived is refused at intake and is not a bucket row. Portfolios of one organisation still meet on `OrganisationProvisioningLock`; many portfolios streaming at once can still hit its 150 s wait.
- **Follow-ups / open threads**: Whether a 503 queue-full should stay `sync_failed` ([Open Questions](../wiki/Open%20Questions.md) #6). Which wallet signs a manual UI sync on a known organisation (#3).

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | `queue_key` from the source adapter |
| `apps/hub-service/src/deal-anchoring/domain/resolve-provisioning-portfolio-id.ts` | Called by `client_dlt` intake. Unchanged |
| `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts` | Unchanged |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [ADR-0007 Pluggable Bucket Sources](ADR-0007%20Pluggable%20Bucket%20Sources.md)
- [ADR-0008 One In Flight Per Organisation](ADR-0008%20One%20In%20Flight%20Per%20Organisation.md)
- [ADR-0002 Portfolio Identity Queue](ADR-0002%20Portfolio%20Identity%20Queue.md)
- [ADR-0005 Unmarked In Flight Holds](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
