---
name: Wiki Log
date: 2026-09-15T15:58:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - log
---

# Wiki log

Append-only. Newest at the bottom.

- 2026-09-15 — Created knowledge base (`wiki/`) for Measurabl provision (INV-42559). Starter page: [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md).
- 2026-09-15 — Ingested [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md) (moved from working note). Registered on [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md). Filled [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) with provision-event forks from the prior thread.
- 2026-09-15 — Wrote [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md) from the prior thread: event contract, establish-if-missing steps, `transactions` persistence gap, feedback keys.
- 2026-09-15 — Slimmed `MeasurablDLTTransaction` from `HubDocumentSyncingRequestedEvent`: portfolio/symbol from `deal_anchors`; omitted userId, estimation, documentTaxonomy stubs. Parked `isSyncNeeded` as [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #7.
- 2026-09-15 — Dropped `fileId` from `MeasurablDLTTransaction`. Hub NVNM `addRecord` does not need it; IO feedback keys on `taxonomyId`.
- 2026-09-15 — Dropped inbound `transactionType` from `MeasurablDLTTransaction`. Hub sets it on encode (`Register` / `Sync-Document`), not from the event.
- 2026-09-15 — Dropped inbound `ledgerType` from `MeasurablDLTTransaction`. Measurabl is NVNM-only; hub sets the ledger.
- 2026-09-15 — Closed the loop: ingest needs `taxonomyId`, not portfolio. Portfolio unused on the `MeasurablDLTTransaction` path; `deal_anchors` is registry-only for this event.
- 2026-09-15 — Wrote [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md): Register vs doc-sync events vs what paints the file Synced badge.
- 2026-09-15 — Confirmed no `userId` on Measurabl Hub events. File badge does not need it; Register settings write accepts empty.
- 2026-09-15 — Added [Event Payloads](Event%20Payloads.md): short inbound/outbound contract.
- 2026-09-15 — Marked [Event Payloads](Event%20Payloads.md) fields as required-for-flow vs extras on the TS types.
- 2026-09-15 — Stage 2 module name locked: `hub-onboarding`. See [ADR-0001](../decisions/ADR-0001%20Hub%20Onboarding%20Module.md).
- 2026-09-15 — Created `hub-onboarding` module: admin login session (`POST /auth/login`). Org/keys HTTP not built.
- 2026-09-15 — Skeleton [Hub Onboarding Chain](Hub%20Onboarding%20Chain.md): saga `MeasurablDLTTransaction` → CoR steps. No IO-service writes.
- 2026-09-16 — Added `InsertHubKeysInVaultStep` (check closest NVNM keys, then `SetScopedIntegrationKeysCommand`). Map table queries: `findByIoOrganisationId` / `findByHubOrganisationId`.
- 2026-09-16 — Replaced `SkipWalletStep` with `EnsureHubWalletStep`: GET existing NVNM wallet, else generate / derive / set.
- 2026-09-16 — Filled onboard TODOs: create Hub org from saga `organisationName`, NVNM profile, credentials-configurator, then Vault keys. Check-before-create on each Hub resource.
- 2026-09-16 — Wrote [Identity Wallet Signing](Identity%20Wallet%20Signing.md): Vault holds org HubKeys only; Hub write `userEmail` `{portfolioId}@measurabl.com` selects the Identity wallet; `hubIdentityId` is reconstructable, not persisted. Linked from [Hub Onboarding Chain](Hub%20Onboarding%20Chain.md).
- 2026-09-17 — Identity chain now starts from `CompleteHubOnboardingStep` after the org chain finishes, not from `EnsureHubOrg`. Identity completion does not start identity again.
- 2026-09-17 — Dropped the `hubIdentityId` guard on org Complete (org never sets it). Identity chain ends on `CompleteHubIdentityStep`.
- 2026-09-17 — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #8 Identity wallet top-up (native mUSD; Hub write cannot). #9 HD from stored org mnemonic vs generate-per-identity.
- 2026-09-17 — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #10: HD mnemonic in a **new path in IO infrastructure Vault** (not Hub app storage), transit-encoded; not mixed into HubKeys.
- 2026-09-17 — Renamed module to IO vocab: `client-provisioning` (org chain) and portfolio provisioning (was Hub identity chain). ADR-0001 keeps the original `hub-onboarding` name.
- 2026-09-17 — Client → Organisation: module is `organisation-provisioning`. IO Organisation maps 1:1 to Hub organisation. Log marker `client-provisioning` unchanged.
- 2026-09-17 — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #11: sentinel `MEASURABL_TRANSACTIONS_USER_ID` (`11111111-1111-4111-8111-111111111111`) on Register / Sync so `transactions.user_id` is a valid uuid. Empty string blocked the pending row and the on-complete webhook.
- 2026-09-17 — Wrote [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md): final sequence from `MeasurablDLTTransaction` through org / portfolio / registry / document, including 3-minute registry poll and `LogDocumentSyncFinishedSaga`.
- 2026-09-17 — Wrote [Open Questions Agenda](Open%20Questions%20Agenda.md): discuss #1–11; confirm working picture first, then gas / HD / sentinel `userId`.
- 2026-09-17 — [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md): each step is a start/end group with Hub request and response (reuse mapped id vs create).
- 2026-09-18 — Split inbound events: `OrganizationToHubProvision` (org relation only) and `ClientDLTTransaction` (was `MeasurablDLTTransaction`; portfolio → registry → sync). Org complete no longer starts the next chain.
- 2026-09-18 — After org `EnsureHubWallet`, `InsertOrgMnemonicInTransitStep` writes the mnemonic through Vault transit `hub-tse/` (`keys/{ioOrg}` + `encrypt/{ioOrg}`), ciphertext at `{kv}/data/Mnemonic/{ioOrg}`.
- 2026-09-18 — Switched TSE mount to a new IO-only engine `inv-hub-tse/` (do not reuse existing `hub-tse/`). DevOps must enable the mount and attach policy.
- 2026-09-18 — Wrote [DevOps How To Onboard Organisation](DevOps%20How%20To%20Onboard%20Organisation.md): org create vs Hub onboard, per-Vault `inv-hub-tse/`, living infra changelog vs `develop`.
- 2026-09-18 — `inv-hub-tse/` enabled on `vault-dev`; probe key encrypt/decrypt verified. Changelog updated.
- 2026-09-18 — [DevOps How To](DevOps%20How%20To%20Onboard%20Organisation.md): dropped document ingest/sync notes (out of DevOps scope).
- 2026-09-18 — `readTransitSecret` next to `createTransitSecret` (KV + `inv-hub-tse/decrypt`). DevOps ACL now includes decrypt + KV read.
- 2026-09-18 — Ciphertext moved off Vault KV onto `io_hub_organisation_map.mnemonic_ciphertext`. `readTransitSecret(key, ciphertext)` decrypts only.
- 2026-09-18 — Portfolio identity wallet derives from the org mnemonic at `m/44'/60'/0'/0/{DISTINCT parent count}`. Parent from the known portfolio-id rule.
- 2026-09-18 — Identity HD derivation + wallet create live under portfolio (`EnsureHubIdentityWalletStep`). Shared `EnsureHubWalletStep` is org generate only.
- 2026-09-21 — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #12: Hub org-wallet estimate vs identity-signed `addRegistry` / `addRecord` (`unauthorized` on document quote). Hub path: estimate from `userEmail`. Provisioning path: org creates registry; optional `grantRole` for portfolios.
- 2026-09-21 — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md): added close variants for #1–#12 (recommended picks; #12 = B while Hub is frozen).
- 2026-09-21 — [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #12 Variant D: skip broken document quote; leftover-aware parent top-up `0.008` in advance (observed doc-sync fee `0.00747063` mUSD at 45 Gwei). Optional funds-fail retry.
- 2026-09-21 — #12 D leftover rule: re-read balance first; if pile `≥ 0.008` skip top-up; else send deficit only.
- 2026-09-21 — Implemented #12 D: `EnsureDocumentFundsStep` uses `ensureRequired(0.008)` (no Hub `addRecord` quote). Leftover `≥ 0.008` skips top-up; else parent sends the deficit. Register quote unchanged.
- 2026-09-21 — Funds poll treated `0.008` leftover as unfunded (`balance > fee`). Gama doc sync waited 3 min after a confirmed parent send, then failed. Poll now uses `>=`.
- 2026-09-21 — Hub `addRecord` job `32d8d765` Failed: insufficient funds after a `0.008` top-up.
- 2026-09-21 — Trying document required pile `0.01` (leftover-aware; poll Hub `≥ 0.01` before write).
- 2026-09-21 — `0.01` confirmed on `0x4766…` and Hub poll; Hub `addRecord` job `fdbc6e1d` still Failed insufficient funds. Raised required pile to `0.025`.
- 2026-09-21 — #12 C: document funds use ethers `eth_estimateGas(addRecord)` from the identity wallet (`EVM_NVNM_URL`). Hub `/ledgers/estimate` not called. Top-up uses Hub sign buffer from that gas.
- 2026-09-21 — Hub `/ledgers/estimate` removed for Register too. Both funds steps use Vault InveniamToken ABI + ethers `eth_estimateGas` from the identity wallet.
- 2026-09-21 — #13: deal `a44a3326…` job `dca26992` first Failed (insufficient funds), later Succeed + hash `0xb20ef61…` skipped as already terminal. Retry write idempotent-replayed the Failed row. Observations parked on [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #13.
- 2026-09-21 — Reverted `LedgerIOProvider` patch that reset a Failed `hubJobId` row to Pending when Hub reused the job with a new hash. #13 now suggests a new transaction + new Hub job instead.
- 2026-09-21 — `organisationName` is org-onboarding only (`OrganisationOnboardingContext` / `OrganizationToHubProvision`). ClientDLT / portfolio / registry / sync no longer carry it; document `dealName` is deal title or `dealId`.
- 2026-09-22 — Closed [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #1–#10 as shipped on `INV-42559-measurabl-anchoring` vs `develop`. Agenda is now #11 (sentinel `userId`), #12 (ethers quote until Hub can estimate from identity), #13 (Failed job stays Failed; retry = new transaction).
- 2026-09-22 — Wrote standalone [DevOps Infrastructure Landing](DevOps%20Infrastructure%20Landing.md): env vars, IO Vault `inv-hub-tse/`, `invhub` migrations. Operator onboard stays on [DevOps How To Onboard Organisation](DevOps%20How%20To%20Onboard%20Organisation.md).
- 2026-09-22 — First CoR step checks every required env for org onboard and ClientDLT / document sync. On miss, logs `eventName` + inbound event `payload` (not CoR context) so the message can be replayed after config is fixed.
- 2026-09-22 — **Problem:** `taxonomyId` is not available at ClientDLT emit. Upload does not create `data_room_file_taxonomies`; view-file URL is `fileId` + `dealId` only. Parked as [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #14 and [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md).
- 2026-09-29 — Reviewed `INV-42559-measurabl-anchoring` vs `develop` (204 files, ~11k lines; 45 provisioning suites / 155 tests green). Wrote [Provisioning Review Findings](Provisioning%20Review%20Findings.md) as a numbered punch list R1–R14, all open.
- 2026-09-29 — Fixed R2 and R3 in `organisation-provisioning`. R2: new `OrganisationProvisioningLock` (session-scoped `pg_try_advisory_lock` on a dedicated QueryRunner, bounded 150s wait); `IdentityWalletTopUp` re-reads leftover and sends inside it, so a concurrent run no-ops instead of colliding on the parent nonce. R3: kept read-then-increment (counter ticks only after a successful create) and wrapped the whole existence-check → read → derive → create → tick sequence in `OrganisationLockScope.IdentityHdLeaf`. Reserve-first was tried and rejected again: it burns a leaf per failed create, and leaves must stay dense so N portfolios sit on leaves 1..N — reconstruction is undesigned, so nobody should have to guess how far to walk the path. Two lock scopes (42559 nonce, 42560 HD leaf) so nested sections cannot self-deadlock. 46 suites / 163 tests green, lint clean.
- 2026-09-29 — R4 measured against real queue config: `heartbeatInterval` 9s already extends visibility, so the risk is `handleMessageTimeout` (180s) against a 300s funding worst case (120s `tx.wait` + 180s poll) — abort, no delete, redelivery. R2 defuses the damage (duplicate serialises and no-ops). Budget-vs-timeout decision still open.
- 2026-09-29 — Located [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #12 Variant A in Hub source as R14. `ledgers.controller.ts` already resolves `userWallet` from `userEmail` and passes it into `EstimateTransactionFeeQuery`; `ProcessTransactionService.estimate` never destructures it and connects the provider with `orgWallet` — hence the master-wallet estimate and `unauthorized` on identity-created registries. `write` in the same service picks `isIndividual ? userWallet : orgWallet`. Fix is that selection mirrored into `estimate`; it would retire the ethers quote path (R5–R8, R13).
- 2026-09-29 — R1 (Hub holds the org seed) **rejected** after checking Hub source: `generateWalletKeys` returns a `bip39` phrase and persists nothing; `deriveKeysFromMnemonic` derives in memory and returns `{ privateKey, address }`. Hub stores the derived key pair only, has no mnemonic storage by design, and gives the phrase to the user as a file. [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #9 and #10 stand as written. Local derivation in IO remains available as a simplification, not a security fix.
- 2026-09-29 — Fixed medium findings R5–R12 in `organisation-provisioning`. R5: `IdentityWalletTopUpEstimate` carries `bigint` wei (`feeWei` / `gas` / `gasPrice` / `requiredWei`); Hub ETH numbers convert at the boundary; logs are strings. R6: `quoteGasPrice` uses `max(gasPrice, maxFeePerGas)` × `nvnm.gasPriceHeadroomPercent` (default 1.2×); `ensureQuoted` re-quotes after the leftover poll and fails if leftover no longer covers. R7: `combineTopUpEstimates` buffers each write, then sums. R8: probe swallows only `CALL_EXCEPTION` / `NvnmEstimateRevertError`; transport fails the quote; stand-in is `nvnm.addRecordEoaGasStandIn` and logs `addRecordStandInUsed`; live probe cached per org. R9: failed `GET /ledgers/balance/{id}` rethrows instead of funding the full buffer. R10: ethers `TIMEOUT` on `tx.wait` is "not yet confirmed" — hash logged and returned so the poll can pick it up; other wait errors reject. R11: `IdentityWriteSigner` compares receipt `from` to the identity on register and addRecord succeed; mismatch is a warn. R12: `SECRET_LOG_KEYS` keeps `walletId` / `from` / `walletAddress`; path sanitizer no longer masks `/wallet/{id}`, so it agrees with `/ledgers/balance/{id}`. 49 suites / 187 tests green, lint clean. Left: R13 (provider reuse) and R14 (Hub `estimate()` still drops `userWallet`).
- 2026-09-30 — Wrote [Split Branch Into PRs Agent Playbook](Split%20Branch%20Into%20PRs%20Agent%20Playbook.md): six-slice split of `INV-42559-measurabl-anchoring`, reconstruction check, no-push rule. Trial local worktrees/branches were cleaned; original branch kept.
- 2026-09-30 — Playbook: do not merge `INV-42086-hub-keys-everywhere`. Scoped keys and deal projection stay in INV-42559.

- 2026-09-30 — Wrote [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): next-developer page for what shipped versus `develop`, decisions, closed gaps (#1–#10, R1–R12), appendix leftovers (#11–#14, R13–R14). Reuses the Organisation Provisioning Sequence diagrams. Ticket numbers omitted from the body.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md) is now standalone: event payloads, step catalogue, identity signing, Synced-badge rules, infra landing, operator onboard, and leftover write-ups are inlined. No outbound wiki or ADR links.

- 2026-09-30 — Rewrote [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md) as a linear narrative (problem → machine → org event → document event → badge → leftovers). Removed section-jumping catalogues and same-page “see A4” links.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): formal register (same voice as Organisation Provisioning Sequence). Removed chapter/story asides. Linear order retained.

- 2026-09-30 — Event payloads as TypeScript types: inbound on [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md) (Inbound events); outbound types at Registry and Document sync. [Event Payloads](Event%20Payloads.md) tables replaced with the same types.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md) and [Event Payloads](Event%20Payloads.md): `taxonomyId` marked as the required IO correlation key (`data_room_file_taxonomies.id`). Listed uses: inbound, `pending_document`, `transactions`, document success event, Synced UI. Hub writes do not use it.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): replay examples include SNS (`emit-organization-to-hub-provision-sns.sh`, `emit-client-dlt-transaction-sns.sh`) alongside local Rabbit.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): expanded CoR on first use as Chain of Responsibility; added to Terminology.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): infrastructure tables point at hub-service migrations `1789471435157`, `1789600000000`, `1789548200000`, `1789700000000`.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): migrations run automatically on `inv-hub-ms` startup (`migrationsRun: true`). No separate migrate job.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): infrastructure env taken from `helm_env_configs` `INV-42559-measurabl-anchoring` vs `origin/master` (that repo has no `develop`). TSE path on cluster is `inveniam-{env}-hub-tse`; `qa9` RPC inherit noted.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): cluster transit ACL is the attached policy (`inveniam-<env>-hub-tse/{keys,encrypt,decrypt}/+`, `update` only), not the requested `keys/*` with create/read.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): dropped concrete env overlays (`qa9`, uat, prod, …). NVNM RPC / network type described as live vs non-live.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): transit ACL states the attached policy only. Removed “originally requested ACL” history.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): removed leftover `hub/data/Mnemonic/*` note.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): opening states Hub is a third-party black box, not part of IO, and is not changed. HubKeys path detail replaced by that rule.

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): third-party app is THE HUB; IO `inv-hub-ms` is IO Hub Service. Code and event names unchanged.

