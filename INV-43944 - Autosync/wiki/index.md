---
name: Wiki Index
date: 2026-11-11T11:44:00.000Z
tags:
  - autosync
  - inv-43944
  - wiki
  - index
---

# Wiki Index

Knowledge base for **Autosync (INV-43944)**. How-tos, diagrams, current state, open questions.

Decisions live in [decisions/INDEX](../decisions/INDEX.md). Cross-link; do not copy ADRs here.

## Pages

- [Automatic Anchoring](Automatic%20Anchoring.md) — Toggle contract. New checksum in an active deal, Inveniam chain only. Organisations in `io_hub_organisation_map` are out of autosync.
- [Two Auto Anchor Paths](Two%20Auto%20Anchor%20Paths.md) — `ClientDLTTransaction` for `io_hub_organisation_map`. General sync for every other organisation.
- [Upload Trigger](Upload%20Trigger.md) — `FDRAutoSyncInitEvent` stays Metachain. A second event fires only when the toggle is on.
- [Pending Taxonomy Concurrency Lock](Pending%20Taxonomy%20Concurrency%20Lock.md) — `Pending` blocks a second sync. No retry. The Anchor 409.
- [Second Write](Second%20Write.md) — `hubJobId` arrives after THE HUB accepts the write. A second request is a second chain write.
- [Open Questions](Open%20Questions.md) — Toggle storage. Shape of the automatic taxonomy row.

## Related

- [Project README](../README.md)
- [CLAUDE](../CLAUDE.md)
