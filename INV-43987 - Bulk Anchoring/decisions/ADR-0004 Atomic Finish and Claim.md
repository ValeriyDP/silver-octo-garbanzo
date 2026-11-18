---
name: ADR-0004 Atomic Finish and Claim
date: 2026-11-11T14:50:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0004 Atomic Finish and Claim

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Proposed)
- **Date**: 2026-11-11
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0001 Hub Postgres Bucket](ADR-0001%20Hub%20Postgres%20Bucket.md), [ADR-0003 Keep Terminal Rows](ADR-0003%20Keep%20Terminal%20Rows.md), [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)

## Context

Several hub pods run intake and finish at the same time. Two races exist if each path only guards itself:

- **Intake vs finish.** Pod 1 inserts C as `waiting` and sees A still `in_flight` (A's finish is not committed). Pod 2 finishes A and finds no `waiting` row (C is not committed). Both commit. C waits with no `in_flight` row and nothing wakes it.
- **Intake vs intake.** Both pods see no `in_flight` row and both try to claim. The unique partial index rejects the second, and in Postgres that error aborts the whole transaction, the insert included.

`FOR UPDATE SKIP LOCKED` does not help. It is for many workers draining one queue. Here one claimant per key is wanted, and skipping a locked row would claim the second-oldest file and break FIFO.

The chain calls THE HUB and can take long enough that a database transaction must not stay open around it. `RunPortfolioProvisioningCommand` is the existing entry (source: `apps/hub-service/src/organisation-provisioning/domain/commands/run-portfolio-provisioning.command.ts`).

Hub already uses advisory locks: `OrganisationProvisioningLock` takes session-scoped `pg_try_advisory_lock(scope, hashtext(organisationId))` with scopes `42559` and `42560` (source: `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`).

## Decision

Intake and finish both serialise on one **transaction-scoped** advisory lock per `queue_key`: `pg_advisory_xact_lock(AdvisoryLockScope.AnchoringBucketQueue, hashtext(queue_key))`, scope `2001` from the hub-wide registry in [ADR-0010](ADR-0010%20Hub%20Advisory%20Lock%20Scope%20Registry.md). It differs from the organisation provisioning scopes. The lock is released by commit or rollback, so no unlock step can be missed. It is never held while the chain runs, so it cannot wait on the organisation locks.

**Claim** (inside the lock):

```sql
UPDATE anchoring_bucket
SET status = 'in_flight'
WHERE id = (
  SELECT id
  FROM anchoring_bucket
  WHERE queue_key = $queueKey
    AND status = 'waiting'
  ORDER BY received_at, id
  LIMIT 1
)
AND NOT EXISTS (
  SELECT 1 FROM anchoring_bucket
  WHERE queue_key = $queueKey AND status = 'in_flight'
)
RETURNING *;
```

**Intake.** One transaction:

1. Take the lock for `queue_key`.
2. `INSERT … status = 'waiting', received_at = now() ON CONFLICT (source, taxonomy_id) DO NOTHING`.
3. Claim. The claimed row is the oldest `waiting` row, which can be older than the one just inserted.
4. Commit. Start the claimed row's command through its source adapter.

**Finish.** One transaction:

1. Find the `in_flight` row by the source's match ([ADR-0003](ADR-0003%20Keep%20Terminal%20Rows.md)). None: stop.
2. Take the lock for its `queue_key`.
3. `UPDATE … SET status = $terminal, reason = $reason WHERE id = $id AND status = 'in_flight'`. Zero rows: another pod finished it. Commit and stop.
4. Claim.
5. Commit. Start the claimed row's command, if any.

A throw in the running command uses the same finish transaction with `sync_failed` and the error message.

The intake-vs-finish race is closed because both take the same lock: whichever commits second sees the other's row. Intake always claims the oldest `waiting` row, so a key left with `waiting` rows and no `in_flight` row is picked up by the next arrival. The unique partial index on `in_flight` stays as a backstop and is not hit in normal operation.

A redelivered `ClientDLTTransaction` inserts nothing, and the claim finds the key already `in_flight`. The intake handler may then ack or fail without side effects.

## Alternatives considered

- **`FOR UPDATE SKIP LOCKED` on the waiting row.** Breaks FIFO under contention and does not close the intake-vs-finish race.
- **Rely on the unique partial index and catch the violation.** The violation aborts the transaction and the insert is lost, unless every statement runs under a savepoint and retries.
- **A `queue_head (queue_key PK, in_flight_id)` table locked `FOR UPDATE`.** Same serialisation as the advisory lock. It needs an upsert per new organisation and one more table to keep in step.
- **Session-scoped lock as in `OrganisationProvisioningLock`.** Needs a dedicated connection and an explicit unlock. The bucket work is a single transaction, so the transaction-scoped form is enough.
- **Mark terminal and claim the next in two commits.** A crash between them leaves waiting rows with nobody to start them until a later intake.
- **Hold the transaction open until THE HUB returns.** The connection sits through register, webhook wait, and `addRecord`.

## Consequences

- **Positive**: One claimant per signing wallet at any moment. FIFO holds under contention. Redelivery is harmless. A finish either lands with the next file already `in_flight`, or it does not land at all.
- **Negative / trade-offs**: The command still runs after commit. A crash in that gap leaves the new row `in_flight` with the chain not running ([ADR-0005](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)). Intake and finish for one `queue_key` queue on the lock for the length of a short transaction.
- **Follow-ups / open threads**: None.

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/anchoring-bucket/` | Intake and finish transactions with `pg_advisory_xact_lock` |
| `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts` | Unchanged. Its scopes must not be reused by the bucket |
| `apps/hub-service/src/organisation-provisioning/domain/commands/run-portfolio-provisioning.command.ts` | Invoked only with a payload already claimed |

## Related

- [Decision register](INDEX.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [Anchoring Bucket Diagrams](../wiki/Anchoring%20Bucket%20Diagrams.md)
- [ADR-0003 Keep Terminal Rows](ADR-0003%20Keep%20Terminal%20Rows.md)
- [ADR-0005 Unmarked In Flight Holds](ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
- [ADR-0009 One In Flight Per Signing Wallet](ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
