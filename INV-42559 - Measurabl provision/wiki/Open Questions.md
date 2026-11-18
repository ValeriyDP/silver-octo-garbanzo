---
name: Open Questions
date: 2026-09-15T15:58:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
---

# Open Questions

**Summary**: Parking lot for things we do not know yet. Promote a question to an ADR in `decisions/` when a design choice is required.

**Sources**: Prior INV-42559 thread; [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md); [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md); [Hub Onboarding Chain](Hub%20Onboarding%20Chain.md); [Identity Wallet Signing](Identity%20Wallet%20Signing.md).

**Last updated**: 2026-09-22

---

| # | Question | Notes | Status |
| - | -------- | ----- | ------ |
| 1 | New `MeasurablDLTTransaction` vs reuse `HubDocumentSyncingRequestedEvent` in place? | **A.** Shipped as `ClientDLTTransaction` (`emit-client-dlt-transaction.sh`). Org is `OrganizationToHubProvision` (`emit-organization-to-hub-provision.sh`). | decided |
| 2 | One event does Register-if-needed **and** `addRecord`? | **A.** Shipped: existing `deal_anchors.registry` → sync now; else park `pending_document[taxonomyId]` and start sync from the register webhook. | decided |
| 3 | Feedback to data-room: reuse `HubDocumentSyncingSucceededEvent`? | **A.** Inbound has `taxonomyId`; existing Succeeded / Failed pair. No new emit. | decided |
| 4 | Persist provision work on existing `transactions` table? | **A.** Shipped. Register / Sync-Document / NVNM / Pending. No second table. | decided |
| 5 | Add a `hash` column on `transactions`? | **B.** Not added. Key on `taxonomyId` at insert + unique `hubJobId`. | decided |
| 6 | What if `deal_anchors` is missing when `ClientDLTTransaction` arrives? | **A.** Inner-join `deal_anchors` to `io_hub_organisation_map` on register webhook; no row → throw, no sync. ClientDLT is not the deal projector. | decided |
| 7 | Include `isSyncNeeded` on `ClientDLTTransaction`? | **A.** Omitted. ClientDLT means sync. | decided |
| 8 | How does the Identity wallet get gas (top-up)? | **A.** Parent org `/0` native NVNM send (ethers, leftover-aware Hub sign buffer). Hub `write()` stays `value = 0`. | decided |
| 9 | HD wallets from one org mnemonic instead of generate-per-identity? | **A.** Org mnemonic on the map; identity `m/44'/60'/0'/0/{n}` with `n` = DISTINCT parent count `+ 1`. Org at `0`. Hub gets leaf keys only. | decided |
| 10 | New path in **IO infrastructure Vault** for the onboarding mnemonic? | **A.** `inv-hub-tse/` transit. Ciphertext on `io_hub_organisation_map.mnemonic_ciphertext`. Decrypt ACL = `inv-hub-ms` only. | decided |
| 11 | Real IO `userId` vs sentinel on `transactions.user_id`? | Measurabl has no IO user. Interim: `MEASURABL_TRANSACTIONS_USER_ID` = `11111111-1111-4111-8111-111111111111` on Register / Sync. Keep sentinel until a real Measurabl IO user exists. Do not null the column. | open |
| 12 | Hub estimate is org-wallet only, but Register / Sync sign as the portfolio identity — so `addRecord` quote fails `unauthorized`. Fix on Hub, or change who creates the registry in provisioning? | **C working** (ethers from identity; Hub estimate unused). Destination is still Hub `/ledgers/estimate` from the identity wallet. See [#12 below](#12-org-wallet-estimate-vs-identity-signed-registry). | working |
| 13 | Hub job `Failed` then later `Succeed` on the same `hubJobId` is dropped as already terminal — registry never stored, document never syncs. Fix in `transactions` (new job), not in provisioning? | **A suggested**, not implemented. Failed stays Failed; retry = new IO row + new Hub job. Reopening the Failed row rejected. See [#13 below](#13-hub-job-failed-then-succeed-same-hubjobid). | open |
| 14 | `ClientDLTTransaction` requires `taxonomyId`, but upload does not create a taxonomy — Measurabl cannot send the id in advance. | **Unsolved.** Row is minted at IO Sync / `create-request`, not at upload and not after the chain. View-file URL is `fileId` + `dealId` only. See [#14 below](#14-taxonomy-id-is-not-available-at-clientdlt-emit) and [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md). | open |

When a row becomes a decision, add the ADR and link it here. Leave the question in place with status `decided` and a link, so the wiki still explains *what we asked*.

## How to close

Recommended pick is **bold**. Promote to an ADR only when someone accepts a pick.

| # | Variants | Close as |
| - | -------- | -------- |
| 1 | A: new inbound event. B: reuse `HubDocumentSyncingRequestedEvent`. | **A decided.** `ClientDLTTransaction` + `OrganizationToHubProvision`. |
| 2 | A: one ClientDLT does register-if-needed then `addRecord`. B: keep projector Sequence A then B as two inbound events. | **A decided.** Registry exists → sync; else park and wait for register webhook. |
| 3 | A: reuse `HubDocumentSyncingSucceededEvent` / Failed. B: new Measurabl-only emit. | **A decided.** |
| 4 | A: existing `transactions`. B: a second provision job table. | **A decided.** |
| 5 | A: add `hash` on `transactions`. B: do not; key on `taxonomyId` + `hubJobId`. | **B decided.** |
| 6 | A: require `deal_anchors` (DealCreated/Updated first); fail if missing. B: create a stub row from ClientDLT. | **A decided.** |
| 7 | A: omit `isSyncNeeded`. B: add it and skip `addRecord` when false. | **A decided.** |
| 8 | A: leftover-aware parent native top-up (current). B: Hub `write()` value. C: manual ops top-up. | **A decided.** Hub write stays `value = 0`. |
| 9 | A: HD from org mnemonic `m/44'/60'/0'/0/{n}`. B: generate-per-identity. | **A decided.** |
| 10 | A: IO transit `inv-hub-tse/` + ciphertext on the map. B: Hub app storage / mix into HubKeys. | **A decided.** |
| 11 | A: keep sentinel. B: create a Measurabl IO service user. C: nullable `transactions.user_id`. | **A for now**, **B when Measurabl has an IO user**. Do not null the column (other ledgers need it). Sentinel is a documented stand-in, not a product user. |
| 12 | A / B / C / D below. | **C working (ethers):** registry and document funds `eth_estimateGas(addRegistry` / `addRecord)` from the identity wallet (Vault ABI); leftover-aware Hub sign buffer. Hub estimate unused. **A** Hub `userEmail` estimate. **B** org-signed writes. **D** fixed pile (superseded). |
| 13 | A below (suggested). B rejected. | **A suggested:** Failed row stays Failed; retry is a new IO transaction + new Hub job. **B rejected:** reopen / patch the Failed row (`Failed → Pending` on the same `hubJobId`) — that was tried and reverted; it breaks one-row-one-outcome. |
| 14 | A / B / C below. | **Unsolved.** Need a pick. **B or C** match Measurabl (identity at emit is `fileId`). **A** only if mint does not also fire the old Hub sync. |

## #12 Org-wallet estimate vs identity-signed registry

**Issue.** NVNM: registry creator is admin; everyone else is deny-by-default until `grantRole`. Provisioning today signs both `addRegistry` and `addRecord` as `{portfolioId}@measurabl.com`. Hub `/ledgers/estimate` always uses the **org** wallet as `from`, even when `userEmail` is set (the Hub controller already loads that identity wallet and estimate ignores it). Result: `eth_estimateGas(addRecord)` from the org is `unauthorized`. Organisation-provisioning then has no fee for leftover-aware parent top-up.

Existing registry `4533` (Gama) was created by the identity, so an org-wallet estimate will keep failing on that deal until a new org-created registry or a Hub estimate change.

### Variant A — Hub estimate from `userEmail` (Hub)

Hub `estimate()` uses the identity wallet when `userEmail` is present (same as write). Current identity-signed Register / Sync then quotes cleanly. No `grantRole`. One Hub change; organisation-provisioning stays as-is.

Do not do this without an explicit ask — Hub is out of the provisioning directory.

**Close when:** Hub owners accept the estimate/`userEmail` change. Then mark #12 decided → A.

### Variant B — Org creates registry and org signs `addRecord` (provisioning)

Drop `userEmail` on Register and on Sync. Org is admin; Hub's existing org-wallet estimate works. No `grantRole`. No Hub change. Portfolio identities exist but do not write. Document top-up (#8) is unused if the org wallet already holds gas.

**Close when:** product accepts org-only writes. Then change `measurabl-tx-payload.ts` only. Gama needs a **new** org-created registry; `4533` stays identity-owned.

**Recommend this** while Hub must not change and `grantRole` is too much plumbing.

### Variant C — Ethers `eth_estimateGas(addRecord)` from the identity wallet (provisioning)

Hub `/ledgers/estimate` always uses the org wallet; identity-created registries return `unauthorized`. Estimate on NVNM RPC instead: encode the same `addRecord` calldata Hub write uses, `eth_estimateGas` with `from` = identity address (`0x4766…`), then leftover-aware parent top-up of Hub’s sign buffer `max(gas*3, gas+30000)*gasPrice`.

**Implemented** in `NvnmAddRecordGas` + `EnsureRegistryFundsStep` / `EnsureDocumentFundsStep.ensureQuoted`. Vault InveniamToken ABI. No Hub estimate for Register or Sync. `grantRole` is not required for this quote.

**Close when:** this quote matches what Hub needs to submit `addRecord`.

(Older C: org `addRegistry` + `grantRole` so Hub org-wallet estimate works. Heavier; not wired.)

### Variant D — Fixed pile (superseded)

Tried `0.008` then `0.01` on `0x4766…`. Hub still Failed `insufficient funds` (job `fdbc6e1d`). Displayed fee is not the sign buffer. Replaced by C (ethers estimate + Hub buffer).

### What not to do

Reuse Register's fee as the document quote. Do not treat explorer `0.01` as enough for Hub write.

## #13 Hub job Failed then Succeed (same `hubJobId`)

**Issue.** `completeIfPending` only updates a `Pending` row. Once we mark the job `Failed`, a later Hub `Succeed` + chain hash is logged `onComplete skipped: already terminal or lost race`. No ledger `onComplete`, no `HubSymbolRegisteringSucceededEvent`, no `StoreDealAnchorRegistry`, no document sync. `deal_anchors.registry` stays empty; `pending_document` stays parked.

Observed on deal `a44a3326-0e18-4f61-8636-2eb46525c762`, Hub job `dca26992-dfdd-49d4-8fd1-1fae5dcadb0c`, hash `0xb20ef61c31ee13c4b6a5ae9c0fe3d081c304b8dbc1836df7022d04681ff256a0`.

**What happened**

1. First `addRegistry` (12:53:27). Hub returns `hubJobId`, no hash. Row inserted `Pending`. Chain waits for the register webhook.
2. Status poll (12:53:35). Hub job = `failed` (`sender balance < tx cost`, no hash). `resolveHubWriteJob` maps job `failed`/`cancelled` to `onComplete(Failed)` immediately. Row claimed `Pending → Failed`. `HubSymbolRegisteringFailedEvent` published.
3. Hub webhook `Failed` (12:53:40). Skipped — already terminal.
4. Retry `ClientDLT` after a larger top-up (13:01:11). Hub write returns the **same** `hubJobId`. Insert hits unique `hub_job_id`. `LedgerIOProvider write idempotent replay` returns the Failed row. No new transaction.
5. Poll then sees a chain hash (13:01:39). `setTransactionIdForHubJob` writes `0xb20ef61…` onto the Failed row. **Status stays Failed.**
6. Poll + webhook `Succeed` (13:01:41 / 13:01:56). Skipped: `currentStatus=Failed`, `incomingStatus=Succeed`.

Two stacked behaviours in `transactions` (outside `organisation-provisioning`):

- **Job `failed` is treated as final.** Hub job Failed here was “cannot sign / broadcast yet”. Same job later got a hash and Succeed.
- **Retry cannot open a new job.** Hub write idempotency returns the old job id. Unique `hub_job_id` + idempotent replay returns the Failed row instead of inserting a new one.

A workaround that **patched the Failed row** to `Pending` when Hub later returned the same `hubJobId` with a new hash was tried and **reverted**. It reused one `transactions` row for two outcomes (Failed, then Succeed). That is not one transaction.

### Variant A — Suggested: Failed stays Failed; retry is a new transaction (`transactions` + Hub write)

Keep `completeIfPending` as-is: a Failed row is closed. A retry `Register` / `ClientDLT` must insert a **new** `transactions` row and get a **new** Hub `hubJobId` (new write idempotency key; do not send Hub the Failed job id). Unique `hub_job_id` then cannot collapse the retry onto the dead row. The new Pending row can claim Succeed and emit `HubSymbolRegisteringSucceededEvent`.

**Close when:** Hub write after a Failed job issues a new job, and IO always inserts instead of replaying the Failed `hubJobId`.

### Variant B — Rejected: reopen the Failed row

Patch `Failed → Pending` (or `Failed → Succeed`) on the same row / same `hubJobId` when a later hash arrives. Tried in `LedgerIOProvider` unique-violation handling; reverted. It breaks the transactional nature of the row (one insert, one terminal status).

Do not fix this inside `organisation-provisioning` without an explicit ask.

## #14 Taxonomy id is not available at ClientDLT emit

**Issue.** Inbound `ClientDLTTransaction` and outbound `HubDocumentSyncingSucceededEvent` both key on `taxonomyId`. Data-room `updateStatusOnResponseFromLedger` no-ops if that row is missing. Upload creates the file only. The view-file URL is `/view-file/{fileId}?id={dealId}` — no taxonomy PK. `GET /dataroom/taxonomies/{fileId}` is empty until IO Sync / `POST /dataroom/taxonomy/create-request/{fileId}` runs `requestChecksumVerification` (insert taxonomy, **then** the old Hub sync event). Measurabl skips that call, so there is no id to put on ClientDLT. A made-up UUID does not create the row.

Confirmed 2026-09-22 on file `04221f59-ffc2-48a6-9dbf-3cf15a8b3ad9`. Full note: [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md).

### Variant A — Mint taxonomy in IO first, then emit ClientDLT

Call `create-request` (or a new mint-only API) so the row exists, then send that `id` on ClientDLT. Today's `create-request` also starts `HubDocumentSyncingRequestedEvent` — do not use it as-is unless that second write is disabled.

**Close when:** a mint-only path exists and Measurabl always has a real taxonomy PK before emit.

### Variant B — Key ClientDLT on `fileId` (recommended)

Drop required inbound `taxonomyId`. Data-room creates or updates the NVNM taxonomy from `fileId` when Hub success arrives (or hub-service asks data-room to mint first). Matches the identity Measurabl already has.

**Close when:** success updates the badge from `fileId` without a pre-existing taxonomy PK.

### Variant C — Hybrid

Keep `taxonomyId` when present. If absent, resolve or create by `fileId` + NVNM on the success handler.

**Close when:** both shapes work; empty inbound `taxonomyId` still paints Synced.

## Related pages

- [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md)

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [DevOps How To Onboard Organisation](DevOps%20How%20To%20Onboard%20Organisation.md)
- [Open Questions Agenda](Open%20Questions%20Agenda.md)
- [Hub Service Anchor Projector Sequence](Hub%20Service%20Anchor%20Projector%20Sequence.md)
- [Hub Onboarding Chain](Hub%20Onboarding%20Chain.md)
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md)
- [Event Payloads](Event%20Payloads.md)
- [Measurabl DLT Transaction](Measurabl%20DLT%20Transaction.md)
- [IO UI File Synced Gaps](IO%20UI%20File%20Synced%20Gaps.md)
- [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md)
- [Decision register](../decisions/INDEX.md)
