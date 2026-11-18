---
name: Sequential PR Descriptions
date: 2026-10-05T16:50:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - process
  - pr-split
---

# Sequential PR Descriptions

**Summary**: Paste-ready GitHub bodies for the six slice PRs under `INV-42559-measurabl-feature-branch`. Feature branch merges into `develop` last.

**Sources**: opened PRs #9752–#9757; [Split Branch Into PRs Agent Playbook](Split%20Branch%20Into%20PRs%20Agent%20Playbook.md); [Sequential PR Stack](Sequential%20PR%20Stack.md).

**Last updated**: 2026-10-05

---

## Stack

```
develop
  ← INV-42559-measurabl-feature-branch   (merge last)
    ← #9752 PR1 foundation
      ← #9753 PR2 deal anchors
        ← #9754 PR3 org onboard
          ← #9755 PR4 portfolio + registry
            ← #9756 PR5 sync doc
              ← #9757 PR6 deals-service
```

Merge order: **#9752 → #9753 → #9754 → #9755 → #9756 → #9757 → feature branch into `develop`.** After each slice merges, GitHub should retarget the next PR onto the feature branch.

---

## [#9752](https://github.com/inveniamcapital/inveniam.io/pull/9752) — Measurabl hub foundation (vault, scoped keys, events)

**Base:** `INV-42559-measurabl-feature-branch`  
**Head:** `INV-42559-foundation-measurabl-hub-pr1`

## Summary
First slice of INV-42559. Lands Hub foundation used by later PRs: Vault transit, scoped integration keys, onboarding event types, and client-provisioning log helpers.

Does not start org onboard, deal projection, or document sync. Those are #9753–#9757.

This PR targets the feature branch, not `develop`. Merge #9752–#9757 first; merge the feature branch into `develop` last.

## Includes
- Vault transit create/read on hub-service secure-storage
- Scoped integration keys (command, query, DTOs, controller, model, tests)
- Hub onboarding events: `OrganisationToHubProvision`, `ClientDLTTransaction`
- Scoped-key complete/failed events and websocket message wiring
- `client-provisioning.log` helpers
- `ethers` on hub-service + `yarn.lock`

## Excludes
- `deal-anchoring/`
- `organisation-provisioning/`
- New `app.module.ts` modules
- Transactions ledger-factory / NVNM scoped signing

## Test plan
- [ ] `vault.provider.test.ts`
- [ ] `integration-keys.model.test.ts`
- [ ] integration-keys controller and factory tests
- [ ] hub-service still boots without DealAnchoring or OrganisationProvisioning modules

---

## [#9753](https://github.com/inveniamcapital/inveniam.io/pull/9753) — Project deal_anchors from DealCreated/DealUpdated

**Base:** `INV-42559-foundation-measurabl-hub-pr1`  
**Head:** `INV-42559-deal-anchors-hub-pr2`  
**Depends on #9752.**

## Summary
Projects `deal_anchors` from `DealCreated` / `DealUpdated`. Constructor-only repository. No pending-document column and no org/document provisioning.

## Includes
- `DealAnchoringModule` wired in `app.module.ts`
- Deal-anchor entity, model, saga, save command, factory
- Root-portfolio resolution
- Base migration `1789471435157-add-deal-anchors-table`

## Excludes
- `pendingDocument` on entity/model/interfaces
- `updateRegistryForMappedDeal` / `putPendingDocument` / `takePendingDocument` / `takeAnyPendingDocument`
- `pending-document-sync.ts`, `typeorm-query-rows.ts`, pending-document migration
- `OrganisationProvisioningModule`

## Test plan
- [ ] `deal-anchor.sagas.test.ts`
- [ ] `save-deal-anchor.command.test.ts`
- [ ] `deal-anchor.model.test.ts`
- [ ] Later identity upsert keeps `registry` and does not mention `pendingDocument`

---

## [#9754](https://github.com/inveniamcapital/inveniam.io/pull/9754) — OrganizationToHubProvision org onboard

**Base:** `INV-42559-deal-anchors-hub-pr2`  
**Head:** `INV-42559-org-hub-provision-pr3`  
**Depends on #9753** (stack order). Content only needs #9752: Hub org, vault keys, webhook.

## Summary
`OrganisationToHubProvision` only. Creates/reuses the Hub org, organisation NVNM wallet, scoped keys, and webhook. Stops before portfolio, registry, and document.

Stacked on #9753 so GitHub stays one line. This slice does not use deal-anchors.

## Includes
- Organisation chain (env, Hub org, NVNM network, wallet, transit mnemonic, scoped keys, webhook, complete)
- `io_hub_organisation_map` entity, queries, repository, migrations
- Hub admin client/session and org provisioning lock
- `identity-wallet-derivation` (org derivation path used by `EnsureHubWalletStep`)
- `typeorm-query-rows` (map repo helper only)
- Emit scripts for `OrganisationToHubProvision`
- Slim org-only module and barrels

