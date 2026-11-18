---
name: Investigation Brief
date: 2026-10-02T12:05:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
---

# Investigation Brief

**Summary**: INV-42833 is a feasibility study: can Metachain events be anchored on NVNM Chain, as part of raising NVNM usage. Deliverable is an integration options paper plus a roadmap — not a code change.

**Sources**: [Metachain task](../raw/Metachain%20task.md)

**Last updated**: 2026-10-02

---

## Goal

There is an over-arching topic of raising NVNM Chain usage. The idea under test: take events that today go to Metachain and put them on NVNM Chain. The source uses both **“anchor”** and **“put all events onto”** — those are different designs. This wiki captures current-state facts first; a later ADR picks the design. (source: Metachain task.md)

## Acceptance criteria

1. Review documentation.
2. Analyze whether Metachain events can be anchored on NVNM Chain.
3. Check with the Gadget team whether this overlaps what they are implementing for immudb (source link is empty).
4. If needed, discuss with Urvish Patel (Roquefort) for technical details.
5. Produce a document that presents a possible integration and an implementation roadmap.

## People

| Who | Why |
| --- | --- |
| Gadget team | Possible overlap with immudb work |
| Urvish Patel (Roquefort) | Technical details if the code/docs are not enough |

## Application repo

- `~/work/inveniam/inveniam.io`

## Related pages

- [Wiki Index](Metachain%20(INV-42833)/wiki/index.md)
- [Open Questions](Metachain%20(INV-42833)/wiki/Open%20Questions.md)
- [Metachain Ownership And Infrastructure](Metachain%20Ownership%20And%20Infrastructure.md)
- [Metachain Write Path](Metachain%20Write%20Path.md)
- [Payload Comparison Metachain vs NVNM](Payload%20Comparison%20Metachain%20vs%20NVNM.md)
- [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md)
