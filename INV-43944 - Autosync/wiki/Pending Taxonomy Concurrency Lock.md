---
name: Pending Taxonomy Concurrency Lock
date: 2026-11-09T14:35:00.000Z
tags:
  - autosync
  - inv-43944
  - wiki
---

# Pending Taxonomy Concurrency Lock

**Summary**: `Pending` on a taxonomy is a lock against a second sync of the same checksum. Data-room has no retry for that status. A stuck `Pending` row is the Anchor 409.

**Sources**: `taxonomy-functional.service.ts` (`canReturnPreviousTaxonomyPayload`, `getFileDLTStatuses`); `request-data-room-file-taxonomy-dlt.command.ts`; `error-messages.constants.ts` (`FILE_ALREADY_SYNCED`).

**Last updated**: 2026-11-09

---

`canReturnPreviousTaxonomyPayload` matches the latest taxonomy for that file and ledger when the checksum is equal and the status is `Pending` or `Succeed`. The handler then sets `isSyncNeed` to false. Unless the file view is `NotSynced` and the taxonomy is already `Succeed`, it throws 409 `FILE_ALREADY_SYNCED`: "file has been synced. Please reload the page". The UI shows every 409 from that call as "currently being synced by a different user."

No user is compared. There is no timeout. The lock opens only when a later event changes the status.

`Succeed` means that checksum is already anchored. `Pending` is the concurrency lock. The Anchor click does not create a new taxonomy and does not call `write()`.

`Failed` is outside the check. The next click creates a new taxonomy and submits again.

A `Pending` taxonomy with an empty `transactionPointer` is shown as `NotSynced` and stays locked. IO Hub Service polls a job only after `write()` has stored a `transactions` row. `ResendTransactionCommand` resends that hub transaction. The file screen does not call it for a `Pending` taxonomy. A row that never receives a success or failure event stays locked.

For this feature the `Pending` arm of that check has to be relaxed so a manual Anchor reaches `write()`. The `Succeed` arm stays. A checksum already anchored is not submitted again.

## Related pages

- [Upload Trigger](Upload%20Trigger.md)
- [Second Write](Second%20Write.md)
- [Wiki Index](index.md)
