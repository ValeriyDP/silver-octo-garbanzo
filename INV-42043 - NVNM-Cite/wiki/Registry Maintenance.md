---
name: Registry Maintenance
date: 2026-08-31T13:43:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Registry Maintenance

**Summary**: The external quote about "only the case name and citation number" is about **adding cases to court registries**, not about lawyer uploads. Shipped code does an initial bulk load plus a CourtListener incremental updater. That is not a two-field bot, and a "citation number" is not the on-chain key.

**Sources**: [raw/Registry Maintenance Excerpt](NVNM-Cite%20(INV-42043)/raw/Registry%20Maintenance%20Excerpt.md), [src/nvnm_cite/loader/update.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/loader/update.py), [docs/record-schema.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/record-schema.md), [IMPLEMENTATION_PLAN.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/IMPLEMENTATION_PLAN.md) (source: those files)

**Last updated**: 2026-08-31

---

## The quote (external)

> Registry maintenance: The initial population used a bulk upload. Near-term updates will use an automated bot; only the case name and citation number are required. A...t expects to deliver a prototype within one week, with up to 50 new cases per week.

(source: raw/Registry Maintenance Excerpt.md)

Full document title and author are unknown. "A...t" is truncated in the excerpt (possibly Albert — unverified).

This is **ops for the court registries**. It is not the Check-tab upload contract. Lawyer documents are a different path: [Uploaded Documents](NVNM-Cite%20(INV-42043)/wiki/Uploaded%20Documents.md).

## What the quote claims

| Claim | Meaning |
| ----- | ------- |
| Initial population = bulk upload | One-shot load of the corpus onto the chain |
| Near-term updates = automated bot | Ongoing appends without another full load |
| Bot input = case name + citation number | A thin intake, not a full CourtListener cluster |
| Cadence = prototype in a week, ≤50 new cases/week | Small incremental volume |

## What the code does today

**Initial population.** CourtListener bulk data → export → chain load. Mainnet corpus was written in the 2026-07-30 anchoring v1.2.0 upgrade block: 2,114 court registries, ~11.94M records. (source: CLAUDE.md, IMPLEMENTATION_PLAN.md)

**Near-term updates.** `nvnm-cite update` (`loader/update.py`): CourtListener REST v4, clusters paged by `date_modified`, append-only into the same checkpoint DB as the bulk loader, then optional `--submit` to chain (writes default to testnet). Needs `COURTLISTENER_TOKEN`. (source: update.py)

The updater does **not** take a human pair `(case name, citation number)`. It consumes CL cluster objects and renders the locked v1 record. (source: update.py, records.py)

**What a registry write actually stores** (locked schema, not two fields):

| Field | Value |
| ----- | ----- |
| `checksum` | Canonical key `<volume> <edition> <first-page>` (e.g. `410 U.S. 113`) — plaintext, not a docket/"citation number" |
| `checksumAlgo` | `cite-canonical-v1` |
| `uri` | CourtListener cluster URL |
| `metadata` | `{"cluster":…,"name":…,"year":…}` |

(source: docs/record-schema.md)

Year may be omitted when CL has no `date_filed`. Collision form uses a `cases` array. Daily update does **not** merge collisions or correct existing metadata — that stays a quarterly bulk + reconcile job. (source: update.py)

## How to read the quote against the code

- "Citation number" in the quote is looser than the product key. The chain keys on volume + reporter edition + first page. A docket number or a bare page is not enough.
- Case name is **metadata**, not the lookup key. The same distinction as Check: existence is the citation string. (source: docs/record-schema.md)
- "50 new cases per week" is a prototype cadence from the excerpt. It does not describe the live mainnet corpus size or the current updater's CL-scan volume. An update / crawl bot can be designed later — [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md) Q3 (closed 2026-09-01).

## Related pages

- [Uploaded Documents](NVNM-Cite%20(INV-42043)/wiki/Uploaded%20Documents.md) — lawyer file types; do not confuse with this page
- [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md) — Q4: CourtListener token / paid vs crawl
- [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
