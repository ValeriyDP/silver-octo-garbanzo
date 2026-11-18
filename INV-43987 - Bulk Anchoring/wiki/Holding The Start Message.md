---
name: Holding The Start Message
date: 2026-11-16T12:30:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - wiki
  - architecture
  - sqs
---

# Holding The Start Message

> [!info] Active
> Part of the current approach, [SQS FIFO Approach](SQS%20FIFO%20Approach.md). No option is chosen yet.

**Summary**: Ways to keep a file's start message, and so its wallet's FIFO group, in the queue until the file's finish. Throwing a retryable error with `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER=true` is needed only on the shared hub queue read by the generic `SqsConsumer`, when the pod's consumer must not stay busy. Waiting inside the handler holds the message without the flag. A dedicated queue with hub's own consumer holds it with no throw at all. A second consumer on the shared hub queue does not work. Direct `SendMessage` to SQS fixes delivery, not holding. Local hub is on Floci, so any of these can be tried there. A receive of one message holds the group.

**Sources**: `shared-modules/NestAwsCqrs/src/broker/aws/SqsConsumer.ts`, `shared-modules/NestAwsCqrs/src/broker/aws/SnsProducer.ts`, `shared-modules/NestAwsCqrs/src/broker/rabbitmq/RabbitMqConsumer.ts`, `shared-modules/NestAwsCqrs/src/NestAwsCqrs.ts`, `node_modules/sqs-consumer/dist/consumer.js`, [SQS FIFO Approach](SQS%20FIFO%20Approach.md).

**Last updated**: 2026-11-16

---

## Constraints

- Goal: as few infrastructure changes as possible.
- The production hub queue is FIFO (stated by the team; attributes not read).
- Local hub runs on Floci SNS and SQS FIFO (see [SQS FIFO Approach](SQS%20FIFO%20Approach.md), Local stack). A receive of one message holds the group. Hub's batch size is 1.

## Why a message needs holding

SQS FIFO does not deliver the next message of a group while one is in flight, and releases the group when that message is deleted. The generic `SqsConsumer` deletes a message when its handler returns. When the handler throws, it also deletes the message unless `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER=true` and the error is not an `ApplicationError` or `DomainError` (source: `SqsConsumer.ts`, `isRetryable`). Holding only blocks the wallet's group. Other groups keep flowing.

The provisioning chain runs inside the handler, and the heartbeat keeps the message invisible while it runs, with no timeout on hub's batch path (source: `NestAwsCqrs.ts`, `consumer.js`). Holding is needed only for the wait between THE HUB accepting the write and the webhook.

## A second consumer on the shared queue does not work

SQS has no per-consumer routing on one queue. Every `ReceiveMessage` takes the next available message, whoever calls it.

- The generic consumer still reads the queue. It receives some start messages, finds the event name outside its allowed list, returns, and the message is deleted. The group is released at once.
- The hub-only consumer receives ordinary service messages and has to give them back.

Making it work means changing the shared `SqsConsumer` so it returns foreign messages with `ChangeMessageVisibility(0)`, and the hub consumer doing the same. Messages bounce between the consumers, each receive raises `ApproximateReceiveCount`, and ordinary messages can reach the dead-letter queue. Every service uses that module. Per-consumer filtering exists only on SNS subscriptions, and a subscription always targets its own queue.

## Options

| Option | Infrastructure | Code | Main risk |
| --- | --- | --- | --- |
| Shared queue, throw with `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER=true` | Nothing new; possibly a higher `maxReceiveCount` | Start handler in hub; the flag in helm | The flag is global. Saga commands that rethrow get retried, provisioning top-ups included. All of them need wrapping. |
| Shared queue, wait inside the handler | Nothing new | Start handler in hub only | The pod's consumer is busy for the whole wait. Files in progress are capped by the number of pods. |
| Shared queue, shared `SqsConsumer` releases foreign messages | Nothing new | Change in shared NestAwsCqrs | Bouncing messages, growing receive counts, ordinary messages can reach the dead-letter queue. |
| Dedicated FIFO queue, direct `SendMessage` | One FIFO queue; a FIFO dead-letter queue (the existing one if it is FIFO); IAM send and receive for hub; the URL in helm. No SNS subscription. | Hub's own consumer; the shared module stays untouched | A small Terraform and helm change. |

### Shared queue, throw