## Excludes
- Portfolio / registry / document chains
- `hub-ledger-quotes`
- `ClientDLTTransaction` saga/handler
- `DealAnchoringModule` import inside `OrganisationProvisioningModule`

## Test plan
- [ ] `organisation-provisioning.chain.test.ts`
- [ ] `organisation-to-hub-provision.saga.test.ts`
- [ ] `hub-admin.client.test.ts` / `hub-admin.session.test.ts`
- [ ] Module has no portfolio, registry, or document providers

---

## [#9755](https://github.com/inveniamcapital/inveniam.io/pull/9755) — ClientDLT portfolio and registry (stop before addRecord)

**Base:** `INV-42559-org-hub-provision-pr3`  
**Head:** `INV-42559-portfolio-registry-pr4`  
**Depends on #9754.** Needs #9752 + #9753 + #9754.

## Summary
First half of `ClientDLTTransaction`: portfolio then registry. If the registry already exists, mark completed and return. If not, park `pending_document[taxonomyId]` and wait for the register webhook. Does **not** start document `addRecord`.

## Includes
- Portfolio and registry chains
- Shared funds / top-up / signer / NVNM gas helpers
- `ClientDLTTransaction` saga/handler
- `StoreDealAnchorRegistryCommand` — writes `deal_anchors.registry` only
- Pending-document column, sync helper, repository methods, migration `1789600000000`
- NVNM scoped ledger-factory candidates
- Emit scripts for `ClientDLTTransaction`

## Intentional stop (closed by #9756)
- `CompleteRegistryProvisioningStep` does not dispatch `RunDocumentProvisioningCommand`
- `StoreDealAnchorRegistryCommand` does not take pending docs or start the document chain

## Excludes
- `domain/chain/document/`
- `run-document-provisioning`
- `log-document-sync-finished`
- `base-ledger.provider` and `estimate-tx-cost-payload.dto` changes (#9756)

## Test plan
- [ ] Portfolio and registry chain tests
- [ ] `client-dlt-provisioning.saga.test.ts`
- [ ] `store-deal-anchor-registry.command.test.ts` / saga test
- [ ] `ledger-factory.provider.test.ts`
- [ ] Existing registry completes without starting document sync
- [ ] Missing registry parks pending document and requests `addRegistry` only

---

## [#9756](https://github.com/inveniamcapital/inveniam.io/pull/9756) — Sync document after registry

**Base:** `INV-42559-portfolio-registry-pr4`  
**Head:** `INV-42559-sync-doc-pr5`  
**Depends on #9755.** Restores full INV-42559 hub-service behavior.

## Summary
Closes the #9755 stop. Existing registry starts document provisioning immediately. Register-succeeded takes the parked document and starts the document chain (`addRecord`).

## Includes
- Full document chain (`ensure funds` → `sync document` → complete)
- `RunDocumentProvisioningCommand`
- `LogDocumentSyncFinishedSaga`
- Restored `CompleteRegistryProvisioningStep` and `StoreDealAnchorRegistryCommand`
- `base-ledger.provider` and `estimate-tx-cost-payload.dto`

## Excludes
- deals-service NVNM register-succeeded skip (#9757)

## Test plan
- [ ] Document chain tests
- [ ] `sync-document.step.test.ts`
- [ ] `log-document-sync-finished.saga.test.ts`
- [ ] `pending-document-context.test.ts`
- [ ] Existing registry → `CompleteRegistryProvisioningStep` starts `RunDocumentProvisioningCommand`
- [ ] Register webhook → `StoreDealAnchorRegistryCommand` takes pending and starts the document chain

---

## [#9757](https://github.com/inveniamcapital/inveniam.io/pull/9757) — Skip redundant NVNM register writes in deals-service

**Base:** `INV-42559-sync-doc-pr5`  
**Head:** `INV-42559-deals-nvnm-symbol-succeeded-pr6`  
**Depends on #9756** (stack order only). No hub-service coupling.

## Summary
Last slice. deals-service skips redundant NVNM register writes after `SymbolRegistrationSucceeded`. Independent of hub onboarding; stacked last so the GitHub list stays one line.

After this PR lands on the feature branch, the feature tree matches `INV-42559-measurabl-anchoring` (plus any newer `develop` already on the feature branch). Then merge `INV-42559-measurabl-feature-branch` into `develop`.

## Includes
- `symbol-registration-succeeded.command.ts` (+ test)
- `deal-integration-settings.model.ts` (+ test)

## Excludes
- Any hub-service change

## Test plan
- [ ] `symbol-registration-succeeded.command.test.ts`
- [ ] `deal-integration-settings.model.test.ts`
- [ ] A second succeed for the same NVNM registration does not write again

---

## Related pages

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Split Branch Into PRs Agent Playbook](Split%20Branch%20Into%20PRs%20Agent%20Playbook.md)
- [Sequential PR Stack](Sequential%20PR%20Stack.md)