- 2026-09-30 — Wrote [Measurabl Provisioning DevOps](Measurabl%20Provisioning%20DevOps.md): DevOps excerpt. Separate IO Vault TSE vs THE HUB `hub-tse/`; transit wrap; ciphertext on `io_hub_organisation_map.mnemonic_ciphertext`. Helm, auto-migrations, prove. Registered on [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md).

- 2026-09-30 — [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md): inbound bus (`EventToMSMap` `hub`, env SNS / local Rabbit); producer field aliases vs `ClientDLTTransaction`; `checksumAlgo` = `SHA-256`; write identity is `transactions.hub_job_id`, not a content composite. Same `uri` + other checksum is a new `addRecord`.

- 2026-09-30 — Wrote [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md): BA / PM / PO excerpt. Two messages, `taxonomyId` / Synced, replay, locked decisions, open product gaps. No infrastructure. Simplified sequences. Registered on [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md).

- 2026-09-30 — [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md): Gherkin acceptance scenarios on organisation vs document, field names, taxonomy / Synced, registry reuse, repeat checksum, failed-job retry.

- 2026-09-30 — Rewrote [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md) around the implemented payloads only. Taxonomy is the sync target. No file-ingest assumptions. Sequences copied from the developer handoff.

- 2026-09-30 — Org vs Identity gas: ops send native NVNM to THE HUB org wallet after onboard; Identity is leftover-aware parent `/0` on `ClientDLTTransaction`. [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md), [Measurabl Provisioning DevOps](Measurabl%20Provisioning%20DevOps.md), [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md), [Identity Wallet Signing](Identity%20Wallet%20Signing.md).

