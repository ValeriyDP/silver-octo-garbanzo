---
name: Canonical Citation
date: 2026-09-01T06:29:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Canonical Citation

**Summary**: The on-chain / lookup key is always `<volume> <edition> <first-page>` with one ASCII space (e.g. `410 U.S. 113`). Wild spellings in a brief are cleaned and mapped to that key. Pin cites, case names, and court parentheticals are not part of the key. Spec: `cite-canonical/v1` in the app repo.

**Sources**: [docs/canonical-citation-spec.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/canonical-citation-spec.md), [src/nvnm_cite/normalizer/canonical.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/normalizer/canonical.py) (source: those files)

**Last updated**: 2026-09-01

---

This page was missing from the wiki until now. [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md) only named the shape. The conversion rules live in the app spec (`cite-canonical/v1`). Full text: `nvnm/nvnm-cite/docs/canonical-citation-spec.md`. Goldens: `tests/golden/normalizer/`.

## The standard form

```
<volume> <edition> <first-page>
```

One space, no padding. Edition is the reporters-db string (`F.3d`, `U.S.`, `S. Ct.`, `L. Ed. 2d`). Leading zeros drop when the token is all digits. (source: spec §1)

That string is the chain `checksum`. Case name is metadata only.

## Wild → standard (keying)

| As written | Canonical key | What happened |
| ---------- | ------------- | ------------- |
| `410 U.S. 113` | `410 U.S. 113` | already standard |
| `410 U. S. 113` | `410 U.S. 113` | extra spaces in edition |
| `925 F. 3d 1339` | `925 F.3d 1339` | `F. 3d` → `F.3d` |
| `181 L.Ed.2d 911` | `181 L. Ed. 2d 911` | edition spelling to reporters-db |
| `5 U.S. (1 Cranch) 137` | `5 U.S. 137` | nominative dropped |
| `Roe v. Wade, 410 U.S. 113, 116 (1973)` | `410 U.S. 113` | name, pin `116`, year dropped |
| `410\nU. S. 113` (PDF line break) | `410 U.S. 113` | `all_whitespace` clean |
| `__410 U.S. 113__` | `410 U.S. 113` | underscore markup stripped |

(source: spec §§1–2)

**First-page rule.** Interior / pin pages are never keys. A fake cite that lands inside a real opinion (`925 F.3d 1339` inside *J.D. v. Azar*, 925 F.3d 1291) misses honestly. (source: spec §1.3)

**No page → no key.** `___ U.S. ___` is unresolved, never guessed. (source: spec §1.3)

## Short forms (`id.`, `supra`, `410 U.S. at 120`)

They have no first page. They inherit the antecedent’s key in the same document. If eyecite strands a short (`NIFLA, 138 S. Ct. at 2371`), a fallback attaches it to the same volume+edition full cite whose first page is the largest not past the pin. No candidate → unresolved, not dropped. (source: spec §3)

## What is *not* a case key

| Form | What the app does |
| ---- | ----------------- |
| `42 U.S.C. § 1983`, journals | out of scope (not case cites) |
| `§2000d` fragments | out of scope, not UNPARSEABLE |
| `2019 WL 1439098` / generic LEXIS | vendor — NOT_COVERED, no chain read |
| NC withdrawn universals (`2021-NCSC-165`) | out of scope (normalizer 1.4.0) |

(source: spec §§4–5)

## Parallels

`558 U.S. 310` and `130 S. Ct. 876` are **two keys**, two records, same CourtListener cluster. The UI may group them as one authority; the chain does not merge them. (source: spec §6)

## Court / registry (not the key)

Parentheticals (`11th Cir.`, California `Name (Court Year) cite`) pick **which registry** to read. They do not change the key string. Bare `F.3d` with no court → key is still computed, registry is **AMBIGUOUS** (never guess). Mapping rules are long (state parentheticals, family sweeps); they bump `NORMALIZER_VERSION`, not `cite-canonical-v1`. See spec §4 and [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md).

Where eyecite and the spec disagree, **the spec wins**. (source: spec §8)

## Related pages

- [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md)
- [Eyecite](NVNM-Cite%20(INV-42043)/wiki/Eyecite.md)
- [Uploaded Documents](NVNM-Cite%20(INV-42043)/wiki/Uploaded%20Documents.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
