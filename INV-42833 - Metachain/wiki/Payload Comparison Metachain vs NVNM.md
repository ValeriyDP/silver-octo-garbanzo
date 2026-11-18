---
name: Payload Comparison Metachain vs NVNM
date: 2026-10-02T12:05:00.000Z
tags:
  - metachain
  - inv-42833
  - nvnm
  - wiki
---

# Payload Comparison Metachain vs NVNM

**Summary**: Metachain anchors a SHA-256 of a **platform domain event**. NVNM (and other EVM-like Hub ledgers) anchors a **document taxonomy fingerprint** via `addRecord` / `setDocument`. Same word “anchor”; different object, trigger, and chain.

**Sources**: `immudb-provider.ts`, `transaction.entity.ts`, `sha256-hash-provider.ts`, `nvnm-payload-codec.service.ts`, `data-room.interfaces.ts`, `ledger-io.provider.ts`

**Last updated**: 2026-10-02

---

## Conceptual difference

| | Metachain live path | NVNM / EVM-like (Hub) |
| - | ------------------- | --------------------- |
| Owner | `metachain-service` | `hub-service` encodes; external Hub app broadcasts |
| What is proven | Integrity of an Inveniam **domain event** | Integrity of a **file taxonomy** (checksum + metadata) |
| Granularity | One write per platform event (file moved, downloaded, deal created, …) | One write per user/system **document sync**; plus one `addRegistry` per deal |
| Trigger | Automatic, broker-driven | On-demand DLT sync after checksum verification; registry must exist |
| Chain | Immudb (append-only KV). Not EVM | NVNM precompile (`InveniamToken`). Same Hub envelope as Ethereum/Polygon/Base |
| Explorer | Immudb tx / generated key | `{explorer}/tx/{transactionHash}` |

NVNM `symbol` is the on-chain **registry id**, not a token ticker. Other EVM ledgers use `setDocument` with a newline-delimited string and a per-deal token contract. For this investigation the Ethereum-like shape is close enough: Hub envelope + ABI calldata. (source: nvnm-payload-codec.service.ts; HOW-TO Enable DLT Validation (NVNM) in Hub Keys Everywhere)

## What Metachain stores

### Hash input

```text
sha256(JSON.stringify(BaseEvent))  → hex
```

(source: sha256-hash-provider.ts)

The **full event** is kept in Postgres, not on Immudb.

### Postgres `transactions` row

| Field | Role |
| ----- | ---- |
| `id` | UUID of the audit row |
| `eventId` | `event.meta.eventId` |
| `eventName` | constructor name |
| `eventData` | full `BaseEvent` JSONB |
| `checksum` / `checksumAlgo` | sha256 / `'sha256'` |
| `organisationId`, `aggregateId`, `aggregateType`, `version` | from event meta/context |
| `ledgerType` | from `SYNC_DOCUMENT_DEFAULT_LEDGER_TYPE` (row label; live write still Immudb) |
| `metachainRecordReference` | `{ transactionId, key }` — Immudb generated key + `eventId` |
| `blockchainRecordReference` | `{ transactionId, entryHash }` — used by batch / Accumulate |
| `status` | Pending / Succeed / Failed / … |

(source: transaction.entity.ts, transaction.model.ts)

### Immudb values (the “anchored payload”)

Live `storeEventHashV2` writes two keys in one transaction:

```json
// key = eventId
{ "eventId": "<uuid>", "hash": "<sha256 hex>", "key": "<generated>" }

// key = generated = `${timestamp}_sha256_${hash(data)}`
{ "eventId": "<uuid>", "hash": "<sha256 hex>" }
```

Returned `transactionId` is the **generated key**, not an EVM tx hash. (source: immudb-provider.ts)

Batch `storeBatchEventHash` writes only `{ eventId, hash }` under key `eventId`.

### Follow-up domain event

`McInveniamEventHashWrittenEvent`: `{ event, eventType, eventHash }`. (source: Metachain/interfaces.ts)

## What NVNM stores

Prerequisite: `addRegistry(dealId, dealId, '')` → receipt log → `registryId` stored as deal `config.symbol`.

### Hub HTTP envelope (NVNM and other EVM ledgers)

```json
{
  "userEmail": "<string>",
  "tx": "<base64 of inner object>",
  "extraData": "{ deal_id, deal_name, organization_id, organization_name }"
}
```

Inner EVM object: `{ contractAddress, txData (ABI hex), metaData (ABI json), estimation? }`. (source: nvnm-payload-codec.service.ts, ledger-io.provider.ts)

### `addRecord` tuple (decoded meaning of `txData`)

Built in `encodeSetDocument`:

| Field | Source |
| ----- | ------ |
| `uri` | `documentTaxonomy.uri` |
| `checksum` | `documentTaxonomy.checksum` |
| `checksumAlgo` | `documentTaxonomy.checksumAlgo` |
| `metadata` | `JSON.stringify({ taxonomyId, fileId, ...documentTaxonomy })` |
| `timestamp` | taxonomy timestamp or ISO now |
| `status` | `'Active'` |
| `recordId` | hardcoded `1` |
| `index` | hardcoded `0` |
| `isLatest` | `true` |
| `registryId` | deal `symbol` |

`TaxonomyInterface`: `dealName`, `document`, `uri`, `checksum`, `checksumAlgo`, `timestamp`, `location`, `individualId`. (source: data-room.interfaces.ts)

Other EVM-like Hub ledgers (ETH/Polygon/Base) use the same envelope; the inner call is `setDocument(processedDocumentData)` on a **deployed token**, not `addRecord` on the NVNM precompile. Shape differs; “hash of a file + metadata on an EVM chain” is the same class of write.

## Side-by-side

If we “put Metachain events onto NVNM”, we would be mapping an `{eventId, hash}` (or a full `BaseEvent`) onto something like `addRecord`. That is not a drop-in: NVNM records are **file/registry** shaped (`uri`, `checksum`, `registryId`), not **event-id** shaped. Options (not decided — see [Open Questions](INV-42833%20-%20Metachain/wiki/Open%20Questions.md)):

1. **Hash-only anchor**: one NVNM record whose `checksum` is the event sha256 and whose `metadata`/`uri` carry `eventId`. Metachain Postgres/Immudb stay.
2. **Write-through**: every Metachain event becomes an NVNM `addRecord` (volume + registry model problem).
3. **Batch / merkle**: many event hashes in one on-chain record (Metachain already batches into Immudb; NVNM codec has no merkle helper).

## Related pages

- [Metachain Write Path](Metachain%20Write%20Path.md)
- [Metachain Ownership And Infrastructure](Metachain%20Ownership%20And%20Infrastructure.md)
- [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md)
- [Open Questions](INV-42833%20-%20Metachain/wiki/Open%20Questions.md)