- 2026-09-30 — Organisation wallet top-up is during onboard (`OrganizationToHubProvision`), not a later ops send. Identity remains leftover-aware parent `/0` on `ClientDLTTransaction`.

- 2026-10-01 — Discussion: linear GitHub stack under a feature branch. [Sequential PR Stack](Sequential%20PR%20Stack.md), [Sequential PR Stack.excalidraw](Sequential%20PR%20Stack.excalidraw.md).

- 2026-10-08 — Wrote [Feature Branch PR Description](Feature%20Branch%20PR%20Description.md). Paste-ready body for the feature branch into `develop`. Registered on [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md).

- 2026-10-08 — Wrote [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md). Black-box happy path for QA: Inveniam preconditions, AWS `OrganisationToHubProvision` and `ClientDLTTransaction`, THE HUB and Kibana. Negative cases are recorded only when they appear unplanned. Registered on [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md).

- 2026-10-08 — [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md): opening catalog of Kibana `msg` / `args.reason` when a happy-path run stops. Not a negative test plan.

- 2026-10-08 — [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md) is standalone. Removed outbound wiki links.

- 2026-10-08 — [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md): appendix embeds the organisation and document sequence diagrams. No link to the developer handoff.

- 2026-10-09 — [Measurabl Provisioning Product](Measurabl%20Provisioning%20Product.md): mnemonic ciphertext arrow stores on `io_hub_organisation_map`. [Measurabl Provisioning DevOps](Measurabl%20Provisioning%20DevOps.md): service name is IO Hub Service.

