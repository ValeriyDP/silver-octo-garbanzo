---
name: How Check Finds Citations
date: 2026-08-31T13:47:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - architecture
---

# How Check Finds Citations

**Summary**: The Check tab does not scan the chain and does not use a court-specific upload form. It extracts citations from the brief's text, maps each one to a court registry + a canonical key, then does a keyed `records(registry_id, citation)` read. One lookup per candidate registry, not a search.

**Sources**: [src/nvnm_cite/verifier/extract.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/verifier/extract.py), [src/nvnm_cite/verifier/check.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/verifier/check.py), [src/nvnm_cite/verifier/resolver.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/verifier/resolver.py), [src/nvnm_cite/normalizer/__init__.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/normalizer/__init__.py), [docs/canonical-citation-spec.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/canonical-citation-spec.md) (source: those files)

**Last updated**: 2026-08-31

---

The site's upload box is only a way to get **text**. After that, the app already knows *where* to look: each citation names its own reporter (and often its court). That is enough to pick a registry and a key.

## The path

```
bytes  →  text  →  citations  →  (registry_id, canonical key)  →  one eth_call each
```

1. **Extract.** `.pdf` / `.docx` / `.txt` / `.md` → in-memory text. Same for every court. [Uploaded Documents](INV-42043%20-%20NVNM-Cite/wiki/Uploaded%20Documents.md). (source: extract.py)
2. **Normalize.** eyecite + the open spec turn the text into occurrences. Each usable cite gets:
   - `as_written` — what the brief said
   - `canonical` — `<volume> <edition> <first-page>` (e.g. `410 U.S. 113`)
   - `registry` — `us-<courts-db id>` (e.g. `us-scotus`, `us-ca11`) from reporter + court parenthetical
   (source: normalizer, docs/canonical-citation-spec.md)
3. **Coverage map.** The pinned manifest (`registry_manifest_*.json`) is name → numeric `#id`. Names are not unique on chain; the id is what the call uses. If the mapped court is not in the manifest → **NOT_COVERED**, no chain read. (source: check.py)
4. **Keyed read.** `records(registry_id, canonical)` via `eth_call` to the anchoring precompile. A miss (`collections: not found`) is **NOT_FOUND**. A dead RPC is an error, never a miss. The exact query is returned so anyone can replay it. (source: resolver.py)
5. **Family sweep (sometimes).** Some editions are split across sibling registries (e.g. Texas / California district families). The verifier tries the routed registry, then same-state candidates, and reports which one answered. Still keyed reads — not a chain-wide search. (source: check.py)

Case name is **not** used to choose the registry or the key. It is only `name_check` after a hit. (source: check.py)

## How it knows "where"

| Signal in the brief | What the app does |
| ------------------- | ----------------- |
| Reporter edition (`U.S.`, `F.3d`, `Cal. App. 5th`) | Maps to a default court / registry family |
| Court parenthetical (`11th Cir.`, `S.D.N.Y.`) | Overrides / corroborates the court |
| Volume + first page | Completes the key. Pin cites are dropped |

If the reporter spans many courts and there is no usable parenthetical (`925 F.3d 1339` with no circuit) → **AMBIGUOUS_JURISDICTION**. The app refuses to guess a registry. (source: docs/canonical-citation-spec.md)

## Statuses (what the UI shows)

| Status | Meaning |
| ------ | ------- |
| VERIFIED | Keyed read returned a record |
| NOT_FOUND | Keyed read missed on a covered registry |
| NOT_COVERED | Court (or vendor cite like WL) is outside the manifest; no read |
| AMBIGUOUS_JURISDICTION | Could not pick a registry |
| UNPARSEABLE | Not a usable case citation |

(source: check.py)

## Not this path

- **Verify a receipt** hashes the file in the browser and looks up the SHA-256 in *receipt* registries. Different upload box, different key.
- **Registry bots / bulk load** put records *onto* the chain. Out of this investigation for now. See [Registry Maintenance](INV-42043%20-%20NVNM-Cite/wiki/Registry%20Maintenance.md) if needed later.

## Related pages

- [Canonical Citation](INV-42043%20-%20NVNM-Cite/wiki/Canonical%20Citation.md) — wild → standard key
- [Eyecite](INV-42043%20-%20NVNM-Cite/wiki/Eyecite.md)
- [Uploaded Documents](INV-42043%20-%20NVNM-Cite/wiki/Uploaded%20Documents.md)
- [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md)
- [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
