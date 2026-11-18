---
name: Event Publish Volume
date: 2026-10-05T10:45:00.000Z
tags:
  - metachain
  - inv-42833
  - wiki
  - metrics
---

# Event Publish Volume

**Summary**: Nest microservices generated **3,169,013** broker events from 2026-09-07 through 2026-10-05 (29 UTC days). Daily **median** is **37,552**. Daily **mean** is **109,276**. The mean sits well above the median because a few early-September days are very large (peak **604,833** on 2026-09-09). After 2026-09-17 most days fall in the 14k–43k range.

**Sources**: Elasticsearch `date_histogram` on application logs. Filter: `component` = `NestAwsPubSub`, `msg` = `Event published`. 
**Last updated**: 2026-10-05

---

## Summary statistics

Period: **2026-09-07 → 2026-10-05** (29 days, UTC).

| Metric | Value |
| ------ | ----- |
| Days | 29 |
| Total events | 3,169,013 |
| Mean | 109,276 / day |
| Median | 37,552 / day |
| Min | 14,169 (2026-09-20) |
| Max | 604,833 (2026-09-09) |

Median is the 15th value of the 29 daily counts when sorted. It is **37,552** (2026-09-29).

Typical recent volume is closer to the median than to the mean. The right tail is 2026-09-09, 2026-09-10, 2026-09-14, and 2026-09-23.

## Daily counts

| Date (UTC) | Events |
| ---------- | -----: |
| 2026-09-07 | 119,284 |
| 2026-09-08 | 170,179 |
| 2026-09-09 | 604,833 |
| 2026-09-10 | 311,478 |
| 2026-09-11 | 179,614 |
| 2026-09-12 | 150,119 |
| 2026-09-13 | 141,023 |
| 2026-09-14 | 331,331 |
| 2026-09-15 | 191,260 |
| 2026-09-16 | 194,454 |
| 2026-09-17 | 135,873 |
| 2026-09-18 | 42,050 |
| 2026-09-19 | 14,847 |
| 2026-09-20 | 14,169 |
| 2026-09-21 | 43,217 |
| 2026-09-22 | 35,271 |
| 2026-09-23 | 210,335 |
| 2026-09-24 | 27,811 |
| 2026-09-25 | 18,529 |
| 2026-09-26 | 15,020 |
| 2026-09-27 | 15,178 |
| 2026-09-28 | 26,889 |
| 2026-09-29 | 37,552 |
| 2026-09-30 | 28,754 |
| 2026-10-01 | 25,241 |
| 2026-10-02 | 33,650 |
| 2026-10-03 | 16,166 |
| 2026-10-04 | 15,006 |
| 2026-10-05 | 19,880 |
| **Total** | **3,169,013** |