- 2026-10-09 — Document sequence on the handoff, product, and QA pages: `eth_estimateGas` for `addRegistry` and `addRecord` goes to the NVNM chain, not THE HUB.

- 2026-10-09 — Same diagrams: note that THE HUB estimates only from the org wallet and ignores `userEmail` on the estimate payload.

- 2026-10-09 — Handoff, product, QA, and DevOps: wallet top-up and the quote that sizes it are funding. `eth_estimateGas`, `gasPrice`, and the `NvnmAddRecordGas` log line stay as code names.

- 2026-10-09 — [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md): onboard and document publish can use `emit-organisation-to-hub-provision-sns.sh` and `emit-client-dlt-transaction-sns.sh`. The document example is the minimum command (`organisationId`, `dealId`). Optional `taxonomyId`, `URI`, `CHECKSUM`, and `CHECKSUM_ALGO` are listed with defaults.

- 2026-10-09 — [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md): document script also has the full command, with `URI`, `CHECKSUM`, `CHECKSUM_ALGO`, and `taxonomyId` set.

- 2026-10-09 — [Measurabl Provisioning QA](Measurabl%20Provisioning%20QA.md): TC-06 through TC-11 for an incorrect id. Non-UUID `organisationId` or `dealId` fails the UUID column lookup. An unknown organisation id fails before Identity. An unknown deal id fails with no portfolio. An empty `taxonomyId` fails only when the deal has no registry, and only after the Identity wallet exists. A new `taxonomyId` UUID is not a failure. A well-formed unknown `organisationId` on onboard is not rejected.

