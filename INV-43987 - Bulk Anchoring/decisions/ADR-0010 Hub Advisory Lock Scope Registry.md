---
name: ADR-0010 Hub Advisory Lock Scope Registry
date: 2026-11-12T11:30:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - adr
  - architecture
---

# ADR-0010 Hub Advisory Lock Scope Registry

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

- **Status**: On hold (was Proposed)
- **Date**: 2026-11-12
- **Area**: hub-service
- **Deciders**: Bulk Anchoring investigation. No named approver recorded in this note.
- **Related**: [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md), [Anchoring Bucket](../wiki/Anchoring%20Bucket.md), [File Start Today](../wiki/File%20Start%20Today.md)

## Context

Hub takes Postgres advisory locks in the two-key form `(scope int4, key int4)`. The first key names the protected resource; the second is a hash of the owner id. Two different scopes never block each other.

Today the scopes live in a module-local enum (source: `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts`):

```ts
export enum OrganisationLockScope {
  /** The parent wallet's nonce — concurrent sends would collide. */
  ParentWalletNonce = 42559,
  /** The org HD counter — concurrent reads would hand out one leaf twice. */
  IdentityHdLeaf = 42560
}
```

`OrganisationProvisioningLock` takes them session-scoped, `pg_try_advisory_lock(scope, hashtext(organisationId))`, on a dedicated connection with a 150 s wait. `ParentWalletNonce` serialises the parent wallet top-up of an Identity wallet, so two runs never sign on one nonce. `IdentityHdLeaf` serialises check → read counter → derive → create → increment of `io_hub_organisation_map.identity_wallet_index`, so one HD leaf is never handed out twice. They are separate scopes because the two sections run on different connections; one shared key would self-deadlock if one section nested inside the other.

The values carry no meaning in Postgres. They match a ticket number and its successor, and nothing records why. The bucket needs a third scope for `pg_advisory_xact_lock(scope, hashtext(queue_key))` ([ADR-0004](ADR-0004%20Atomic%20Finish%20and%20Claim.md)). With one enum per module, a new scope can reuse a value already taken elsewhere without anyone noticing.

Locks taken with one `bigint` key and locks taken with two `int4` keys are separate key spaces in Postgres, so only two-key callers can collide.

No running code takes these locks yet: the organisation provisioning flow is merged but not active. Renumbering therefore has no rolling-deploy window in which old and new pods use different keys.

## Decision

One registry of advisory lock scopes for all of hub, in a shared location such as `apps/hub-service/src/common/`:

```ts
export enum AdvisoryLockScope {
  // 1xxx organisation-provisioning
  ParentWalletNonce = 1001,
  IdentityHdLeaf = 1002,
  // 2xxx anchoring-bucket
  AnchoringBucketQueue = 2001
}
```

- The thousands digit is the module; the rest is the resource within it. A new module takes the next thousand.
- Values below `1000` are not used.
- `OrganisationProvisioningLock` uses the registry. `OrganisationLockScope` is removed.
- The bucket takes `pg_advisory_xact_lock(AdvisoryLockScope.AnchoringBucketQueue, hashtext(queue_key))`.
- A unit test asserts that every value in the registry is unique.

## Alternatives considered

- **Keep `42559` / `42560` and add `43987` for the bucket.** Follows the existing habit. Values stay unexplained, and each module still owns a private enum, so collisions stay invisible.
- **Keep per-module enums with round numbers.** Readable values, but nothing stops two modules picking the same one.
- **Hash a string name into the scope (`hashtext('anchoring-bucket')`).** No registry to maintain, but collisions are possible and the value cannot be read from `pg_locks` without recomputing it.

## Consequences

- **Positive**: Every hub lock scope is listed in one file. `pg_locks.classid` reads as module and resource. The uniqueness test catches a duplicate before review.
- **Negative / trade-offs**: `organisation-provisioning` changes in a feature that is otherwise about the bucket. Anyone reading `pg_locks` with the old numbers in mind sees new values.
- **Follow-ups / open threads**: Not checked whether anything else in hub's database takes two-key advisory locks.

## Affected code

Nothing is changed yet.

| Path | What would change |
| ---- | ----------------- |
| `apps/hub-service/src/common/` (proposed) | New `AdvisoryLockScope` registry and its uniqueness test |
| `apps/hub-service/src/organisation-provisioning/infrastructure/organisation-provisioning.lock.ts` | Uses `AdvisoryLockScope`; `OrganisationLockScope` removed |
| Callers of `OrganisationLockScope` (`IdentityWalletTopUp`, `EnsureHubIdentityWalletStep`) | Import the new enum |
| `apps/hub-service/src/anchoring-bucket/` | Intake and finish lock on `AnchoringBucketQueue` |

## Related

- [Decision register](INDEX.md)
- [ADR-0004 Atomic Finish and Claim](ADR-0004%20Atomic%20Finish%20and%20Claim.md)
- [Anchoring Bucket](../wiki/Anchoring%20Bucket.md)
- [File Start Today](../wiki/File%20Start%20Today.md)
