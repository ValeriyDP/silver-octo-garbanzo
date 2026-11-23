---
name: Code Review Plan
date: 2026-11-23T20:40:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - wiki
  - guide
---

# Code Review Plan

> [!info] Active
> Review of the code that is already running. This page lists what to delete, what to leave, and the one open design direction. Legacy tokenization is out of scope and described on its own page.

**Summary**: The review covers NVNM document anchoring: register (`addRegistry`), document sync, connect, and status polling. Tokenization (deploy, supply, distribution, token relations) and every non-NVNM ledger are legacy, are frozen, and live on [Legacy Tokenization](Legacy%20Tokenization.md). Three deletions are settled. One direction is set, with seven decisions settled and none open: a typed `HubConnectionOutageException` marks a failed THE HUB login, and register redelivers on an outage like document sync. It stays inside IO Hub Service. `HubTokenizationProvider` and `NestAwsCqrs` are not edited.

**Sources**: `apps/hub-service/src/sqs/retryable.ts`, `apps/hub-service/src/sqs/hub-unavailable.error.ts`, `apps/hub-service/src/sqs/install-hub-sqs-retry.ts`, `apps/hub-service/src/main.ts`, `apps/hub-service/src/tokenization/hub-tokenization.provider.ts`, `apps/hub-service/src/tokenization/smart-account-tokenization.provider.ts`, `apps/hub-service/src/transactions/domain/models/transactions.model.ts`, `apps/hub-service/src/transactions/domain/commands/sync-document.command.ts`, `apps/hub-service/src/transactions/domain/commands/register-symbol.command.ts`, `apps/hub-service/src/transactions/application/providers/ledger-io.provider.ts`, `apps/hub-service/src/transactions/application/providers/base-ledger.provider.ts`, `apps/hub-service/src/transactions/application/providers/tokenization/nvnm/nvnm-ledger.provider.ts`, `apps/hub-service/src/organisation-provisioning/domain/chain/shared/identity-wallet-underfunded.error.ts`, `apps/hub-service/src/organisation-provisioning/domain/anchoring-message-group.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/publish-hub-document-syncing-requested-internal.event.handler.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/publish-client-dlt-transaction-internal.event.handler.ts`, `shared-modules/NestAwsCqrs/src/NestAwsService.ts`.

**Last updated**: 2026-11-23

---

## Scope

IO Hub Service only, NVNM only. In scope:

- The regular start: `HubDocumentSyncingRequestedEvent`, its internal copy, and `SyncDocumentCommand`.
- Register: `HubSymbolRegisteringRequestedEvent`, `RegisterSymbolCommand`, and the NVNM `addRegistry` write.
- `connect()`, `getProfile()`, `setAccessKey()`, and `write()` on `HubTokenizationProvider`.
- The internal sends on `anchoring:org:` and `anchoring:identity:` groups.

Out of scope: legacy tokenization, every non-NVNM ledger provider, `SmartAccountTokenizationProvider` (it does not call THE HUB), THE HUB queue depth (`WALLET_TX_QUEUE_MAX_DEPTH`), and the local emit script.

The behaviour to preserve:

- A regular file is copied to `HubDocumentSyncingRequestedInternal` and sent on `anchoring:org:{organisationId}`, deduplicated by `taxonomyId`.
- `TransactionsSagas.syncDocument` listens only to that internal event.
- No HTTP response from THE HUB, and HTTP 503 on the write, leave the command message on the queue. No `HubDocumentSyncingFailedEvent`, no Failed transaction row.
- A credential rejection (HTTP 422 from `connect()`) and any other write error stay final.

## Delete

### Dead group check on the regular start

`PublishHubDocumentSyncingRequestedInternalHandler` already returns when `organisationId` is empty. `anchoringMessageGroupId({ organisationId })` then always returns `anchoring:org:{organisationId}`. The following stop, reason `No wallet group`, cannot run (source: `publish-hub-document-syncing-requested-internal.event.handler.ts`, `anchoring-message-group.ts`).

Delete that branch and its test, if a test asserts it. Keep the stops for a missing organisation id and a missing taxonomy id.

### Hand-built identity group id

