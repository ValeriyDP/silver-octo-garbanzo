---
name: Automatic Anchoring
date: 2026-11-11T11:44:00.000Z
tags:
  - autosync
  - inv-43944
  - wiki
---

# Automatic Anchoring

**Summary**: Organisation setting that writes each new checksum in an active deal to the Inveniam chain with no Anchor click. Organisations in `io_hub_organisation_map` are out of autosync.

**Sources**: INV-43944 task description, 2026-11-09. Correction 2026-11-11. Application: `inveniam.io`.

**Last updated**: 2026-11-11

---

An organisation admin turns the toggle on under Settings → Blockchain. It starts off. When several chains are connected, only the Inveniam chain can be selected. The other connected chains are shown and disabled.

From that moment, a new checksum in an active deal with a connected ledger is written to the Inveniam chain once. Nobody clicks Anchor. Documents already in the organisation are not submitted (INV-43063). An identical checksum that is already anchored is not submitted again. An inactive deal, or a deal with no connected ledger, is not submitted.

Turning the toggle off stops new automatic writes. A write already accepted finishes. Manual Anchor still works.

A write that fails because the connection was lost or the balance ran out leaves the document unverified. The reason is recorded. The toggle stays on. There is no Failed DLT status.

An organisation in `io_hub_organisation_map` is out of autosync. This listener does nothing for that organisation (INV-42558). The Measurabl branch is merged. That flow is not functional yet. The exclusion does not depend on it.

Out of this feature: documents already in the organisation, a second chain, data-room or portfolio scope, Merkle batching, an MCP tool.

## Related pages

- [Two Auto Anchor Paths](Two%20Auto%20Anchor%20Paths.md)
- [Upload Trigger](Upload%20Trigger.md)
- [Open Questions](Open%20Questions.md)
- [Wiki Index](index.md)
