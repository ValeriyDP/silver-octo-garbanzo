---
name: Why Python
date: 2026-08-31T14:55:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Why Python

**Summary**: There is **no recorded ADR** that compares Python to another language. The day-one plan assumed Python 3.11 + uv. The strongest reason *in the repo* is: do not write a citation parser; build on Free Law Project's **eyecite** (a Python library) plus reporters-db and courts-db.

**Sources**: [docs/ARCHIVE/build-plan-v1-2026-06-09.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/ARCHIVE/build-plan-v1-2026-06-09.md), [DECISIONS.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/DECISIONS.md), [CLAUDE.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/CLAUDE.md), [pyproject.toml](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/pyproject.toml) (source: those files)

**Last updated**: 2026-08-31

---

## What is *not* in the record

No DECISIONS.md entry, plan checkbox, or vault ADR says "we picked Python instead of Go / TypeScript / … because …". Alternatives were not written down. (searched; mark if a source appears later)

## What *is* in the record

**Assumed from the first plan (2026-06-09).** Setup is "Python 3.11+, uv". The data-sources list names **eyecite (FLP Python library)** and says build on it, do not reinvent. Same rule is still in CLAUDE.md: "Build on eyecite / reporters-db / courts-db. Never write a citation parser from scratch." (source: build-plan-v1-2026-06-09.md, CLAUDE.md)

The normalizer is in the **trust boundary**. Receipts record its version. That makes the FLP stack load-bearing, not a convenience dep. (source: CLAUDE.md invariant 5, DECISIONS 2026-06-10 Phase 1 deps)

**The one explicit "Python" user decision is narrower.** Albert chose a **from-scratch pure-Python signer** over the `eth-account` library, and `chain/` stays stdlib-only. That is Python-vs-a-Python-library, not Python-vs-another-language. The draft had already pointed at a missing `evm_signer_v5.py` (also Python). (source: DECISIONS.md 2026-06-10)

**Later choices stayed inside that frame:** stdlib HTTP server (no Flask/FastAPI), no new web runtime, pdfplumber as the PDF extractor, uv.lock pins. (source: DECISIONS.md 2026-06-11 / 2026-06-14)

The UI is already not Python: vanilla JS. [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md).

## Fair inference (not a quote)

Python was the language that could import the one citation stack they refused to rewrite. Everything else (signer, loader, web server) was written to sit next to that.

This investigation **closed** the language question: the project is locked to eyecite (see [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md) Q5, closed 2026-09-01). A later language rewrite would still owe an ADR that deals with invariant 5 (one reference normalizer, versioned on every receipt).

## Related pages

- [Eyecite](NVNM-Cite%20(INV-42043)/wiki/Eyecite.md)
- [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md)
- [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md)
- [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
