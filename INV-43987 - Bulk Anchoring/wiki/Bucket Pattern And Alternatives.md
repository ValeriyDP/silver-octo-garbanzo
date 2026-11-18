---
name: Bucket Pattern And Alternatives
date: 2026-11-11T18:15:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - wiki
  - architecture
---

# Bucket Pattern And Alternatives

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

**Summary**: The anchoring bucket is a **per-key admission gate in front of the process**: a keyed semaphore acquired before the start command is sent and released by the terminal event. It does not wrap the saga or change its steps. In messaging terms it is a Sequential Convoy. It is not fan-in. It holds a THE HUB signing wallet for the whole business process, from `ClientDLTTransaction` to the Success/Failed webhook, not only while one message is handled. Job queues and brokers limit concurrency per handler run, so they do not replace it. The native cloud workflow services that can hold a key for a whole process would need the provisioning chain rewritten as a state machine.

**Sources**: [Anchoring Bucket](Anchoring%20Bucket.md), [ADR-0004](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md), [ADR-0005](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md), [ADR-0009](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md). Product behaviour below comes from vendor documentation as known at the time of writing; it was not re-verified against current docs.

**Last updated**: 2026-11-11

---

## Pattern name

| Name                               | Source                                | What it covers                                                                                                                               |
| ---------------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Admission gate (admission control) | General                               | Holds incoming work and admits it only when capacity is free                                                                                 |
| Keyed semaphore / keyed mutex      | General                               | At most N (here 1) units of work active per key                                                                                              |
| Sequential Convoy                  | Azure Architecture Center             | Messages partitioned by key, FIFO within a key, keys in parallel                                                                             |
| Process Manager                    | Enterprise Integration Patterns (EIP) | Partial match only. A Process Manager decides each next step; the bucket tracks only start and end and leaves the steps to the existing saga |

The gate sits between the entry event and the saga's first command. Today `ClientDltProvisioningSaga` maps `ClientDLTTransaction` straight to `RunPortfolioProvisioningCommand`. With the bucket, the event becomes a `waiting` row, and the command is sent only when the wallet has no `in_flight` row. The steps in between are untouched. The bucket listens only for the terminal events that release the wallet.

Fan-in, as EIP uses the term, gathers the results of parallel work into one place (Aggregator, Scatter-Gather). The bucket does the opposite: it spreads incoming files into one serial lane per signing wallet.

## Unit being serialized

The lock covers the whole business process, not one handler call:

1. `ClientDLTTransaction` arrives and is claimed for its `queue_key` (`identity:{portfolioId}` or `org:{organisationId}`).
2. IO Hub Service runs the provisioning chain, with several HTTP calls to THE HUB.
3. THE HUB answers through the Success/Failed webhook.
4. The finish transaction marks the row terminal and claims the next waiting row for that key.

The process takes minutes, not milliseconds. Any alternative must keep the wallet held for that whole span.

## Job queues and brokers

These tools limit concurrency **while a handler runs**. The next item for a key starts when the handler returns or acks, even though the business process is still waiting on THE HUB.

| Tool | Per-key serial | Gap for this process |
| --- | --- | --- |
| pg-boss (Postgres, Node) | `singletonKey` plus queue policies (unverified: exact per-key semantics in current versions) | A job ends when the handler completes. Holding it open until the webhook means fetching manually and completing by id. |
| graphile-worker (Postgres, Node) | Jobs sharing a `queueName` run one after another | A job ends when the task function resolves. |
| BullMQ Pro groups (Redis) | Per-group concurrency | Same handler-level limit. Needs Redis and a paid licence. |
| AWS SQS FIFO | `MessageGroupId`; a group is blocked while one of its messages is in flight | Holding a message un-deleted until the webhook relies on extending visibility, which is capped at 12 h. Local RabbitMQ has no equivalent. |
| Azure Service Bus sessions | Session id per key, one receiver per session | Same as SQS FIFO: the lock lasts while the message is held, not while the process runs. |
| Kafka keyed partitions | Order per partition | Unrelated keys sharing a partition block each other. Commits are per offset, not per process. |

Any of these can act as the waiting list. A separate lock that spans the whole process is still needed, and that lock is what the bucket is.

## Native cloud workflow services

These treat a long, multi-step process as one unit and can wait for an external callback.

| Service | How it would hold the key | Fit with IO Hub Service |
| --- | --- | --- |
| AWS Step Functions | Semaphore in DynamoDB taken at the start and released at the end, with a cleanup path on failure. Webhook via a callback task (`.waitForTaskToken`). | IO Hub Service on EKS can run steps as an Activity worker (`GetActivityTask`) or be called over HTTP. The provisioning chain moves from NestJS CQRS sagas into a state machine. |
| Azure Durable Functions / Durable Task | Durable Entities run operations one at a time per key. Orchestrations wait for the webhook with `WaitForExternalEvent`. | Code runs in Azure Functions or on the Durable Task SDKs. It does not fit the NestJS service as deployed today. |

Both are a rewrite of the provisioning chain, not a gate placed in front of the existing saga.

## Why the bucket stays custom

The existing saga is NestJS CQRS events and commands. Gating it without rewriting it needs a semaphore that starts on the entry event and releases on the terminal event. No off-the-shelf tool provides that gate in front of an in-process saga. The Postgres table with per-key `pg_advisory_xact_lock` is the usual answer for this shape ([ADR-0004](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md)).

## What mature tools have that the bucket lacks

| Capability | Bucket today |
| --- | --- |
| Outbox or lease between claim and dispatch | The claim commits `in_flight`, then the start command is sent. A crash in between leaves the row holding the wallet. |
| Delayed retry (`run_at` / `available_at`) | Claims run only on intake and finish. A requeued row alone in its queue has nothing to wake it. See [Open Questions](Open%20Questions.md) #6. |
| Global concurrency cap | Only the per-key limit. A 503 from THE HUB points at a limit wider than one wallet. |
| Process deadline | None. Accepted in [ADR-0005](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md). Recovery after a pod reset: [Open Questions](Open%20Questions.md) #7. |

## When a row holds without a terminal event

Steps that catch an error and emit a Failed event close the process normally. A row holds only when no `catch` runs or when the terminal event cannot be matched:

- The pod stops mid-step (deploy, OOM kill, eviction) during a THE HUB call or between a command and its in-process CQRS event.
- THE HUB accepts the request but never calls the webhook.
- The Failed event cannot be matched to a row. `HubSymbolRegisteringFailedEvent` has no `taxonomyId`; the match resolves the wallet from `dealId` ([ADR-0003](../decisions/ADR-0003%20Keep%20Terminal%20Rows.md)).
- A `catch` logs and swallows the error without emitting a terminal event (unverified: the `ClientDLTTransaction` chain has not been traced for this).

## Related pages

- [Anchoring Bucket](Anchoring%20Bucket.md)
- [File Start Today](File%20Start%20Today.md)
- [Open Questions](Open%20Questions.md)
- [ADR-0004 Atomic Finish and Claim](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md)
- [ADR-0005 Unmarked In Flight Holds](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
- [ADR-0009 One In Flight Per Signing Wallet](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
