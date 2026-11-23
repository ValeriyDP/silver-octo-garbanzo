---
name: Code Review Plan
date: 2026-11-23T17:20:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - wiki
  - guide
---

# Code Review Plan

> [!info] Active
> Review of the code that is already running. This page lists what to delete and what to leave in place. It is not a new design.

**Summary**: The regular-organisation start hop and the 503 / hub-down retry are small enough. The review removes dead branches and one duplicated group-id string. It leaves the three `Retryable` rethrows, the SQS consumer patch, and the log-only `@EventsHandler` classes. Those classes are how the command queue learns the internal event name.

**Sources**: `apps/hub-service/src/sqs/retryable.ts`, `apps/hub-service/src/sqs/hub-unavailable.error.ts`, `apps/hub-service/src/sqs/install-hub-sqs-retry.ts`, `apps/hub-service/src/main.ts`, `apps/hub-service/src/tokenization/hub-tokenization.provider.ts`, `apps/hub-service/src/transactions/domain/models/transactions.model.ts`, `apps/hub-service/src/transactions/domain/commands/sync-document.command.ts`, `apps/hub-service/src/transactions/application/providers/ledger-io.provider.ts`, `apps/hub-service/src/organisation-provisioning/domain/anchoring-message-group.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/publish-hub-document-syncing-requested-internal.event.handler.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/publish-client-dlt-transaction-internal.event.handler.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/hub-document-syncing-requested-internal.event.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/client-dlt-transaction-internal.event.ts`, `apps/hub-service/src/organisation-provisioning/domain/events/hub-symbol-registering-succeeded-internal.event.ts`, `shared-modules/NestAwsCqrs/src/NestAwsService.ts`.

**Last updated**: 2026-11-23

---

## Scope

IO Hub Service only. THE HUB queue depth stays a THE HUB setting (`WALLET_TX_QUEUE_MAX_DEPTH`). The local emit script stays a local tool and is outside this review.

The behaviour to preserve:

- A regular file is copied to `HubDocumentSyncingRequestedInternal` and sent on `anchoring:org:{organisationId}`, deduplicated by `taxonomyId`.
- `TransactionsSagas.syncDocument` listens only to that internal event.
- No HTTP response from THE HUB, and HTTP 503, leave the command message on the queue. No `HubDocumentSyncingFailedEvent`, no Failed transaction row.
- A credential rejection (HTTP 422 from `connect()`) and any other write error stay final.

## Delete

### Dead group check on the regular start

`PublishHubDocumentSyncingRequestedInternalHandler` already returns when `organisationId` is empty. `anchoringMessageGroupId({ organisationId })` then always returns `anchoring:org:{organisationId}`. The following stop, reason `No wallet group`, cannot run (source: `publish-hub-document-syncing-requested-internal.event.handler.ts`, `anchoring-message-group.ts`).

Delete that branch and its test, if a test asserts it. Keep the stops for a missing organisation id and a missing taxonomy id.

### Hand-built identity group id

`PublishClientDltTransactionInternalHandler` sends `` `anchoring:identity:${portfolioId}` ``. The register-success handler and the regular-start handler call `anchoringMessageGroupId`. One function owns the prefix (source: `publish-client-dlt-transaction-internal.event.handler.ts`).

Replace the template string with `anchoringMessageGroupId({ portfolioId })`. The handler already returns when `portfolioId` is missing, so the call has the same result. Update the assertion in `publish-client-dlt-transaction-internal.event.handler.test.ts` only if the expected string changes. It should not.

### Empty `Retryable` interface

`retryable.ts` exports an empty interface and an abstract class of the same name. TypeScript merges them. Nothing implements the interface on its own. Delete the interface. Keep the abstract class. `HubUnavailableError` stays the only subclass.

### Local alias of the connection message

`hub-tokenization.provider.ts` copies `HUB_CONNECTION_NOT_ESTABLISHED` into `CONNECTION_NOT_ESTABLISHED`. Use the imported constant at the four call sites.

## Leave in place

### Three rethrows

`Retryable` is rethrown in three catches. Each catch would otherwise finish the file:

| Catch | What it would do |
| --- | --- |
| `LedgerIOProvider.write` | Insert a Failed transaction row |
| `TransactionsModel.syncDocument` | Apply `HubDocumentSyncingFailedEvent` |
| `SyncDocumentCommandHandler.execute` | Log, skip the rethrow, then `commit()` |

Keep all three. A fourth wrapper, interceptor, or retry policy service would only forward the same error.

`syncDocument` also turns an `HttpException` with status 502 into `HubUnavailableError`. That is the `connect()` path: no response and HTTP 5xx become `BadGatewayException` with `Connection with provider was not established`. `write()` already throws `HubUnavailableError` for no response and for HTTP 503. Leave the 502 conversion on `syncDocument`. Moving it into `connect()` would throw `HubUnavailableError` at every caller, including symbol register, whose catch publishes `HubSymbolRegisteringFailedEvent` and does not rethrow. That is a behaviour change and is out of this cleanup.

`HUB_QUEUE_FULL` (`Hub wallet transaction queue is full`) is the fallback when a 503 body has no message. THE HUB's own body is `Wallet transaction queue is at capacity. Retry later.`, and `write()` already prefers that body. Keep the fallback. Do not match on both strings.

### SQS patch

`installHubSqsRetry` replaces `SqsConsumer.prototype.isRetryable` so `instanceof Retryable` is redelivered while `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER` stays off (source: `install-hub-sqs-retry.ts`, `main.ts`). NestAwsCqrs stays unchanged. Do not fork `SqsConsumer` and do not add a second patch.

### Log-only event handlers

`HubDocumentSyncingRequestedInternalEventHandler`, `ClientDLTTransactionInternalEventHandler`, and `HubSymbolRegisteringSucceededInternalEventHandler` only write a log line. Their `@EventsHandler` decorator is the registration. `NestAwsService.convertEventHandlersToEvents` puts `eventConstructor.name` into the supported set from that metadata. A command-queue message whose name is missing from that set is dropped (source: `NestAwsService.ts`).

Keep the three classes. Do not add a side list of event names. The log line can go only if `Command received` is enough; the class stays.

## Do not add

- A base class for the three publish handlers. They share a stop-and-send shape and one group-id function. A template method would be a new abstraction over three call sites.
- Another error type between `Retryable` and `HubUnavailableError`.
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

After the cut, a missing organisation id and a missing taxonomy id still skip the send. A present organisation id still sends `anchoring:org:{organisationId}`. A client deal with a portfolio still sends `anchoring:identity:{portfolioId}`. A 503 and a missing HTTP response still reject with `HubUnavailableError` and do not apply a Failed event.

## Related pages

- [Wiki Index](index.md)
- [SQS FIFO Approach](SQS%20FIFO%20Approach.md)
- [ADR-0011 FIFO Per-Wallet Chain Without Hold](../decisions/ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)
