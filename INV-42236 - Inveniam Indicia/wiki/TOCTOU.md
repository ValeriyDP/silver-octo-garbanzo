---
name: TOCTOU
date: 2026-09-01T13:34:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - architecture
---

# TOCTOU

**Summary**: Time-Of-Check to Time-Of-Use — a race between “I looked, it was fine” and “I acted on that look.” In this repo it is why whole-tenant offboard is not an API yet.

**Sources**: `DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md` D3d; `SECURITY_ASSESSMENT_2026-08-14_BACKLOG.md` (`internal-keyvault-1`); `API_SPECIFICATION.md` (erasure door, “not available”); `SECURITY.md`.

**Last updated**: 2026-09-03 (freeze = company graveyard first, [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md))

---

The check and the use are not one atomic step. Something else can change the world in the gap, so the action runs on stale facts.

```
1. Check  — list subjects / “file exists” / “user is allowed”
        ⋮  ← another request lands here
2. Use    — destroy those keys / open the file / do the privileged thing
```

## Here: tenant offboard

`OffboardTenant` / `PurgeTenant` walk “all subjects in this tenant” and disable or destroy their Vault Transit keys (source: `SEPARATION_OF_CONCERNS_SLICE_2A_KEYVAULT.md`, `internal-keyvault-1`).

```
list subjects → destroy key 1 → destroy key 2 → …
                    ↑
         a new ingest can mint subject N+1 here
```

The list was true at T0. Destroy runs at T1. A subject created in the window is a leftover: the tenant looks offboarded, but that key is still decryptable (source: D3d; method doc comments cited by `internal-keyvault-1`).

Closing it is the same graveyard as person-forget: **company row + `SADD` first**, then walk the list ([ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) §3b). Ingest checks company before person. **Out of this feature** ([Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md) #7): no company API in this delivery. Sequence: [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md) diagrams 1–2.

This is finding `internal-keyvault-1`: **CONDITIONAL**, inert until a production caller exists. Close it in the same change that adds that caller (source: `SECURITY_ASSESSMENT_2026-08-14_BACKLOG.md`).

## Related pages

- [New Developer Onboarding](New%20Developer%20Onboarding.md)
- [Core and Sidecar](Core%20and%20Sidecar.md)
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md)
- [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- [ADR-0002 Forget Table Before Cache](../decisions/ADR-0002%20Forget%20Table%20Before%20Cache.md)
- [ADR-0001 Acknowledged Sidecar Cache Purge](../decisions/ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md)
- [Wiki Index](INV-42236%20-%20Inveniam%20Indicia/wiki/index.md)
- [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md)
- [Decision register](../decisions/INDEX.md)