`PublishClientDltTransactionInternalHandler` sends `` `anchoring:identity:${portfolioId}` ``. The register-success handler and the regular-start handler call `anchoringMessageGroupId`. One function owns the prefix (source: `publish-client-dlt-transaction-internal.event.handler.ts`).

Replace the template string with `anchoringMessageGroupId({ portfolioId })`. The handler already returns when `portfolioId` is missing, so the call has the same result. Update the assertion in `publish-client-dlt-transaction-internal.event.handler.test.ts` only if the expected string changes. It should not.

### Empty `Retryable` interface

`retryable.ts` exports an empty interface and an abstract class of the same name. TypeScript merges them. Nothing implements the interface on its own. Delete the interface. Keep the abstract class. It has two subclasses: `HubUnavailableError` and `IdentityWalletUnderfundedError`. `installHubSqsRetry` redelivers both.

## Outage rule

### Where the rule lives today

Six modules each know a part of "THE HUB is unreachable or full, redeliver; anything else is final":

| Module | What it decides |
| --- | --- |
| `HubTokenizationProvider.connect` | A 4xx is a final 422. No response and any other failure are a `BadGatewayException` (502). |
| `HubTokenizationProvider.write` | No response and HTTP 503 become `HubUnavailableError`. Every other failure is final. |
| `LedgerIOProvider.write` catch | Rethrows `Retryable` before it inserts a Failed row. |
| `TransactionsModel.syncDocument` catch | Rethrows `Retryable`. Converts any `HttpException` with status 502 into `HubUnavailableError`. |
| `SyncDocumentCommandHandler` catch | Rethrows `Retryable` and skips `commit()`. |
| `installHubSqsRetry` | Makes the SQS consumer keep a `Retryable` message. |

### Gaps

- `setAccessKey` turns every error into a 422 and `getProfile` turns every error into a 422. A THE HUB outage on either is final, while the same outage on the write is redelivered. This stays as it is (decision 4).
- The 502 check in `TransactionsModel.syncDocument` matches any `BadGatewayException`, including the ones the hub-admin clients throw.
- Register reaches `LedgerIOProvider.write`. On an outage the write rethrows before the Failed row, and `registerSymbol` publishes `HubSymbolRegisteringFailedEvent`. Register is not redelivered and leaves no Failed row. Neither `TransactionsModel.registerSymbol` nor `RegisterSymbolCommandHandler` rethrows `Retryable`.
- `LedgerIOProvider.write` rethrows `Retryable` for every caller, so legacy flows also leave no Failed row on an outage. That is recorded on [Legacy Tokenization](Legacy%20Tokenization.md) and is not fixed here.

### Direction

`HubTokenizationProvider` is not edited. A typed marker for "THE HUB could not be logged in to" is added around it, in two places that already exist:

- `HubConnectionOutageException` in `sqs/hub-unavailable.error.ts`, next to `HubUnavailableError`. It extends `BadGatewayException`, so HTTP callers still see 502.
- `TokenizationService.getSpecificProvider`, the only call site of `HubTokenizationProvider.connect()`. It turns the `BadGatewayException` from `connect()` into `HubConnectionOutageException`. A 422 from a rejected login passes through unchanged.

`TransactionsModel` checks for `HubConnectionOutageException` and turns it into `HubUnavailableError`. The check replaces the old test for any `HttpException` with status 502, which also matched `BadGatewayException` from the hub-admin clients. The model uses one private method for both `syncDocument` and `registerSymbol`. `HubUnavailableError`, `Retryable`, and `installHubSqsRetry` stay where they are. No file moves.

The write rule stays inside `HubTokenizationProvider.write`: no response and HTTP 503 are an outage, and any other failure is final, because a 504 may mean the write reached THE HUB. No separate classifier module is added.

### Settled decisions

1. Register redelivers on an outage, like document sync. A registry that fails because THE HUB was down blocks every file on that deal. Register's FIFO group is its own aggregate id, so redelivery blocks no other message.
2. There is no opt-in mechanism. `LedgerIOProvider.write` stays as it is. Document sync and register both redeliver through the existing `Retryable` rethrow. The frozen legacy flows are not touched and keep the gap recorded on [Legacy Tokenization](Legacy%20Tokenization.md).
3. The three `instanceof Retryable` rethrows stay in `TransactionsModel`, `SyncDocumentCommandHandler`, and `LedgerIOProvider.write`. Register gets the same two rethrows in `TransactionsModel.registerSymbol` and `RegisterSymbolCommandHandler`. `HubConnectionOutageException` and the write rule in `HubTokenizationProvider.write` still own what counts as an outage.

