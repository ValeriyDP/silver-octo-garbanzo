---
name: Eyecite
date: 2026-09-01T06:08:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Eyecite

**Summary**: Eyecite is a Free Law Project **Python** library that finds legal citations in text and ties short forms (`id.`, `supra`) back to a full cite. NVNM-Cite's normalizer is a thin, versioned wrapper around it. It is not a citator and it does not talk to the chain.

**Sources**: [eyecite docs](https://github.com/freelawproject/eyecite), [src/nvnm_cite/normalizer/canonical.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/normalizer/canonical.py), [DECISIONS.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/DECISIONS.md) 2026-06-10, [docs/canonical-citation-spec.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/canonical-citation-spec.md) (source: those files)

**Last updated**: 2026-09-01

---

## What it is

A parser. You give it a string (a brief). It returns citation objects: full case cites, short cites, `id.`, `supra`, plus statutes and journals this project then throws away.

Upstream: [github.com/freelawproject/eyecite](https://github.com/freelawproject/eyecite). License BSD-2-Clause. This repo pins **2.7.6**. (source: DECISIONS.md 2026-06-10)

It sits on two other FLP datasets:

| Library | Job |
| ------- | --- |
| **reporters-db** | Reporter abbreviations and edition strings (`F.3d`, `U.S.`) |
| **courts-db** | Court IDs (`ca11`, `scotus`) from parentheticals |

(source: CLAUDE.md, DECISIONS.md)

## What NVNM-Cite calls

```
clean_text  →  get_citations  →  resolve_citations
```

Then the project builds a first-page key: `<volume> <corrected_reporter()> <page>` (e.g. `410 U.S. 113`) and maps a registry. (source: canonical.py)

That is step 2 of [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md). Eyecite never queries NVNM Chain.

## What it is not

- Not a good-law / Shepard's / KeyCite tool
- Not CourtListener's search API (different FLP product)
- Not the upload parser (PDF/DOCX is `extract.py` / pdfplumber)
- Not always right — this repo **compensates** for measured gaps (orphan shorts, `(3d Cir.)`, table-of-authorities overreach). Where eyecite and the spec disagree, the spec wins. (source: docs/canonical-citation-spec.md)

## Is the project built around it?

**For turning a brief into citation keys: yes.** There is one reference normalizer. The rule is: use eyecite / reporters-db / courts-db; never write a parser from scratch. CLI and webapp both call that same core, so there is not a second parser hiding in the UI. (source: CLAUDE.md, check.py)

It is a **wrapper**, not a blind import. The open spec (`cite-canonical/v1`) is the contract. Golden tests pin behavior against eyecite 2.7.6. When eyecite is wrong, this repo patches it and the spec wins.

**For the product as a whole: no.** Existence proof is the keyed chain read. Receipts, wallets, the stdlib signer, and the static page do not go through eyecite. Swap the parser and you still need the same chain key shape — but you would owe a normalizer version bump and a new receipt trail. [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md).

## Why it matters here

CLAUDE.md: never write a citation parser from scratch. The normalizer is in the trust boundary; receipts record `normalizer_version`. That is the inferential reason the app is Python. [Why Python](INV-42043%20-%20NVNM-Cite/wiki/Why%20Python.md).

A TypeScript port exists (`eyecite-js`). This checkout does not use it. (unverified whether it matches 2.7.6 behavior)

## Related pages

- [Canonical Citation](INV-42043%20-%20NVNM-Cite/wiki/Canonical%20Citation.md)
- [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md)
- [Why Python](INV-42043%20-%20NVNM-Cite/wiki/Why%20Python.md)
- [Uploaded Documents](INV-42043%20-%20NVNM-Cite/wiki/Uploaded%20Documents.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
