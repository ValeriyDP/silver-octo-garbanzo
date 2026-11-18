---
name: Measurabl DLT Transaction
date: 2026-09-15T16:00:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# Measurabl DLT Transaction

**Summary**: Working picture (not an ADR) for one provision event, `MeasurablDLTTransaction`, slimmed from `HubDocumentSyncingRequestedEvent`. The file identity we need is `taxonomyId`. Portfolio is not on the event and is not used on this path. Register-if-needed + `addRecord`. Job state on existing `transactions`.

**Sources**: Prior INV-42559 thread; `shared-modules/Events/Hub/interfaces.ts`; `shared-modules/Events/DataRoom/Interfaces/data-room.interfaces.ts`; `hub-service/src/transactions/domain/entities/transactions.entity.ts`; `transactions.model.ts` `documentSyncingEventPublisher`; [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md).

**Last updated**: 2026-09-15

---

This page is the **current working model**. Forks that still need a choice are in [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md). Do not treat the event name or emit shape as locked.

## Goal

Client provision sends one event. Hub-service must **establish everything needed for a sync**, then sync:

1. Register a symbol if the deal has none.
2. `addRecord` the document.

Those two steps run from **one consumed event**: `MeasurablDLTTransaction`, a slim of `HubDocumentSyncingRequestedEvent`.

The initial question was “what extra values do we need so IO can mark the file synced?” **Taxonomy, not portfolio.** `taxonomyId` is the data-room PK. Feedback keys on it. Portfolio is not required to Register or `addRecord`.

## Event in (`MeasurablDLTTransaction`)

Same job as `HubDocumentSyncingRequestedEvent`. New name. Aggregate id = `taxonomyId`.

```
dealId
taxonomyId
organisationId
uri              // url
checksum         // hash
checksumAlgo
```

**Not on the event — resolved locally:**

| Field | Source |
| --- | --- |
| `symbol` / `registry` | `deal_anchors.registry` after Register |

**Not needed on this path:** `portfolioId` / `parentPortfolioIds`. Do not load them for this event.

**Omitted** (on `HubDocumentSyncingRequestedEvent` today, dropped here):

- `ledgerType` — inbound unused. Measurabl is NVNM-only; hub sets `NVNM` on the write.
- `fileId` — not used for NVNM `addRecord` fields; not on `transactions`; not on succeeded/failed. Data-room already has it on the taxonomy row.
- `transactionType` — inbound unused. Hub sets `Register` / `Sync-Document` itself when it encodes those writes.
- `userId`
- `estimation`
- `symbol`
- `portfolioId`
- `documentTaxonomy.dealName`
- `documentTaxonomy.document`
- `documentTaxonomy.location`
- `documentTaxonomy.individualId`

`isSyncNeeded` — not decided. See [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md) #7.

## What hub-service establishes, in order

From that one event. Each step is skip-if-already-there.

| Step | If missing | Source |
| --- | --- | --- |
| 1. Hub org + HubKeys | login, create org/keys once | Vault by `organisationId` — not on the event |
| 2. `deal_anchors` row | needed for `registry` only, not portfolio | load by `dealId` |
| 3. Registry (`symbol`) | `addRegistry`, save `deal_anchors.registry` | empty `registry` on the row |
| 4. `addRecord` | `checksum` / `uri` from the event | event + `deal_anchors.registry` |

`deal_anchors` is the registry lookup. Portfolio on that row is unused here. If the row is missing, Register has nowhere to save `registry`. See [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md) #6.

## Job state: existing `transactions` table

Do **not** invent a second job table. Persist the provision work on `transactions` so async Hub completion still has enough to emit feedback.

Insert (working shape):

| Column today | Value |
| --- | --- |
| `type` | `TransactionTypeEnum.SyncDocument` (`Sync-Document`) |
| `ledger` | `HubLedgerTypeEnum.NVNM` |
| `status` | `DLTOperationStatuses.Pending` |
| `dealId` | event |
| `organisationId` | event |
| `docuri` | event `uri` |
| `taxonomyId` | event `taxonomyId` |

`onComplete` is async. It will not remember the consumed event. Today `documentSyncingEventPublisher` reads `taxonomyId`, `organisationId`, and `transactionId` off the row and emits `HubDocumentSyncingSucceededEvent` / `Failed` / `Pending`. That path works again if `taxonomyId` is stored at insert.

## Event out (feedback to data-room)

IO taxonomy **is** our concern. After Hub finishes, emit that the file is on chain (or that it failed).

### What exists today

`HubDocumentSyncingSucceededEventPayload` = `BaseHubInterface` + `DLTResponseInterface`:

- `ledgerType`, `transactionType`
- `taxonomyId` (**required on the type**)
- `transactionPointer`
- `status`
- `reason`
- `organisationId?`, `userId?`

Data-room updates taxonomy from that event via `UpdateDataRoomFileTaxonomyCommand`. The request path stored `taxonomyId` on the `transactions` row first.

### What this event enables

Inbound `taxonomyId` can be copied onto `transactions` and echoed on the existing succeeded/failed events. Data-room already updates taxonomy from `HubDocumentSyncingSucceededEvent` via `UpdateDataRoomFileTaxonomyCommand`. See [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md) #3 if we still want a separate emit.

## Relation to the projector page

[Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md) is the **local read model** and the intended Hub HTTP sequences (login → org/keys → `addRegistry` → `grantRole` → `addRecord`).

This page is the **one-shot trigger**: provision event drives those Hub steps and the `transactions` feedback path.

| Concern | Where it lives |
| --- | --- |
| Deal identity + `registry` | `deal_anchors` |
| File hash / URL | event `uri` / `checksum` |
| Hub org / HubKeys | Vault / Hub, not `deal_anchors` |
| Taxonomy id | on the event (data-room PK); copied onto `transactions` |

## Related pages

- [Wiki Index](INV-42559%20-%20Measurabl%20provision/wiki/index.md)
- [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md)
- [Event Payloads](Event%20Payloads.md)
- [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md)
- [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md)
- [Decision register](../decisions/INDEX.md)