4. `getProfile` and `setAccessKey` stay as they are, with every error turned into a 422. They serve flows outside this review, and nobody has confirmed what those flows expect.
5. Existing tests that still pass stay. New tests cover `TokenizationService`, the model for sync and register, and `RegisterSymbolCommandHandler`. A test is replaced only if it asserts the old 502 status check.
6. `addRegistry` goes through the same `HubTokenizationProvider.write` POST as document sync. It follows the same write rule, so a missing response and HTTP 503 both redeliver. Giving register a stricter rule would need a call-type flag on `write`, which is not cheap. The duplicate risk is accepted on the owner's reasoning: if THE HUB accepted `addRegistry`, the same transaction cannot be repeated, and if it did not, redelivery is safe. This has not been checked against THE HUB.

7. `hub-tokenization.provider.ts` is not edited by this review. The alias `CONNECTION_NOT_ESTABLISHED` stays there, so the earlier plan item to remove it is dropped.

## Leave in place

### SQS patch

`installHubSqsRetry` replaces `SqsConsumer.prototype.isRetryable` so `instanceof Retryable` is redelivered while `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER` stays off (source: `install-hub-sqs-retry.ts`, `main.ts`). `NestAwsCqrs` stays unchanged. Do not fork `SqsConsumer` and do not add a second patch.

### Log-only event handlers

`HubDocumentSyncingRequestedInternalEventHandler`, `ClientDLTTransactionInternalEventHandler`, and `HubSymbolRegisteringSucceededInternalEventHandler` only write a log line. Their `@EventsHandler` decorator is the registration. `NestAwsService.convertEventHandlersToEvents` puts `eventConstructor.name` into the supported set from that metadata. A command-queue message whose name is missing from that set is dropped (source: `NestAwsService.ts`).

Keep the three classes. Do not add a side list of event names.

### `HUB_QUEUE_FULL`

`HUB_QUEUE_FULL` (`Hub wallet transaction queue is full`) is the fallback when a 503 body has no message. THE HUB's own body is `Wallet transaction queue is at capacity. Retry later.`, and `write()` already prefers that body. Keep the fallback. Do not match on both strings.

## Do not add

- A base class for the three publish handlers. They share a stop-and-send shape and one group-id function.
- Another error type between `Retryable` and `HubUnavailableError`.
- A port or a classifier module for the outage rule. One adapter makes it a seam with nothing across it.
- A change to batch size or consumer count. Parallel organisations already come from separate `MessageGroupId`s on the existing consumers.

## Check

From `inveniam.io`, run the unit tests that cover the touched files:

- `apps/hub-service/src/sqs/install-hub-sqs-retry.test.ts`
- `apps/hub-service/src/tokenization/hub-tokenization.provider.test.ts`
- `apps/hub-service/src/transactions/domain/models/transactions.model.test.ts`
- `apps/hub-service/src/transactions/domain/commands/sync-document.command.test.ts`
- `apps/hub-service/src/transactions/application/providers/tokenization/tokenization-ledger.provider.test.ts`
- `apps/hub-service/src/organisation-provisioning/domain/events/publish-hub-document-syncing-requested-internal.event.handler.test.ts`
- `apps/hub-service/src/organisation-provisioning/domain/events/publish-client-dlt-transaction-internal.event.handler.test.ts`

After the cut, a missing organisation id and a missing taxonomy id still skip the send. A present organisation id still sends `anchoring:org:{organisationId}`. A client deal with a portfolio still sends `anchoring:identity:{portfolioId}`. A 503 and a missing HTTP response on the write still reject with `HubUnavailableError` and do not apply a Failed event.

## Related pages

- [Wiki Index](index.md)
- [Legacy Tokenization](Legacy%20Tokenization.md)
- [SQS FIFO Approach](SQS%20FIFO%20Approach.md)
- [ADR-0011 FIFO Per-Wallet Chain Without Hold](../decisions/ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)
