---
name: Metachain Write Path
date: 2026-10-02T12:05:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
  - how-to
---

# Metachain Write Path

**Summary**: The microservice starts with compose/Helm. Hashing starts on the first consumed `BaseEvent` that has `meta.eventId` and is not in `EventsToExclude`. Producers are the other microservices; they do not call metachain to write. Deal-create “connect Inv Metachain” only writes integration settings.

**Sources**: `inveniam-event.saga.ts`, `process-inveniam-event.command.ts`, `transaction.model.ts`, `immudb-provider.ts`, `EventsConstants.ts`, `deal-integration-events.sagas.ts`

**Last updated**: 2026-10-02

---

## Who starts the process

Two different “starts”:

| What starts | Who | When |
| ----------- | --- | ---- |
| The microservice process | Compose (`inv-metachain-ms`) or Helm (`inv-metachain`) | After Postgres + broker (+ Immudb locally) are up. `npm run start:dev` / container listen on 8897 |
| The first ledger write | Any producer MS, indirectly | First domain event with `meta.eventId` that passes `EVENTS_TO_LISTEN` |

There is no per-org or per-deal worker. Org create (`OrganisationCreatedEvent`) only seeds a deal-logs org view. Deal create (`DealCreatedEvent`) both (a) is itself hashed if routed to metachain and (b) triggers `ConnectInvMetachainCommand` in **deals-service** — that is deal integration settings, not starting metachain-service. (source: deal-integration-events.sagas.ts, organisation-created.event.handler.ts)

Batch blockchain store (`BatchStoreEventsService.publishBatchEventHashStore`) has `@Interval` **commented out**. Batch only runs if something publishes `McBatchStoreEventHashInBlockchainEvent`. (source: batch-store-events.service.ts)

## Who publishes into Metachain

Mechanism: producer MS applies a domain event → broker → `EventToMSMap[eventName]` includes `'metachain'` → metachain event-handler queue.

`EVENTS_TO_LISTEN` is almost every `@inveniam/events` `BaseEvent` minus `EventsToExclude` (email/notification noise, some finished/failed workflow events, template heroes, etc.). Then the saga requires `event.meta.eventId`. (source: events-provider.ts, inveniam-event.saga.ts)

High-volume producers (not exhaustive; `EventsConstants.ts` has hundreds of `'metachain'` map entries):

| Producer | Example trigger | Event examples |
| -------- | --------------- | -------------- |
| data-room-service | File/folder lifecycle, checksum, taxonomy | `FDRFileCreatedEvent`, `DataRoomFileDownloadedEvent`, `MetaChainDocumentSyncingRequestedEvent` |
| deals-service | Deal create/update, members, integration | `DealCreatedEvent` |
| iam-service | Org / user provisioning | `OrganisationCreatedEvent` |
| hub-service | Symbol register, document sync status | Hub symbol / sync events |
| tasks / workflows / ai / notification / organisation | Lifecycle | Routed when `EventToMSMap` lists `metachain` |

Metachain also publishes its own follow-up events (`McInveniamEventHashWrittenEvent`, `McInveniamEventHashWriteFailedEvent`) which feed deal-logs.

## Live write pipeline (event hash)

1. Broker delivers `BaseEvent` to metachain.
2. `InveniamEventSaga.handleInveniamEvent` → `ProcessInveniamEventCommand`.
3. `TransactionModel.save`: SHA-256 of `JSON.stringify(event)` (`Sha256HashProvider`). Builds a `transactions` row: `eventId`, full `eventData`, `checksum`, `checksumAlgo: 'sha256'`, `organisationId`, aggregate meta, empty ledger pointers.
4. Insert Postgres (unique on `eventId`). Duplicate + same checksum + existing pointer → ignore. Duplicate + same checksum + missing pointer → repair Immudb write. Different checksum → security log, reject.
5. `createMetachainReference()` → **always Immudb** (`getImmuDBProvider()`), not the org Accumulate profile.
6. `storeEventHashV2(eventId, checksum)`: write-once gate; then one Immudb transaction with two keys (see [Payload Comparison](Payload%20Comparison%20Metachain%20vs%20NVNM.md)).
7. After 5s delay, `McInveniamEventHashWrittenEvent` → deal-log saga.

## Other write paths (same service, different payload)

| Path | Trigger | What is stored |
| ---- | ------- | -------------- |
| Document sync | `MetaChainDocumentSyncingRequestedEvent` (data-room when Hub is **not** the target) | Full `documentTaxonomy` JSON in Immudb/QLDB via `ledgerProvider.write` |
| Batch hash | `McBatchStoreEventHashInBlockchainEvent` | Many `{eventId, hash}` pairs via `storeBatchEventHash`; pointer goes to `blockchainRecordReference` |

## Related pages

- [Metachain Ownership And Infrastructure](Metachain%20Ownership%20And%20Infrastructure.md)
- [Event Hash vs File Taxonomy](Event%20Hash%20vs%20File%20Taxonomy.md)
- [How File Shows As Synced](How%20File%20Shows%20As%20Synced.md) — document-sync badge (separate from this hash path)
- [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md)
- [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md)
- [Open Questions](INV-42833%20-%20Metachain/wiki/Open%20Questions.md)
