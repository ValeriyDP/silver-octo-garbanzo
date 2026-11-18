---
name: Repository Docs
date: 2026-09-01T12:05:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - index
---

# Repository Docs

**Summary**: The Inveniam Indicia repo already has a large `docs/` tree. It is indexed in place as qmd collection `inveniam-indicia-docs`. Do not copy those files into `wiki/` or `raw/`.

**Sources**: `docs/README.md` in `/Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia`

**Last updated**: 2026-09-01

---

Query with `-c inveniam-indicia-docs`. This investigation's own notes stay in `inveniam-indicia`. Go source is `inveniam-indicia-code` (path finder only). See [CLAUDE](../CLAUDE.md).

## Map

| Area | Path | What is there |
| ---- | ---- | ------------- |
| API | `docs/api/` | Endpoint spec (`API_SPECIFICATION.md`) and internal pipeline (`ARCHITECTURE.md`) |
| Guides | `docs/guides/` | Getting started, env vars, admin UI, NVNM smoke test, verification recipe |
| Standards | `docs/standards/` | Go coding standards |
| DevOps | `docs/devops/` | Topology, CI, security, keyvault storage, Azure handoff, capacity, immudb, performance |
| Features | `docs/feature_summaries/` | Batching, Merkle anchoring, batch status worker, ops, idempotency, company admin, FusionAuth, stack |
| Plans | `docs/plans/` | Separation-of-concerns specs, crypto-shred, sidecar, RBAC/erasure decisions, security assessments, backlogs |
| Handoffs | `docs/handoffs/` | Point-in-time onboarding notes (disposable; durable decisions live under `plans/`) |
| Ideas | `docs/new ideas/` | Unscheduled wishlist / strategy notes |

Provenance note in `docs/README.md`: the repo began 2026-08-17 as a fresh-history import. `plans/` citations to older PRs or commits are historical and not resolvable here.

## Related pages

- [Wiki Index](Inveniam%20Indicia%20(INV-42236)/wiki/index.md)
- [New Developer Onboarding](New%20Developer%20Onboarding.md)
- [Core and Sidecar](Core%20and%20Sidecar.md)
- [BYO Producer](BYO%20Producer.md)
- [Open Questions](Inveniam%20Indicia%20(INV-42236)/wiki/Open%20Questions.md)
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](TOCTOU.md)
- [Project README](../README.md)
- [CLAUDE](../CLAUDE.md)
