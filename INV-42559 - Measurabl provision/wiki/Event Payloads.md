---
name: Event Payloads
date: 2026-09-15T16:30:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
---

# Event Payloads

**Summary**: Inbound events: `OrganizationToHubProvision` (org relation only) and `ClientDLTTransaction` (portfolio / registry / sync). Hub → IO success events unchanged. Payloads as TypeScript types.

**Sources**: [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md); [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md).

**Last updated**: 2026-09-30

---

Comments mark flow use. Existing TS types also declare fields this path does not send (inbound `userId`, `userEmail`, `ledgerType`, `transactionType`). Outbound events are `UserScope<T>` (`T & { userId: string }`).

## In — `OrganizationToHubProvision`

Stops after org relation setup. Does not start portfolio, registry, or sync.

```ts
export interface OrganizationToHubProvisionPayload {
  organisationId: string;
  organisationName: string;
}
```

## In — `ClientDLTTransaction`

Was `MeasurablDLTTransaction`.

```ts
export interface ClientDLTTransactionPayload {
  dealId: string;
  taxonomyId: string; // required IO correlation key. Must be data_room_file_taxonomies.id
  organisationId: string;
  uri: string;
  checksum: string;
  checksumAlgo: string;
}
```

`taxonomyId` is required for IO. Hub `addRegistry` / `addRecord` do not use it. Without an existing `data_room_file_taxonomies` row at that primary key, IO cannot park `pending_document`, cannot emit a usable `HubDocumentSyncingSucceededEvent`, cannot run `updateStatusOnResponseFromLedger`, and cannot paint Synced. A fabricated UUID does not create the row. Measurabl cannot supply this id at emit today — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #14.

## Out — `HubDocumentSyncingSucceededEvent` / `Failed` / `Pending`

IO uses `taxonomyId`, `transactionPointer`, `status`, `reason`. It ignores `ledgerType`, `organisationId`, and `userId`. Failed / Pending share this shape (`DLTResponseInterface`).

```ts
export interface HubDocumentSyncingSucceededEventPayload {
  ledgerType: HubLedgerTypeEnum;
  transactionType: TransactionTypeEnum;
  taxonomyId: string; // required IO key — data_room_file_taxonomies PK. Without it IO cannot update the file
  transactionPointer: string; // empty + Pending = NotSynced
  hubJobId?: string;
  status: string; // must be Succeed for the badge
  reason: string; // empty string on success
  organisationId?: string;
  userId?: string;
}
```

## Out — `HubSymbolRegisteringSucceededEvent`

Deal connected only. Not the file badge. `userId` / `userEmail` are required on the type; this path has no real IO user. Local `transactions.user_id` uses the sentinel in [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #11 so the pending row can insert. deals-service already writes `userId ?? ''`.

```ts
export interface HubSymbolRegisteringSucceededEventPayload {
  ledgerType: HubLedgerTypeEnum; // NVNM
  transactionType: TransactionTypeEnum;
  dealId: string;
  userId: string;
  userEmail: string;
  organisationId: string;
  transactionId: string;
  hubJobId?: string;
  status: DLTOperationStatuses;
  symbol?: string; // NVNM registry id; deals-service throws if missing
  taxonomyId?: string;
}
```

## Related pages

- [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md)

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md)
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md)
- [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md)
- [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md)
- [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #14
- [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md)
