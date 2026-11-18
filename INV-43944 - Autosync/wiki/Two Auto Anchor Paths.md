---
name: Two Auto Anchor Paths
date: 2026-11-09T14:35:00.000Z
tags:
  - autosync
  - inv-43944
  - wiki
---

# Two Auto Anchor Paths

**Summary**: Measurabl-like organisations anchor through `ClientDLTTransaction`. Every other organisation anchors through the general sync, and only when the toggle is on.

**Sources**: INV-43944 task description; [Measurabl Provisioning Product](../../INV-42559%20-%20Measurabl%20provision/wiki/Measurabl%20Provisioning%20Product.md); investigation 2026-11-09.

**Last updated**: 2026-11-09

---

| Organisation | Gate | Path |
| --- | --- | --- |
| Measurabl-like | Row in `io_hub_organisation_map` | `ClientDLTTransaction` only. IO Hub Service establishes the portfolio Identity, the registry if missing, then `addRecord`. |
| Every other organisation | Toggle on, and no row in `io_hub_organisation_map` | The general sync, the same request Metachain already uses on upload, aimed at the Inveniam chain. |

Hub organisation setup and HubKeys for the second path stay manual, at organisation level. The signing wallet is the organisation wallet. There is no portfolio Identity and no wallet drifting on that path.

L2 or L1 is out of scope. That choice belongs to THE HUB.

`FDRAutoSyncInitEvent` today also starts `requestClientDltTransaction` for any room with an organisation and a portfolio. That creates an NVNM taxonomy in `Pending` and emits `ClientDLTTransaction` for organisations that are not in `io_hub_organisation_map`. Those organisations belong on the general path.

## Related pages

- [Automatic Anchoring](Automatic%20Anchoring.md)
- [Upload Trigger](Upload%20Trigger.md)
- [Pending Taxonomy Concurrency Lock](Pending%20Taxonomy%20Concurrency%20Lock.md)
- [Wiki Index](index.md)