- 2026-11-10 — Wrote [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md). THE HUB URLs on `ClientDLTTransaction` that use the user JWT from `POST /auth/login`. Registered on [Wiki Index](index.md).

- 2026-11-10 — [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md): route-specific permission for each URL. `POST /auth/login` and `GET /ledgers/balance/{walletId}` have none.

- 2026-11-10 — [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md): unified permission list. Five names.

- 2026-11-10 — Wrote [Identity Provisioner](Identity%20Provisioner.md). New THE HUB organization role for the `ClientDLTTransaction` user JWT. Five permissions. Not in the codebase. Registered on [Wiki Index](index.md).

- 2026-11-10 — [Identity Provisioner](Identity%20Provisioner.md): migration `1792600000000-create-identity-provisioner-role.ts` recorded on the page. Not applied in `hub`.

- 2026-11-10 — [new flow proposal](new%20flow%20proposal.md): FusionAuth token exchange is not applicable. It would inject IO-specific needs into Hub.

- 2026-11-10 — [new flow proposal](new%20flow%20proposal.md): item 2 states the Hub user must exist, so the `Identity Provisioner` migration runs before the user is invited.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): the personal Hub JWT from the exchange endpoint is used by IO.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): item 5 says IO uses the personal Hub JWT minted in step 4.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): the exchange is set aside because it would add alien logic to Hub's auth process.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): closing softened to "We would rather not take this path."

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): closing rewritten. Hub's auth stays as it is; the exchange would plant a step that does not belong to Hub.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): closing now says the auth change and the exchange exist only so IO can get a Hub JWT, and that step is not Hub's to carry.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): the machine-to-machine section now sits above the proposed next steps.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): grammar only on the rewritten message.

