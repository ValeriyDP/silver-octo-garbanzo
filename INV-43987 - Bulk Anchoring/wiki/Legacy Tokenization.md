---
name: Legacy Tokenization
date: 2026-11-23T19:30:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - wiki
  - reference
---

# Legacy Tokenization

> [!info] Reference
> Everything on this page is out of the code review. It is frozen: no cleanup, no failure-handling changes, no tests added for it.

**Summary**: IO Hub Service has two historic actions. Tokenization mints a token on a chain and then moves it (register a symbol, deploy a token, change total supply, distribute tokens, set tokens relation). Document sync anchors a file checksum. Current work targets the NVNM chain and document anchoring only. The NVNM payload codec encodes four transaction types, and any other type throws `NotImplementedException`, so the token flows cannot produce an NVNM write. Register is the one shared step: on NVNM it calls `addRegistry` and belongs to anchoring.

**Sources**: `apps/hub-service/src/transactions/application/services/codec/nvnm/nvnm-payload-codec.service.ts`, `apps/hub-service/src/transactions/application/providers/ledger-factory.provider.ts`, `apps/hub-service/src/transactions/application/providers/tokenization/nvnm/nvnm-ledger.provider.ts`, `apps/hub-service/src/transactions/domain/sagas/transactions.sagas.ts`, `apps/hub-service/src/transactions/domain/commands/`, `apps/hub-service/src/transactions/domain/models/transactions.model.ts`, `apps/hub-service/src/transactions/application/providers/ledger-io.provider.ts`, `apps/deals-service/src/core/integration-settings/application/controllers/integration-settings.controller.ts`, `apps/deals-service/src/core/integration-settings/domain/models/deal-integration-settings.model.ts`, `apps/deals-service/src/core/integration-settings/domain/commands/process-tokenization-bootstrap-item.command.ts`, `apps/deals-service/src/core/integration-settings/domain/commands/advance-tokenization-bootstrap-job.command.ts`, `apps/deals-service/src/core/integration-settings/application/services/event-factory-providers/Hub/hub-events-factory.ts`.

**Last updated**: 2026-11-23

---

## What stays in scope

NVNM document anchoring. The NVNM codec encodes these transaction types (source: `nvnm-payload-codec.service.ts`, `encode`):

| Transaction type | NVNM encoding | Role |
| --- | --- | --- |
| `Register` | `encodeRegisterSymbol`: `addRegistry(dealId, dealId, '')` | Creates the deal registry. Anchoring needs it. |
| `SyncDocument` | `encodeSetDocument` | Anchors the file checksum. |
| `GetDocument` | `encodeGetDocument` | Reads an anchored document. |
| `GetTokenDetails` | `encodeGetTokenDetails` | Read. Not classified as legacy. |

## What is legacy

The token lifecycle. Each flow is a public event, a saga in `TransactionsSagas`, a command, a `TransactionsModel` method, and a Failed event.

| Flow | Hub command | Model method | Sender found in this repository |
| --- | --- | --- | --- |
| Deploy token | `DeployTokenCommand` | `deployToken` | `deals-service` integration settings: the deploy-token endpoint, `DealIntegrationSettingsModel`, and the tokenization bootstrap job commands |
| Change total supply | `ChangeTotalSupplyCommand` | `changeTotalSupply` | `deals-service` integration settings: the change-total-supply endpoint and `DealIntegrationSettingsModel` |
| Distribute tokens | `DistributeTokensCommand` | `distributeTokens` | `deals-service` integration settings: the distribute-tokens endpoint and `DealIntegrationSettingsModel` |
| Set tokens relation | `SetTokensRelationCommand` | `setTokensRelation` | None. No non-test `new HubSetTokensRelationRequestedEvent(` call exists. |

These are still reachable: `deals-service` can emit the request events. On NVNM they end in a Failed event, because the NVNM codec throws for deploy, supply, distribution, and relation.

Register is shared. For every chain except NVNM it registers a symbol. For NVNM it is `addRegistry`. Register stays in the review scope for NVNM only.

## Other chains

`LedgerFactoryProvider` maps these ledger types to a provider (source: `ledger-factory.provider.ts`): `ETH`, `HLF`, `TEZ`, `QUORUM`, `QLDB`, `AVALANCHE`, `POLYGON`, `BSC`, `ACCUMULATE`, `BASE`, `PROVENANCE`, `HEDERA_HASHGRAPH`, `MANTRA`, `NVNM`. Every one except `NVNM` is legacy for this review. Their providers live under `transactions/application/providers/tokenization/` and `data-validation/`.

## Known behaviour, recorded and not fixed

`LedgerIOProvider.write` rethrows a `Retryable` error before it inserts a Failed transaction row. That applies to every caller of `write`, legacy flows included. On a THE HUB outage the model catch of `deployToken`, `changeTotalSupply`, `distributeTokens`, and `setTokensRelation` publishes its Failed event and no Failed row exists. Before the retry change those flows inserted the row and published the event.

The same gap applies to Register, which is in scope. It is recorded on the review plan, not here.

## Related pages

- [Code Review Plan](Code%20Review%20Plan.md)
- [SQS FIFO Approach](SQS%20FIFO%20Approach.md)
- [Wiki Index](index.md)
