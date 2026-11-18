---
name: Open Questions
date: 2026-10-02T12:05:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
---

# Open Questions

**Summary**: Parking lot for things we do not know yet. Promote a question to an ADR in `decisions/` when a design choice is required.

**Sources**: [Metachain task](../raw/Metachain%20task.md); current-state pages in this wiki

**Last updated**: 2026-10-02

---

| # | Question | Notes | Status |
| - | -------- | ----- | ------ |
| 1 | Anchor hashes on NVNM, or write every Metachain event through as an `addRecord`? | Source uses both phrasings. Payloads are not drop-in — see [Payload Comparison](Payload%20Comparison%20Metachain%20vs%20NVNM.md). Promote to ADR when we pick. | open |
| 2 | What is the Gadget / immudb work this might overlap? | Acceptance criteria say “refer to this” with an empty link. Need a ticket, doc, or Slack pointer. | open |
| 3 | Do we need Urvish Patel (Roquefort) for remaining gaps? | After current-state trace: live path is Immudb-only; Accumulate batch cron is commented out; NVNM is hub-owned. Confirm if Roquefort owns Hub/NVNM codec or something else. | open |
| 4 | Which NVNM registry would event hashes land in? | NVNM `addRecord` requires `registryId` (deal `symbol`). Platform events are org-scoped, not file-scoped. No event-shaped ABI today. | open |
| 5 | Volume / cost of per-event EVM writes? | Metachain hashes a large share of `BaseEvent`s. NVNM writes are currently per document sync. Unverified: event rate in prod. | open |

When a row becomes a decision, add the ADR and link it here. Leave the question in place with status `decided` and a link, so the wiki still explains *what we asked*.

## Related pages

- [Wiki Index](INV-42833%20-%20Metachain/wiki/index.md)
- [Investigation Brief](Investigation%20Brief.md)
- [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md)
- [Decision register](../decisions/INDEX.md)
