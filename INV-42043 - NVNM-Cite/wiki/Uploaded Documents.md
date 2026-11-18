---
name: Uploaded Documents
date: 2026-08-31T13:41:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Uploaded Documents

**Summary**: Upload file types are one stable set for every court (`.pdf`, `.docx`, `.txt`, `.md`). The app does not consume a per-court filing form. Existence lookup keys on the canonical citation string, not on case name. Case name is only a post-hit heuristic.

**Sources**: [src/nvnm_cite/verifier/extract.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/verifier/extract.py), [src/nvnm_cite/verifier/check.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/verifier/check.py), [docs/canonical-citation-spec.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/canonical-citation-spec.md), [docs/record-schema.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/record-schema.md), [src/nvnm_cite/webapp/static/index.html](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/static/index.html), [src/nvnm_cite/webapp/static/agents.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/static/agents.md) (source: those files)

**Last updated**: 2026-08-31

---

There are two different "formats." Do not mix them.

## 1. File type (stable — not per court)

The Check / Record paths accept the same four types everywhere:

| Type | How text is extracted |
| ---- | --------------------- |
| `.pdf` | pdfplumber; first 400 pages; image-only scans are flagged, never silently treated as "no cites" |
| `.docx` | stdlib zip + Word XML, including footnotes and endnotes |
| `.txt` / `.md` | decode utf-8 / cp1252 / latin-1 |
| paste | treated as `pasted-text.txt` |

(source: extract.py, index.html, agents.md)

The filename extension tells the server how to extract; PDF/`PK` magic is a fallback. Anything else is rejected (`unsupported file type`). There is no court picker and no ECF / state-form parser. A SDNY brief, a SCOTUS merits brief, and a state-court motion go through the same dropzone. (source: extract.py, index.html)

The Verify-a-receipt tab is different: **any file**, hashed in the browser with WebCrypto. The file is never uploaded; only the SHA-256 (and an optional registry #id) leaves the machine. (source: docs/web-demo.md, index.html)

## 2. What must be *inside* the document

The app is not a form. It extracts text, then runs eyecite / the normalizer over that text. It does not require a caption, a table of authorities, or a court-specific cover sheet. (source: check.py)

**Existence lookup keys on the citation, not the case name.** The on-chain `checksum` is the canonical key `<volume> <edition> <first-page>` (e.g. `410 U.S. 113`). A cite that parses to that key can VERIFIED with no party names in the brief at all. (source: docs/canonical-citation-spec.md, docs/record-schema.md)

Case name is extra:

- On chain, metadata carries `name` + `year` (and `cluster`). (source: docs/record-schema.md)
- After a hit, `name_check` does a conservative token overlap between the brief's parties and the registry name. `mismatch` only when they share no significant token. It is a field, not a status. (source: check.py, docs/web-demo.md)

The line "only the case name and citation number are required" is from an **external registry-maintenance** note, not from the Check UI. It describes how new cases might be added to court registries. It does not define lawyer uploads. See [Registry Maintenance](INV-42043%20-%20NVNM-Cite/wiki/Registry%20Maintenance.md). For NVNM-Cite Check: **a recognizable case citation in extractable text is enough.** Case name helps the mismatch heuristic; it is not the lookup key. How lookup works: [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md).

## 3. Citation *as written* does vary by court — the *key* does not

Courts and reporters write citations differently (Bluebook parentheticals, California `Name (Court Year) cite`, state parentheticals, parallel reporters, vendor WL/LEXIS). The normalizer's job is to map those wild strings onto the same first-page key. When it cannot map a court, the row is AMBIGUOUS_JURISDICTION or UNPARSEABLE — not a different upload form. (source: docs/canonical-citation-spec.md)

A citation that maps to a court with no on-chain registry is NOT_COVERED. That is coverage, not a file-format issue. (source: check.py)

## Related pages

- [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md)
- [Registry Maintenance](INV-42043%20-%20NVNM-Cite/wiki/Registry%20Maintenance.md)
- [Open Questions](INV-42043%20-%20NVNM-Cite/wiki/Open%20Questions.md)
- [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md)
- [Audience](INV-42043%20-%20NVNM-Cite/wiki/Audience.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
