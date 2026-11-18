---
name: Wiki Index
date: 2026-11-16T12:30:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - wiki
  - index
---

# Wiki Index

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

Knowledge base for **Bulk Anchoring (INV-43987)**. How-tos, diagrams, current state, open questions.

Decisions live in [decisions/INDEX](../decisions/INDEX.md). Cross-link; do not copy ADRs here.

## Pages

- [SQS FIFO Approach](SQS%20FIFO%20Approach.md) — **Active.** Hub republishes file starts to the existing hub SQS FIFO queue, grouped by signing wallet. Start and finish event pairs with payloads, holding the group until finish, handler audit for the global error handler, chain-throw failure event, file record, local stack on Floci (hub is on it; a receive of one message holds the group), open items.
- [Holding The Start Message](Holding%20The%20Start%20Message.md) — **Active.** Ways to hold a start message until the finish: throw with the global error handler, wait inside the handler, dedicated queue with its own consumer. Why a second consumer on the shared queue fails. Direct `SendMessage` instead of SNS.

Every page below is on hold and kept as reference.

- [File Start Today](File%20Start%20Today.md) — Hub starts each file on arrival. Who sends which event. How hub writes to THE HUB. The 150 s organisation lock.
- [Anchoring Bucket](Anchoring%20Bucket.md) — Proposed standalone module: one in-flight file per THE HUB signing wallet, `client_dlt` source wired, `regular` source stubbed, terminal rows kept.
- [Anchoring Bucket Diagrams](Anchoring%20Bucket%20Diagrams.md) — PlantUML for module and sources, end-to-end `client_dlt` sequence, intake, finish-and-claim, per-wallet queues, status.
- [Anchoring Bucket Board](Anchoring%20Bucket%20Board.excalidraw.md) — Excalidraw board of the same flow. JSON: [Anchoring Bucket Board.excalidraw](Anchoring%20Bucket%20Board.excalidraw).
- [Bucket Pattern And Alternatives](Bucket%20Pattern%20And%20Alternatives.md) — Pattern name (per-key admission gate in front of the process, keyed semaphore, Sequential Convoy; not fan-in). Why job queues and brokers do not replace it. AWS Step Functions and Azure Durable Functions as native options. Gaps against mature tools.
- [Anchoring Bucket Module](Anchoring%20Bucket%20Module.excalidraw.md) — Excalidraw drawing of the module and sources: data room → source adapters (intake, start, finish) → core → `anchoring_bucket`. JSON: [Anchoring Bucket Module.excalidraw](Anchoring%20Bucket%20Module.excalidraw).
- [Open Questions](Open%20Questions.md) — Two decided, one direction agreed (503 queue-full requeues to the tail), five open (manual sync wallet, taxonomy reuse, registry-failure payload, recovery after a pod reset, graceful shutdown of the current file).

## Related

- [Project README](../README.md)
- [CLAUDE](../CLAUDE.md)
- [Decision register](../decisions/INDEX.md)
