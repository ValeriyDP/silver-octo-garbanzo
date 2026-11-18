---
name: ADR-0006 Separate Scoped Hub Key Modal
date: 2026-08-22T00:00:00.000Z
tags:
  - hub-keys
  - inv-42086
  - inveniam-v2
  - scoped-keys
  - architecture
  - adr
---

# ADR-0006 Separate Scoped Hub Key Modal From Org Settings

- **Status**: Accepted
- **Date**: 2026-08-22
- **Area**: inveniam-v2 UI
- **Ticket**: `INV-42086` (branch `INV-42086-hub-keys-everywhere`)
- **Related**: [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md), [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md), [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)

## Context

Scoped (below-org) hub keys started out reusing the org-level `AddLedgerViaHubkeyModalComponent`. To satisfy [ADR-0005](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md) the shared modal grew scope-aware branches: an `isScopedHubKey` computed, a filtered `ledgerOptions`, a guarded file auto-select, a disabled ledger control, and a `getRawValue()` submit. All of that scoped logic lived **inside the org settings modal**.

The scoped feature is **experimental** and likely to change or be dropped. Threading its behaviour through the org modal means:

- Every scoped tweak edits a component the org settings page also depends on (risk of regressions to a stable surface).
- The org modal carries conditionals that are dead weight for its own (org-only) use.
- "Remove the experiment" would be a careful surgical edit rather than deleting a folder.

## Decision

Give scoped hub keys their **own representation** and keep it isolated from the org modal.

- New experimental block `packages/browser/features/hub-integration-settings/src/lib/scoped/`:
  - `AddScopedLedgerViaHubkeyModalComponent` — its own template/styles. Scoped keys are `NVNM`-only (ADR-0005), so there is **no ledger picker**: the ledger is fixed to `NVNM` and shown read-only. No org tokenization `patch` side effect.
  - `openAddScopedHubKeyModal(modalService, { scope, destroyRef })` — the scoped opener.
  - `index.ts` barrel; re-exported from the feature's public `index.ts` behind an "EXPERIMENTAL … safe to drop as a unit" comment.
- The org-level `AddLedgerViaHubkeyModalComponent` and `openAddHubKeyModal` are reduced to an **org-only** modal: the ADR-0005 scope branches are removed (full ledger list, always tokenization patch), and their data/opener `scope` is narrowed to `{ organisationId: string }` — no `HubKeyScope`, no `isOrgOnlyHubKeyScope`, so scoped ids can't even be passed in.
- Scoped call sites switch openers: `portfolios-tree`, `deal-header`, `dataroom-title-bar` → `openAddScopedHubKeyModal`. The org call site (`ledger-settings-page`) keeps `openAddHubKeyModal`.
- Shared low-level pieces (`helpers` file validators, `readFileAsJson`, `types`, `fixtures`, and `OrganisationIntegrationSettingsApiService.hubKey`, which already routes by scope) stay shared — they are generic and their reuse does not couple the two views.

This **supersedes the inveniam-v2 (UX guard) portion of [ADR-0005](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)** (the shared-modal filtering / disabled control). ADR-0005's rule — scoped is `NVNM`-only — and its **hub-service** body guard remain in force; the scoped modal simply enforces it by construction.

## Alternatives considered

- **Keep the shared modal with `@if` scope branches** — rejected: couples an experiment to the stable org surface; removal/iteration is risky.
- **Config-driven single modal (mode input)** — still one component owning both flows; the org path keeps paying for scoped complexity.
- **Duplicate everything including helpers/API** — unnecessary; the generic helpers and the scope-routing `hubKey` service are not scoped-specific, so sharing them adds no coupling to the view.

## Consequences

- **Positive**: the org settings modal is back to a clean org-only component; scoped can evolve or be deleted as a self-contained block (delete `lib/scoped/`, drop its barrel export, revert three call sites); the scoped view is simpler (no picker) and can't accidentally offer a non-`NVNM` ledger.
- **Trade-offs**: some modal scaffolding (file input, drop overlay, submit) is duplicated between the two components — intentional, and the price of isolation for an experimental feature.
- **Follow-ups**: if scoped graduates from experimental, revisit whether the two modals should reconverge.

## Affected code

| Path | What changed |
| ---- | ------------ |
| `inveniam-v2/.../hub-integration-settings/src/lib/scoped/**` | new experimental block: scoped modal component + view + `openAddScopedHubKeyModal` + barrel |
| `inveniam-v2/.../hub-integration-settings/src/index.ts` | re-export the scoped block |
| `inveniam-v2/.../add-ledger-via-hubkey-modal.component.ts` + `.spec.ts` | reduced to org-only: scope narrowed to `{ organisationId }`, always patches, no `HubKeyScope`/`isOrgOnlyHubKeyScope`; obsolete below-org spec removed, 3-arg `hubKey` assertion kept |
| `inveniam-v2/.../hub-integration-settings/src/lib/open-add-hub-key-modal.ts` | org opener `scope` narrowed to `{ organisationId }` |
| `inveniam-v2/.../deals/.../portfolios-tree.component.ts` (+ spec) | use `openAddScopedHubKeyModal` |
| `inveniam-v2/.../deals/.../deal-header.component.ts` (+ spec) | use `openAddScopedHubKeyModal` |
| `inveniam-v2/.../dataroom/.../dataroom-title-bar.component.ts` (+ spec) | use `openAddScopedHubKeyModal` |

## Related

- [ADR-0005 Restrict Scoped Hub Keys To NVNM](ADR-0005%20Restrict%20Scoped%20Hub%20Keys%20To%20NVNM.md)
- [ADR-0001 Scoped Add HUB Key](ADR-0001%20Scoped%20Add%20HUB%20Key.md)
- [INDEX](Hub%20Keys%20Everywhere%20(INV-42086)/INDEX.md)
