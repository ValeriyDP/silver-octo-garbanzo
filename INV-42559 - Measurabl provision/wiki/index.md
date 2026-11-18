---
name: Wiki Index
date: 2026-09-15T15:58:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - index
---

# Wiki Index

Start here: [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md) — formal, self-contained description in execution order. Does not depend on the other pages below. DevOps: [Measurabl Provisioning DevOps](Measurabl%20Provisioning%20DevOps.md). Product: [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md).

Knowledge base for **Measurabl provision (INV-42559)**. How-tos, diagrams, current state, open questions.

Decisions live in [decisions/INDEX](../decisions/INDEX.md). Cross-link; do not copy ADRs here. Locked: [ADR-0001 Hub Onboarding Module](../decisions/ADR-0001%20Hub%20Onboarding%20Module.md).

## Pages

- [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md) — Formal handoff in execution order. Self-contained.

- [Measurabl Provisioning DevOps](Measurabl%20Provisioning%20DevOps.md) — DevOps excerpt: IO Vault TSE, ciphertext on `invhub`, helm, migrations on startup, native gas, prove.

- [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md) — BA / PM / PO: two payloads; taxonomy sync; org vs Identity gas. Developer-handoff sequences. No infrastructure, no file-ingest story.
- [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md) — Black-box happy path and incorrect-id cases: Inveniam preconditions, AWS onboard and document sync (console, CLI, or hub-service SNS scripts), THE HUB and Kibana checks.

- [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md) — Local `deal_anchors` projector: what is built, intended lazy-onboard and sync sequences.
- [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md) — `OrganizationToHubProvision` (org only) and `ClientDLTTransaction` (portfolio → registry → `addRecord`).
- [Organisation Provisioning Chain](Hub%20Onboarding%20Chain.md) — Two CoRs: org relation setup; then portfolio → registry (`addRegistry` or reuse) → document (`addRecord`) on existing registry or register webhook.
- [DevOps Infrastructure Landing](DevOps%20Infrastructure%20Landing.md) — Standalone: env vars + IO Vault `inv-hub-tse/` + `invhub` migrations to land INV-42559.
- [DevOps How To Onboard Organisation](DevOps%20How%20To%20Onboard%20Organisation.md) — Operator: create IO org, emit `OrganizationToHubProvision`, living infra changelog.
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md) — Org HubKeys in Vault; write `userEmail` `{portfolioId}@measurabl.com` selects the Identity wallet. `hubIdentityId` not persisted.
- [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md) — THE HUB URLs on `ClientDLTTransaction` called with the user JWT, and the route-specific permission for each.
- [Identity Provisioner](Identity%20Provisioner.md) — New THE HUB organization role for that user JWT. Five permissions. Migration is on the page, not applied in `hub`.
- [new flow proposal](new%20flow%20proposal.md) — Note to Darell: no Hub auth change; one `Identity Provisioner` migration; manual org setup; mnemonic ciphertext on the map; provisioner login and password in the inv-hub-ms environment, with an optional transit wrap.
- [Event Payloads](Event%20Payloads.md) — Short contract: inbound `OrganizationToHubProvision` / `ClientDLTTransaction` and Hub → IO success events.
- [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md) — Working picture: `MeasurablDLTTransaction` (slim of `HubDocumentSyncingRequestedEvent`). Needs `taxonomyId`. Does not need portfolio.
- [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md) — What both success events must carry, and what IO must already have, for the file Synced badge.
- [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md) — **Problem:** `taxonomyId` is required on ClientDLT but upload does not create the row. Open #14.
- [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) — #1–#10 decided on this branch; #11–#14 still open.
- [Open Questions Agenda](Open%20Questions%20Agenda.md) — Remaining: sentinel `userId`, Hub estimate-from-identity, Hub job Failed-then-Succeed, taxonomy id at ClientDLT emit.
- [Provisioning Review Findings](Provisioning%20Review%20Findings.md) — R1–R14 punch list from the branch review. High R2–R4 and medium R5–R12 done. R1 (Hub mnemonic) rejected. Left: R13 (provider reuse), R14 (Hub estimate drops identity).
- [Split Branch Into PRs Agent Playbook](Split%20Branch%20Into%20PRs%20Agent%20Playbook.md) — How an agent splits `INV-42559-measurabl-anchoring` into six local PRs and proves the merge still matches the original.
- [Sequential PR Stack](Sequential%20PR%20Stack.md) — Discussion: linear GitHub stack under a feature branch for tracking. [Excalidraw](Sequential%20PR%20Stack.excalidraw.md).
- [Sequential PR Descriptions](Sequential%20PR%20Descriptions.md) — Paste-ready GitHub bodies for #9752–#9757. Feature branch merges into `develop` last.
- [Feature Branch PR Description](Feature%20Branch%20PR%20Description.md) — Paste-ready GitHub body for merging `INV-42559-measurabl-feature-branch` into `develop`.

## Related

- [Project README](../README.md)
- [CLAUDE](../CLAUDE.md)