- 2026-11-11 — [new flow proposal](new%20flow%20proposal.md): Hub change is one role migration, not "no Hub change". Endpoints mapped to the five permissions. `User:Create` does not assign roles. One provisioner user per organisation. Login and password are Vault transit ciphertext, with access and rotation. Vault example no longer puts the mnemonic on the command line. Ask states what Darell confirms and who does the work. Registered on [Wiki Index](index.md).

- 2026-11-12 — [new flow proposal](new%20flow%20proposal.md): opening now leads with the two approaches. FusionAuth is the one that takes Hub-side changes. Identity Provisioner is the one that leaves Hub auth as it is.

- 2026-11-12 — [new flow proposal](new%20flow%20proposal.md): `io_hub_organisation_map` stores the mnemonic ciphertext only. The provisioner login and password are environment variables on inv-hub-ms.

- 2026-11-12 — [new flow proposal](new%20flow%20proposal.md): ciphering the provisioner login and password with the same transit key is an optional step. The ciphertexts stay in the environment.

- 2026-11-12 — [new flow proposal](new%20flow%20proposal.md): answers on the credential ciphertext, in the wording of the reply. The transit key is the organisation id from the event. MFA is off for this machine user. Cross-org decrypt and non-IO access match HubKeys and the existing Vault token.
