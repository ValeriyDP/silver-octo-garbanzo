---
name: Split Branch Into PRs Agent Playbook
date: 2026-09-30T11:41:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - process
  - pr-split
---

# Split Branch Into PRs Agent Playbook

**Summary**: How an AI agent must split `INV-42559-measurabl-anchoring` into six local reviewable PRs, keep the original branch intact, and prove the merged slices still match that branch.

**Sources**: `inveniam.io` branch `INV-42559-measurabl-anchoring`; [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md); [Organisation Provisioning Chain](Hub%20Onboarding%20Chain.md); [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md).

**Last updated**: 2026-09-30

Branch names keep the meaningful slice name and add a `-prN` suffix so the stack order is obvious (`…-pr1`, `…-pr2`, …).

**Repo:** `~/work/inveniam/inveniam.io`  
**Default branch:** `origin/develop`  
**Source of truth (do not rewrite):** `INV-42559-measurabl-anchoring`

A prior split was executed locally and then cleaned. Treat this page as the only remaining instruction. Recreate the slices from the source branch; do not assume leftover worktrees or slice branches exist.

Ignore `INV-42086-hub-keys-everywhere`. It was evaluated and never merged. Everything needed from that work is already on `INV-42559-measurabl-anchoring` (PR1 scoped keys, PR2 deal projector). Do not cherry-pick, merge, or re-implement it.

---

## Hard rules

- Do **not** push, force-push, or open GitHub PRs until the human says to push.
- Do **not** rewrite, reset, or delete `INV-42559-measurabl-anchoring`.
- Do **not** use `git add .` / `git add -A`. Stage named files only.
- Do **not** include local-only junk from the original working tree:
  - `apps/hub-service/src/main.ts` (dirty)
  - `create-org.sh`
  - `docker-compose.override.yml`
  - `apps/metachain-service/root`
- Prefer **git worktrees** so the original checkout and its dirty files stay untouched.
- Snapshot before moving work:

  ```bash
  SHA=$(git stash create "pre-split")
  if [ -n "$SHA" ]; then
    git update-ref "refs/backup/pre-split-$(date +%s)" "$SHA"
  fi
  git update-ref refs/backup/INV-42559-measurabl-anchoring HEAD
  ```

- After every slice is committed, reconstruct by merging onto a fresh branch from `origin/develop` and diff against the original. Feature trees must match.

---

## Why these six slices

The original branch is one pile (~211 files vs `develop`). True independence is limited.

- `OrganizationToHubProvision` stops at the Hub org relation.
- `ClientDLTTransaction` is one pipeline: portfolio → registry → document.
- Sync-doc cannot merge off `develop` alone.

```
Wave 1 (off develop, after PR1 lands)
  PR1 Foundation
  PR2 Deal anchors          (needs PR1 for client-provisioning.log)
  PR6 Deals-service         (independent; merge anytime)

Wave 2
  PR3 Org onboard           (needs PR1 only)

Wave 3 (stacked)
  PR4 Portfolio + registry  (needs PR1 + PR2 + PR3)
  PR5 Sync doc              (needs PR4)
```

Local branch names (required):

| PR | Branch | Base |
| --- | --- | --- |
| 1 | `INV-42559-foundation-measurabl-hub-pr1` | `origin/develop` |
| 2 | `INV-42559-deal-anchors-hub-pr2` | `INV-42559-foundation-measurabl-hub-pr1` |
| 3 | `INV-42559-org-hub-provision-pr3` | `INV-42559-foundation-measurabl-hub-pr1` |
| 4 | `INV-42559-portfolio-registry-pr4` | merge `…-pr2` + `…-pr3` |
| 5 | `INV-42559-sync-doc-pr5` | `INV-42559-portfolio-registry-pr4` |
| 6 | `INV-42559-deals-nvnm-symbol-succeeded-pr6` | `origin/develop` |

Reconstruction check branch: `INV-42559-slices-merged-from-develop`.

When later opening GitHub PRs: PR1 and PR6 against `develop`; PR2 and PR3 against PR1; PR4 against the merged PR2+PR3 base (or `develop` after 1–3 merge); PR5 against PR4.

---

## PR1 — Foundation

**Independent. Base: `develop`.**

Checkout these paths from `INV-42559-measurabl-anchoring` onto a worktree from `origin/develop`:

- `shared-modules/Events/EventsConstants.ts`
- `shared-modules/Events/Hub/IntegrationKeys/hub-set-scoped-integration-keys-complete.event.ts`
- `shared-modules/Events/Hub/IntegrationKeys/hub-set-scoped-integration-keys-failed.event.ts`
- `shared-modules/Events/Hub/IntegrationKeys/index.ts`
- `shared-modules/Events/Hub/Onboarding/` (both events + `index.ts`)
- `shared-modules/Events/Hub/index.ts`
- `shared-modules/Events/Hub/interfaces.ts`
- `apps/hub-service/src/secure-storage/` (vault + abstract + interface + typings + vault tests)
- `apps/hub-service/src/integration-keys/` (scoped command/query/DTOs/controller/model + tests)
- `apps/hub-service/src/config/environment.ts`
- `apps/hub-service/src/config/client-provisioning.log.ts`
- `apps/hub-service/src/config/client-provisioning.log.test.ts`
- `apps/websockets-service/src/hub-event-messages.config.ts`
- `apps/hub-service/package.json` (`ethers`)
- `yarn.lock`

**Do not include:** `deal-anchoring/`, `organisation-provisioning/`, `app.module.ts` new modules, transactions ledger-factory.

**Prove:** `vault.provider.test.ts`, `integration-keys.model.test.ts`, integration-keys controller/factory tests.

**Commit message style:** `INV-42559 - Land Measurabl hub foundation: vault transit, scoped keys, onboarding events.`

---

## PR2 — Deal anchors

**Base: PR1. Independent of org and sync.**

Checkout the `deal-anchoring` projector and the **base** migration only:

- `apps/hub-service/src/deal-anchoring/application/sagas/`
- `apps/hub-service/src/deal-anchoring/deal-anchoring.module.ts`
- `apps/hub-service/src/deal-anchoring/domain/commands/`
- `apps/hub-service/src/deal-anchoring/domain/entities/`
- `apps/hub-service/src/deal-anchoring/domain/models/`
- `apps/hub-service/src/deal-anchoring/domain/services/`
- `apps/hub-service/src/deal-anchoring/domain/resolve-provisioning-portfolio-id.ts` (+ test)
- `apps/hub-service/src/deal-anchoring/infrastructure/interfaces.ts`
- `apps/hub-service/src/deal-anchoring/infrastructure/repositories/` (repo + `index.ts` only)
- `apps/hub-service/src/migrations/1789471435157-add-deal-anchors-table.ts`

Then **slim** vs the source branch:

- Drop `pendingDocument` from entity, model, interfaces.
- Drop `updateRegistryForMappedDeal` / `putPendingDocument` / `takePendingDocument` / `takeAnyPendingDocument` from the repository. Constructor-only repo is enough.
- Do **not** add `pending-document-sync.ts`, `typeorm-query-rows.ts`, `deal-anchors.repository.test.ts` (those tests only cover PR4 methods), or `1789600000000-add-deal-anchors-pending-document.ts`.
- Drop the `preserves pendingDocument` model test.
- Edit `app.module.ts` to import `DealAnchoringModule` only. Do **not** checkout the source `app.module.ts` (it also adds `OrganisationProvisioningModule`).

**Prove:** `deal-anchor.sagas.test.ts`, `save-deal-anchor.command.test.ts`, `deal-anchor.model.test.ts`.

---

## PR3 — Org onboard

**Base: PR1. Does not need deal-anchors or sync-doc.**

`OrganizationToHubProvision` only. Stops at Hub org / vault keys / webhook.

Checkout:

- `organisation-provisioning/domain/chain/organisation/**`
- `organisation-provisioning/domain/chain/organisation-provisioning.context.ts`
- `organisation-provisioning/domain/chain/organisation-provisioning-step.ts` (+ test)
- Shared org pieces: `ensure-hub-wallet.step`, `ensure-required-provisioning-env.step`, `hub-wallet-address`, `required-provisioning-env` (+ tests)
- `organisation-provisioning/domain/chain/portfolio/identity-wallet-derivation.ts` (+ test) — **required**. `EnsureHubWalletStep` imports `NVNM_ORG_DERIVATION_PATH` from there.
- `run-organisation-provisioning.command.ts` (+ test)
- `organization-to-hub-provision.saga.ts` (+ test)
- `organization-to-hub-provision.event.handler.ts`
- Infra: `hub-admin.client`, `hub-admin.session`, `io-hub-organisation-map.repository`, `io-hub-organisation-map.ts`, `organisation-provisioning.lock` (+ tests)
- **Do not** include `hub-ledger-quotes` (registry/document funds).
- Entity + queries for `io_hub_organisation_map`
- Migrations: `1789548200000-add-io-hub-organisation-map-table.ts`, `1789700000000-add-io-hub-organisation-map-identity-wallet-index.ts`
- Scripts: `emit-organization-to-hub-provision.sh`, `emit-organization-to-hub-provision-sns.sh`
- `deal-anchoring/infrastructure/typeorm-query-rows.ts` (+ test) — map repo imports this path. Do **not** add the rest of deal-anchoring.