The start handler throws a retryable error on every delivery until the finish is recorded. The message comes back about every 10 s (hub's `VISIBILITY_TIMEOUT`). Every delivery counts toward `maxReceiveCount`; locally that is 100, about 17 minutes. Each throw is logged at error level. Detail: [SQS FIFO Approach](SQS%20FIFO%20Approach.md), Chosen direction and Handler audit.

### Shared queue, wait inside the handler

The handler does not return until the file record shows `sync_success` or `sync_failed`. The heartbeat extends visibility, no timeout applies, no receive is spent, and the flag is not needed. `sqs-consumer` handles a pod's messages one at a time, so the pod handles nothing else from the hub queue meanwhile. THE HUB's webhook arrives over HTTP, not through the queue (unverified: no finish path depends on the queue). Visibility extension is capped at 12 h from receipt.

### Dedicated queue, own consumer

No throw. Hub's code controls the message's lifetime:

1. The consumer receives the start message, starts the process, and keeps the receipt handle instead of deleting the message.
2. While the process runs, it extends visibility with `ChangeMessageVisibility`.
3. On the finish (`sync_success` or `sync_failed` from the webhook), it calls `DeleteMessage` with the stored handle. The group is released.

No retries, no `maxReceiveCount` spending, no global flag, no log noise. Limits: the 12 h visibility cap, and a pod restart loses the handle. The message then becomes visible again on its own. On redelivery the file record decides: started with an unknown outcome → `sync_failed`, delete; not started → start.

## Direct `SendMessage` instead of SNS

Hub can send the start message straight to SQS when it receives the source event (`ClientDLTTransaction` or `HubDocumentSyncingRequestedEvent`). This fixes delivery. It does not hold the message: on the shared queue the generic consumer reads it like any other.

What it gives:

- Hub sets `MessageGroupId` (`anchoring:identity:{portfolioId}`, `anchoring:org:{organisationId}`) and `MessageDeduplicationId` (`taxonomyId`) itself. Through SNS the group comes from `aggregateId` or `context.messageGroupId` (source: `SnsProducer.ts`).
- The message reaches only the target queue, not every topic subscriber.
- It bypasses `SnsProducer`, which logs and swallows publish errors. A `SendMessage` failure is visible.
- A dedicated queue needs no SNS subscription.

What to handle:

- **Body.** `SqsConsumer` parses `JSON.parse(Body).Message`, so on the shared queue the body is an SNS envelope `{ "Message": "<json>" }` holding `{ eventName, eventBody }`.
- **Allowed list.** On the shared queue the event name must be in hub's allowed list, or the consumer deletes the message without handling it.
- **IAM.** Hub needs `sqs:SendMessage` on the target queue (unverified: hub's current permissions).
- **Lost start.** The source event's handler sends, returns, and the source message is deleted. With the flag off, a failed `SendMessage` loses the start. The send needs its own retry or an explicit failure event.
- **Double start.** `ClientDltProvisioningSaga` must stop running the chain on the source event, or every file runs twice.
- **Local.** Hub is on Floci. From another container the hub event queue is `http://inv-floci:4566/000000000000/hub-event-queue.fifo`.

## Floci for local runs

Floci is the local broker, and hub is already on it. FIFO groups, dedup, and the `msList` subscription filter were checked live. The hub queues redrive to `inveniam-dead-letters.fifo` after 100 receives; that move was not exercised (see [SQS FIFO Approach](SQS%20FIFO%20Approach.md), Local stack). A receive of one message holds the group and lets other groups through. A receive of ten returned every waiting message of two groups in one call, so a batch larger than 1 does not hold the group on this emulator. `RabbitMqConsumer` still has no groups (source: `RabbitMqConsumer.ts`). Hub is not using it. Data room was not running at the check, so a file start has not been exercised end to end.

## A fourth option: no hold at all

Re-grouping the whole per-file chain under `MessageGroupId = wallet` and letting it flow without any hold is a separate design, written up in [ADR-0011 FIFO Per-Wallet Chain Without Hold](../decisions/ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md). It serialises one handler at a time per wallet instead of one file end-to-end, keeps the org lock for the cross-wallet parent nonce, and leans on THE HUB's own write queue plus 503→requeue. It trades the strict one-in-flight guarantee for no hold and no table.

## Related pages

- [Wiki Index](index.md)
- [SQS FIFO Approach](SQS%20FIFO%20Approach.md)
- [ADR-0011 FIFO Per-Wallet Chain Without Hold](../decisions/ADR-0011%20FIFO%20Per-Wallet%20Chain%20Without%20Hold.md)
