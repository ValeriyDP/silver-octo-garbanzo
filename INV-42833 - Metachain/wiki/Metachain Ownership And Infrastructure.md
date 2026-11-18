---
name: Metachain Ownership And Infrastructure
date: 2026-10-02T12:05:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
  - architecture
---

# Metachain Ownership And Infrastructure

**Summary**: `metachain-service` owns the Inveniam event-hash ledger. Postgres holds the full event plus checksum; Immudb holds `{eventId, hash}`. QLDB is legacy; Accumulate is an optional org-scoped batch path. NVNM is a different product path owned by `hub-service`.

**Sources**: `apps/metachain-service`, `helm/configs/metachain.yaml`, `docker-compose.yml` (service `inv-metachain-ms`)

**Last updated**: 2026-10-02

---

## Owner

`apps/metachain-service` — NestJS microservice `metachain` (`IOMicroservices.metachain`). Helm release `inv-metachain`. Local container `inv-metachain-ms` on port `8897`, URL prefix `metachain`. (source: docker-compose.yml, helm/configs/metachain.yaml)

**What it does**

- Consumes almost all platform `BaseEvent`s from the message broker.
- SHA-256 hashes each event, stores the row in Postgres `invmetachain.transactions`.
- Anchors `{eventId, hash}` in Immudb (live path).
- Builds deal-log views for the UI.
- Optional document-taxonomy sync to Immudb/QLDB (`MetaChainDocumentSyncingRequestedEvent`).
- HTTP: event hash/transaction lookup, deal logs, connection profiles, wallets, org options, sync-document.

It does **not** write to NVNM Chain. NVNM document anchoring is `hub-service` + the external Hub app. (source: nvnm-payload-codec.service.ts; metachain-service has no NVNM provider)

## Bootstrap

`main.ts` creates the Nest app, starts HTTP listen, then `ImmudbMigration` (create Immudb database if missing), then CQRS consumers via `NestAwsCqrsModule`. (source: apps/metachain-service/src/main.ts)

`AppModule` wires: `NestAwsCqrsModule`, `DatabaseModule`, `InveniamEventsModule`, `DealLogsModule`, `ConnectionProfileModule`, `WalletsModule`, `OrganisationOptionsModule`, `CronModule`, `MetachainSyncDocumentModule`. (source: app.module.ts)

## Infrastructure

| Layer | Store | Contents |
| ----- | ----- | -------- |
| Source events | RabbitMQ (dev) / SNS→SQS (AWS) / Azure Service Bus | Full `IBrokerMessage` domain events; routing via `EventToMSMap` when `'metachain'` is listed |
| Event audit row | Postgres `invmetachain.transactions` | Full `eventData` JSONB + sha256 checksum + ledger pointers |
| Anchored hash (live) | Immudb `invimmudb` | Dual keys: `eventId` → `{eventId, hash, key}`, generated key → `{eventId, hash}` |
| Deal log view | Postgres `deal_logs` | Presentation + event payload |
| Document sync view | Postgres `metachain_sync_document_transactions` | Status + ledger pointer |
| Permissions cache | Redis | Not the ledger |
| Org wallet / connection secrets | Vault (`metachain/connections/…`, `metachain/wallets/…`) | Accumulate / legacy ledger creds |

**Ledger types in code** (`McLedgerTypeEnum`): `IMMUDB`, `QLDB`, `ACCUMULATE`. (source: shared-modules/Events/Metachain/interfaces.ts)

- **Immudb** — live event-hash write (`createMetachainReference` always calls `getImmuDBProvider()`). Dev compose: `inv-immudb` + `inv-immudb-auditor`.
- **QLDB** — legacy “Metachain” document ledger. Frontend `ProviderTypeEnum.metachain` still maps to `'QLDB'`. Helm comment: TF used QLDB; compose defaults `SYNC_DOCUMENT_DEFAULT_LEDGER_TYPE=IMMUDB`.
- **Accumulate** — org-scoped batch hash store via `LEDGER_RPC_ENDPOINT` / `LEDGER_CHAIN_ID`. Batch cron `@Interval` is **commented out**.

## How other services reach it

| Direction | Mechanism |
| --------- | --------- |
| In (events) | Broker fan-out. Any MS that publishes a `BaseEvent` whose `EventToMSMap` includes `'metachain'` |
| Out (reads) | HTTP. data-room file-veracity calls `GET /metachain/inveniam-events/:eventId/transaction` |
| Hub document sync (non-NVNM) | `hub-service` `MetachainLedgerProvider` for QLDB-style taxonomy write |
| UI | Frontend deal-logs route; websockets-service user-visible metachain messages |

## Naming trap

“Metachain” in older Hub/frontend code often means **QLDB**. “Inv Metachain” / `metachainv2` means this service + Immudb. Deal create auto-connects Inv Metachain **integration settings** in deals-service Postgres — that does not start the microservice. (source: connect-inv-metachain-command.ts, deal-integration-events.sagas.ts)

## Related pages

- [Investigation Brief](Investigation%20Brief.md)
- [Metachain Write Path](Metachain%20Write%20Path.md)
- [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md)
- [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md)
- [Wiki Index](Metachain%20(INV-42833)/wiki/index.md)