Then write **slim barrels** (org-only):

- `organisation-provisioning.module.ts` — org providers/sagas only. **No** `DealAnchoringModule`.
- `domain/chain/index.ts` — context, step, organisation, shared. No portfolio/registry/document.
- `domain/chain/shared/index.ts` — env, wallet, address only.
- `domain/commands/index.ts` — `RunOrganisationProvisioningCommandHandler` only.
- `application/sagas/index.ts` — `OrganizationToHubProvisionSaga` only.
- `domain/events/index.ts` — org handler only.
- `infrastructure/index.ts` — no `hub-ledger-quotes`.

Edit `app.module.ts` to add `OrganisationProvisioningModule` only (PR3 is on PR1, so no `DealAnchoringModule` here).

**Prove:** `organisation-provisioning.chain.test.ts`, `organization-to-hub-provision.saga.test.ts`, `hub-admin.*.test.ts`.

---

## PR4 — Portfolio + registry

**Stacked on PR1 + PR2 + PR3.** First half of `ClientDLTTransaction`.

Create the branch from PR3, merge PR2. Expect one conflict in `app.module.ts`. Resolve to import **both** `DealAnchoringModule` and `OrganisationProvisioningModule` (DealAnchoring first, same as the original).

Then checkout from the source branch:

- Entire `domain/chain/portfolio/` (derivation files already exist from PR3)
- Entire `domain/chain/registry/`
- Remaining shared: `identity-wallet-funds*`, `identity-wallet-top-up*`, `identity-write-signer`, `nvnm-add-record-gas`, `nvnm-native-transfer`
- Commands: `run-portfolio-provisioning`, `run-registry-provisioning`, `store-deal-anchor-registry` (+ tests)
- Sagas: `client-dlt-provisioning`, `store-deal-anchor-registry` (+ tests)
- `client-dlt-transaction.event.handler.ts`
- `pending-document-context.ts` (+ test)
- `measurabl-identity.ts`, `measurabl-tx-payload.ts`
- `hub-ledger-quotes.ts` (+ test)
- Deal-anchor **pending** surface from source: `pending-document-sync.ts`, full entity/model/interfaces/repository + `deal-anchors.repository.test.ts`, migration `1789600000000-add-deal-anchors-pending-document.ts`
- Scripts: `emit-client-dlt-transaction.sh`, `emit-client-dlt-transaction-sns.sh`
- Transactions: `ledger-factory.provider`, `nvnm-scoped-candidates`, `nvnm-ledger.provider`, `transactions.model`, `transactions.sagas`, `transactions-model-factory.service.test`, `transactions.module`
- `apps/hub-service/src/tokenization/hub-tokenization.provider.ts`

**Intentional stop (closed by PR5):**

1. `CompleteRegistryProvisioningStep` — if registry exists, mark completed and **return**. If missing, park `pending_document[taxonomyId]`. Do **not** call `RunDocumentProvisioningCommand`. Drop unused `CommandBus` from the constructor.
2. `StoreDealAnchorRegistryCommand` — store `deal_anchors.registry` only. Do **not** `takePendingDocument` / `takeAnyPendingDocument`. Do **not** start document provisioning. Drop unused `CommandBus`.

Update those two tests plus `registry-provisioning.chain.test.ts` so they no longer expect `RunDocumentProvisioningCommand`.

Grow barrels/module with portfolio + registry providers. Still **no** document chain, no `run-document-provisioning`, no `log-document-sync-finished`.

Leave `base-ledger.provider` and `estimate-tx-cost-payload.dto` for PR5.

**Prove:** portfolio/registry chain tests, `client-dlt-provisioning.saga.test.ts`, `store-deal-anchor-registry.*`, `ledger-factory.provider.test.ts`.

---

## PR5 — Sync doc

**Stacked on PR4.** Restores original-branch behavior.

Checkout from the source branch and **overwrite** the slimmed stop points:

- Entire `domain/chain/document/`
- `run-document-provisioning.command.ts` (+ test)
- `log-document-sync-finished.saga.ts` (+ test)
- Source copies of:
  - `complete-registry-provisioning.step.ts` (+ test)
  - `store-deal-anchor-registry.command.ts` (+ test)
  - `registry-provisioning.chain.test.ts`
  - `organisation-provisioning.module.ts`
  - `domain/chain/index.ts`, `domain/commands/index.ts`, `application/sagas/index.ts`
- Remaining transactions: `base-ledger.provider.ts` (+ test), `estimate-tx-cost-payload.dto.ts` (+ test)

The two restored call sites must match today:

- existing registry → `CompleteRegistryProvisioningStep` starts `RunDocumentProvisioningCommand`
- register webhook → `StoreDealAnchorRegistryCommand` takes pending and starts document chain

**Prove:** document chain tests, `sync-document.step.test.ts`, `log-document-sync-finished.saga.test.ts`, `pending-document-context.test.ts`.

---

## PR6 — Deals-service NVNM register succeeded

**Independent. Base: `develop`. Merge anytime.**

Checkout:

- `apps/deals-service/src/core/integration-settings/domain/commands/symbol-registration-succeeded.command.ts` (+ test)
- `apps/deals-service/src/core/integration-settings/domain/models/deal-integration-settings.model.ts` (+ test)

No hub-service coupling.

---

## Reconstruct and compare

After all six commits exist locally:

1. `git fetch origin develop`
2. New worktree/branch from `origin/develop` named `INV-42559-slices-merged-from-develop`
3. Merge in order: `…-pr1` → `…-pr2` → `…-pr3` → `…-pr4` → `…-pr5` → `…-pr6`
4. PR1 and PR2 fast-forward if stacked that way.
5. PR3 vs PR2 conflicts **only** on `apps/hub-service/src/app.module.ts`. Keep both modules.
6. PR4–PR6 should merge cleanly after that.

Compare to the original:

```bash
# Must be empty
git diff --name-status INV-42559-measurabl-anchoring HEAD -- \
  apps/hub-service apps/deals-service apps/websockets-service shared-modules yarn.lock

# Allowed extra: newer develop files the original never merged
git diff --name-status INV-42559-measurabl-anchoring HEAD
```

Expected allowed extra vs an original that last merged older `develop`: `apps/ai-service/alembic/versions/v_043_a8c4e1f2b903_create_dgml_workspaces_table.py` (or whatever current `develop` added since the original's merge-base).

`deal-anchoring` + `organisation-provisioning` file counts on original vs reconstructed must match (142 files when this playbook was written).

Nothing from the original **commits** may be missing. Local uncommitted junk on the original working tree is out of scope.

---

## Push / GitHub (only when the human asks)

Do not do this until told.

Then push each branch with `-u` and open stacked PRs with `gh pr create`. Suggested titles:

1. `INV-42559 - Measurabl hub foundation (vault, scoped keys, events)`
2. `INV-42559 - Project deal_anchors from DealCreated/DealUpdated`
3. `INV-42559 - OrganizationToHubProvision org onboard`
4. `INV-42559 - ClientDLT portfolio and registry (stop before addRecord)`
5. `INV-42559 - Sync document after registry`
6. `INV-42559 - Skip redundant NVNM register writes in deals-service`

Each PR body should say what it includes, what it excludes, and how to test it.

---

## Cleanup after a trial split

If the human asks to wipe a trial (as on 2026-09-30):

- Remove only the **slice worktrees**, not the original repo checkout.
- Delete only the **slice / reconstruction branches**, not `INV-42559-measurabl-anchoring`.
- Do not `reset --hard` the original branch.
- Leave the original dirty files alone.

Typical trial artifacts to delete (not the original branch):

- Worktrees: extra checkouts of the six `…-prN` branches and `INV-42559-slices-merged-from-develop`
- Branches: `INV-42559-foundation-measurabl-hub-pr1` … `INV-42559-deals-nvnm-symbol-succeeded-pr6` and `INV-42559-slices-merged-from-develop`

---

## Related pages

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md)
- [Organisation Provisioning Chain](Hub%20Onboarding%20Chain.md)
- [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md)
- [ADR-0001 Hub Onboarding Module](../decisions/ADR-0001%20Hub%20Onboarding%20Module.md)
- [Sequential PR Stack](Sequential%20PR%20Stack.md) — Discussion: linear GitHub order under a feature branch.
- [Sequential PR Descriptions](Sequential%20PR%20Descriptions.md) — Paste-ready GitHub bodies for #9752–#9757.
