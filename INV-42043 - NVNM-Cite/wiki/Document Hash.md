---
name: Document Hash
date: 2026-09-01T06:47:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Document Hash

**Summary**: SHA-256 of the **file bytes** is the receipt’s pointer to “this exact document.” It is not how citations are looked up. The business problem is: prove you ran an existence check on a specific filing, without publishing the brief or its authority list, and without asking anyone to trust NVNM’s word.

**Sources**: [docs/brief-for-firms.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/brief-for-firms.md), [docs/record-schema.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/record-schema.md), [README.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/README.md) (source: those files)

**Last updated**: 2026-09-01

---

## The business problem

A check in a drafting tool is easy to deny later: “we never ran it,” or “we ran it on a different draft.” Courts, opposing counsel, and carriers then have to trust a vendor screenshot.

The product’s second job is a **filing receipt**: a permanent, independently replayable record that *this* document was citation-checked at a stated chain height, against named court registries, by a named wallet. (source: docs/brief-for-firms.md)

## Why a hash (not the file, not the cite list)

| Need | What the hash does |
| ---- | ------------------ |
| Bind the exact bytes | Change one character → different SHA-256 → old receipt no longer matches |
| Keep the brief off chain | Only 64 hex chars go on chain (`checksum` of the receipt record) |
| Keep authorities private | Receipt has a status *tally*, never the cited cases (invariant 7) |
| Let a skeptic verify | Anyone with the filed file hashes it locally and looks up that hex. Verify tab never uploads the file. |

(source: README.md, docs/record-schema.md, docs/web-demo.md)

Check itself does **not** need this hash. Check uses plaintext citation keys. [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md). Hashing happens when you **Record** a receipt (or when someone **Verifies** one).

## Related pages

- [How Check Finds Citations](INV-42043%20-%20NVNM-Cite/wiki/How%20Check%20Finds%20Citations.md)
- [Canonical Citation](INV-42043%20-%20NVNM-Cite/wiki/Canonical%20Citation.md)
- [Authentication](INV-42043%20-%20NVNM-Cite/wiki/Authentication.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
