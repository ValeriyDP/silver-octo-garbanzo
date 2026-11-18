---
name: Onboarding
date: 2026-09-01T07:01:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - guide
---

# Onboarding

**Summary**: First-day map of NVNM-Cite: who the product is for, what to hold in your head before opening the code, and how to boot it on this machine.

**Sources**: [README.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/README.md), [docs/brief-for-firms.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/brief-for-firms.md), [docs/web-demo.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/web-demo.md), [docs/record-schema.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/record-schema.md), [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md), [Document Hash](INV-42043%20-%20NVNM-Cite/wiki/Document%20Hash.md) (source: those files)

**Last updated**: 2026-09-01T07:01:00.000Z

---

A lawyer can do two things, and only these two. **Check** asks whether each citation *in the brief* is a real published first-page key in the court registries on NVNM Chain (CourtListener-derived corpus) — not “did this case exist in all of legal history,” not good law, not “does it support my argument,” and not cites “in the receipt” (receipts do not list cases). A miss can be a fake or a real case the corpus never got. **Record** binds a SHA-256 of *one exact file version* plus provenance (block, registries, wallet). It does not store the brief or prove the document “never changed over time”; if the bytes change, the receipt no longer matches. [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md), [Document Hash](INV-42043%20-%20NVNM-Cite/wiki/Document%20Hash.md).

NVNM-Cite never claims a case supports a proposition or is good law. Provenance, not truth. (source: README.md, docs/brief-for-firms.md)

### Check, then Record (what “lock” means)

Check first, Record second. Check does not write a hash. Record is how you bind one exact file version to a receipt. “Lock” here is only that bind — not storing the brief, and not freezing it from later edits.

**Check** does not hash anything. It reads the brief, pulls citations, and asks the court registries whether those keys exist. You can do that on as many drafts as you want. (source: docs/web-demo.md, [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md))

**Record** hashes *this exact file* (SHA-256 of the bytes, in the browser), then writes that hex to a per-firm-per-case receipt registry, signed by your wallet. The brief itself never goes on chain. The receipt also stores provenance (chain, block, which court registries were read, a status *count*, wallet) — not the list of cases. (source: docs/record-schema.md, docs/web-demo.md, [Document Hash](INV-42043%20-%20NVNM-Cite/wiki/Document%20Hash.md))

“Lock” means: **this exact byte sequence was citation-checked at this height, against these registries, by this wallet.** Anyone later can hash the same file locally (Verify never uploads it) and look up that hex.

What it does **not** mean:

- The brief is stored or frozen on chain.
- The file cannot be edited. Edit one character → new hash → old receipt no longer matches. That is the point: the receipt is a fingerprint of one version, not a claim that the document never changed over time.
- The receipt lists which cases you cited. It only has a tally (how many VERIFIED / NOT_FOUND / …).

Typical use: check while drafting; when the filing is the one you will stand behind, Record that version. If you file a later edit, you Record again — the old receipt still exists, it just no longer matches the new bytes.

Code: `/Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite`. Public site: https://nvnmcite.com (source: pyproject.toml, docs/DEPLOYMENT.md).

## Read these three pages

| Question | Page |
| -------- | ---- |
| For whom? | [Audience](INV-42043%20-%20NVNM-Cite/wiki/Audience.md) |
| What should I know beforehand? | [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md) |
| How do I start it locally? | [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md) |

## The one-line product

> Confirms cited cases are real and gives a permanent, independently verifiable receipt that you checked — without publishing the brief or asserting anything it cannot prove. (source: docs/brief-for-firms.md)

## Fastest first hour

1. Read [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md) (especially the invariants).
2. Follow [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md) (`uv` or the repo `Dockerfile`) and open http://127.0.0.1:8787.
3. Drop in the committed Mata fixture (`tests/fixtures/briefs/extracted/mata-avianca-nysd-ecf24-reply-memo.txt`). The invented *Varghese* cite should come back NOT_FOUND. (source: docs/web-demo.md)

You do **not** need a wallet, a `.env`, or a database to check a brief. Those matter only when you write to the chain or run corpus-loader commands. (source: docs/DEPLOYMENT.md, .env.example)

## Related pages

- [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md)
- [Document Hash](INV-42043%20-%20NVNM-Cite/wiki/Document%20Hash.md)
- [Canonical Citation](INV-42043%20-%20NVNM-Cite/wiki/Canonical%20Citation.md)
- [Audience](INV-42043%20-%20NVNM-Cite/wiki/Audience.md)
- [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md)
- [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md)
- [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
- [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md)
