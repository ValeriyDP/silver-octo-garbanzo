---
name: Taxonomy Id Before Client DLT
date: 2026-09-22T21:58:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# Taxonomy Id Before Client DLT

**Summary**: **Problem to solve.** `ClientDLTTransaction` requires `taxonomyId` and a data-room taxonomy row. Upload does not create that row. The view-file URL has `fileId` + `dealId` only. Measurabl cannot know `taxonomyId` at emit time. Open: [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md) #14.

**Sources**: Live check 2026-09-22 — `GET /dataroom/taxonomies/{fileId}` empty after upload; `view-file/{fileId}?id={dealId}`; `requestChecksumVerification` / `UpdateDataRoomFileTaxonomyCommand`; [Event Payloads](Event%20Payloads.md); [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md).

**Last updated**: 2026-09-22

---

## What we observed

Frontend file URL:

```
/view-file/{fileId}?id={dealId}
```

Example: `/view-file/04221f59-ffc2-48a6-9dbf-3cf15a8b3ad9?id=9947de6d-c635-4fe8-8bd0-5fb14401f62d`. Path = `data_room_files.id`. Query `id` = deal. No taxonomy PK.

After upload, `GET http://localhost:8881/dataroom/taxonomies/{fileId}` is empty (`200 []` on the API; hitting `:8880` is the frontend and 404s). No `data_room_file_taxonomies` row yet.

## When the row actually appears

Not after the chain confirms. Not at upload.

IO Sync / `POST /dataroom/taxonomy/create-request/{fileId}` runs `requestChecksumVerification`: **insert taxonomy, then** emit `HubDocumentSyncingRequestedEvent` with that `id`. Blockchain write is later. `HubDocumentSyncingSucceededEvent` → `updateStatusOnResponseFromLedger(taxonomyId)`. Missing row → log and return. Badge does not move.

`ClientDLTTransaction` skips `create-request`. Measurabl has `fileId` / `dealId` / checksum / uri. It does not have a taxonomy PK. Inventing a UUID does not help — data-room looks up by that id.

## Why this blocks the flow

| Contract today | Reality after upload |
| --- | --- |
| Inbound `taxonomyId` required; row must exist | Row does not exist |
| Outbound success keys on `taxonomyId` | No row to update |
| Parked `pending_document` keyed by `taxonomyId` | Same missing key |

This is the same hole as [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md) gap 1, now confirmed on a live file. It is **not** solved. Do not treat `taxonomyId` on [Event Payloads](Event%20Payloads.md) as usable for Measurabl until #14 closes.

## Variants (not chosen)

| | Approach | Note |
| --- | --- | --- |
| A | Mint taxonomy in IO first (`create-request` or a mint-only API), then emit ClientDLT with that `id` | Today's `create-request` also starts the old Hub sync path |
| B | Key ClientDLT on `fileId`; data-room creates/updates the NVNM taxonomy on success | Identity Measurabl already has |
| C | Keep `taxonomyId` if present; else resolve/create by `fileId` + NVNM on the success handler | Hybrid |

Recommend **B or C**. Promote to an ADR when someone picks.

## Related pages

- [Wiki Index](INV-42559%20-%20Measurabl%20provision/wiki/index.md)
- [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md) #14
- [Open Questions Agenda](Open%20Questions%20Agenda.md)
- [Event Payloads](Event%20Payloads.md)
- [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md)
- [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md)
