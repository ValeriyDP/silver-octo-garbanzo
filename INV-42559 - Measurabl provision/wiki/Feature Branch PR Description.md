---
name: Feature Branch PR Description
date: 2026-10-08T15:38:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - pr-split
---

# Feature Branch PR Description

**Summary**: Paste-ready GitHub body for merging `INV-42559-measurabl-feature-branch` into `develop` after #9752–#9757.

**Sources**: [Sequential PR Descriptions](Sequential%20PR%20Descriptions.md); branch `INV-42559-measurabl-feature-branch` compared with `INV-42559-measurabl-anchoring`.

**Last updated**: 2026-10-08

---

### dataTestId

No `dataTestId` changes. Frontend is not part of this PR.

---
### JIRA TICKET

### https://inveniam.atlassian.net/browse/INV-42559

---
### Overview

Measurabl hub provisioning for an Inveniam organisation: onboard the org onto Hub, project deal anchors, then run `ClientDLTTransaction` through portfolio, registry, and document sync.

Lands on `develop` as the combined result of #9752–#9757 (`INV-42559-measurabl-feature-branch`). The tree matches `INV-42559-measurabl-anchoring` after both branches include `develop` at `46fc8a18`.

---
### What has been done

- **Hub foundation.** Vault transit create/read, scoped integration keys, `OrganisationToHubProvision` and `ClientDLTTransaction` events, scoped-key complete/failed websocket messages, client-provisioning log helpers. `ethers` added on hub-service.
- **Deal anchors.** `DealAnchoringModule` projects `deal_anchors` from `DealCreated` / `DealUpdated`, including root-portfolio resolution and a pending-document column used when the registry is not ready yet.
- **Organisation onboard.** `OrganisationToHubProvision` creates or reuses the Hub org, organisation NVNM wallet, transit mnemonic, scoped keys, and webhook. Persists `io_hub_organisation_map`.
- **Client DLT chain.** Portfolio, then registry, then document (`ensure funds` → `sync document` / `addRecord` → complete). An existing registry starts document provisioning immediately. A missing registry parks `pending_document[taxonomyId]` and document sync starts after the register webhook writes `deal_anchors.registry`.
- **deals-service.** A repeated NVNM `SymbolRegistrationSucceeded` for the same registration does not write again.
- **Migrations.** `deal_anchors`, `deal_anchors` pending document, `io_hub_organisation_map`, identity-wallet index.

---

## Version Bump?

Did I bump the version in the `pyproject.toml` file or `package.json` file of the package I am updating?

- [ ] Yes
- [x] No

`apps/hub-service/package.json` adds dependency `ethers` `^6.17.0` only. No package version field change. No `pyproject.toml` change.

---
### Type of Change

- [x] New feature (non-breaking change which adds functionality)

---
### How the test was performed ( Dev K8S )

Not run on Dev K8S for this write-up. Paste the environment and the onboard / `ClientDLTTransaction` result here.

---
### How Has This Been Tested?

- [x] I added new unit tests to cover this change
- [ ] I believe this change is already covered by existing unit tests

Hub-service tests cover vault, scoped keys, deal-anchor projection, organisation / portfolio / registry / document chains, pending-document handoff, ledger factory, and NVNM scoped signing. deals-service tests cover `symbol-registration-succeeded` and `deal-integration-settings`.

---
### Proof of Dev K8S Deployment

<!-- Paste deployment link or pod logs here -->

---
### Proof of local unit test case execution

<!-- Paste local test output here -->

hub-service: organisation-provisioning chain tests, deal-anchoring tests, `vault.provider.test.ts`, integration-keys tests, `ledger-factory.provider.test.ts`.

deals-service: `symbol-registration-succeeded.command.test.ts`, `deal-integration-settings.model.test.ts`.

---
### Proof of Benchmark Execution

**Mandatory:** Please paste execution logs or link to performance results below.

No benchmark in this change.

---
### Proof of Self-Review

**Mandatory:** Please confirm you have performed a self-review using the cursor self-review command before requesting a peer review.

- [ ] I have executed the cursor self-review command for this PR
- [ ] I have reviewed and addressed all Critical and Major issues identified in the self-review
- [ ] I have documented any Minor issues or Enhancements that were deferred with justification

**Self-Review Results:**
<!-- Paste the output from the cursor self-review command here, or provide a link to the review results -->

---
### How to test

1. Run hub-service migrations (`deal_anchors`, pending document, `io_hub_organisation_map`).
2. Emit `OrganisationToHubProvision` for an org. Expect a Hub org, organisation wallet, scoped keys in vault, webhook, and a row in `io_hub_organisation_map`.
3. Create or update a deal. Expect a `deal_anchors` row.
4. Emit `ClientDLTTransaction`. Expect portfolio provisioning, then registry. If the registry already exists, document sync starts immediately. If not, `pending_document` is stored and document sync starts after the register webhook writes `deal_anchors.registry`.
5. Send `SymbolRegistrationSucceeded` twice for the same NVNM registration in deals-service. The second event does not write again.

---

## Suggested Checklist:

- [ ] I have performed a self-review of my own code using cursor
- [x] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [x] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] I ran `uv run make check; uv run make lint; yarn lint; yarn type-check` to appease the lint gods

### Bugs:
- [ ]
- [ ]
- [ ]
- [ ]

---

## Related pages

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Sequential PR Descriptions](Sequential%20PR%20Descriptions.md)
- [Sequential PR Stack](Sequential%20PR%20Stack.md)
- [Split Branch Into PRs Agent Playbook](Split%20Branch%20Into%20PRs%20Agent%20Playbook.md)
