---
name: Organisation Provisioning Chain
date: 2026-09-15T20:27:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# Organisation Provisioning Chain

**Summary**: Two events. `OrganizationToHubProvision` runs `RunOrganisationProvisioningCommand` and stops at `CompleteOrganisationProvisioningStep`. `ClientDLTTransaction` (was `MeasurablDLTTransaction`) runs `RunPortfolioProvisioningCommand` after resolving `hubOrganisationId` from `io_hub_organisation_map`. After Identity, `CompletePortfolioProvisioningStep` starts `RunRegistryProvisioningCommand`. If `deal_anchors.registry` already exists, `CompleteRegistryProvisioningStep` starts `RunDocumentProvisioningCommand` immediately. If not, it parks the ClientDLT document fields on `deal_anchors.pending_document` keyed by `taxonomyId` and waits for the register webhook (`HubSymbolRegisteringSucceededEvent` → `StoreDealAnchorRegistry` → document sync for that key). No registry poll. Sequence: [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md).

**Sources**: [ADR-0001 Hub Onboarding Module](../decisions/ADR-0001%20Hub%20Onboarding%20Module.md); `apps/hub-service/src/organisation-provisioning/`.

**Last updated**: 2026-09-22T13:00:00.000Z

---

IO vocabulary vs Hub: **Organisation** = IO organisation = Hub organisation (1:1). **Portfolio** = Hub Identity. Hub stays on resource step names (`EnsureHubOrg`, `EnsureHubIdentity`, `EnsureHubWallet`).

```
OrganizationToHubProvision
  → RunOrganisationProvisioningCommand
    → EnsureOrganisationProvisioningEnv
    → login (admin JWT)
    → EnsureHubOrg → SetNvnmNetwork → EnsureHubWallet (org) → InsertOrgMnemonicInTransit → SaveScopedKeys
    → EnsureHubWebhook → InsertHubKeysInVault → CompleteOrganisationProvisioning
    organisation wallet native gas during this onboard (not later)
    (stop)

ClientDLTTransaction
  → RunPortfolioProvisioningCommand
    → EnsurePortfolioProvisioningEnv
    → ResolveHubOrganisation (map only; fail if missing)
    → EnsureHubIdentity → EnsureHubIdentityWallet → CompletePortfolioProvisioning
        → RunRegistryProvisioningCommand
            → EnsureRegistryFunds → EnsureRegistry → CompleteRegistryProvisioning
                → RunDocumentProvisioningCommand
                    → EnsureDocumentProvisioningEnv → EnsureDocumentFunds → SyncDocument → CompleteDocumentProvisioning
```

| Step | Does | Persist |
| --- | --- | --- |
| `EnsureOrganisationProvisioningEnvStep` | First org step. Collects every missing required config key (`hub.url` / admin / webhook, `networkType.NVNM`, `networkUrl.NVNM`, `vault.endpoint` / `role` / `kv`). On miss: log `eventName: OrganizationToHubProvision` + the inbound `payload` (`organisationId`, `organisationName`) and throw. No CoR context. Do not call Hub. Replay with `scripts/emit-organization-to-hub-provision.sh` after config is fixed. | — |
| `EnsurePortfolioProvisioningEnvStep` | First ClientDLT step. Same check for Hub admin + `networkUrl.NVNM` + Vault. On miss: log `eventName: ClientDLTTransaction` + inbound `payload`. Replay with `scripts/emit-client-dlt-transaction.sh`. | — |
| `EnsureDocumentProvisioningEnvStep` | First document-sync step (webhook resume included). Same keys and replay body as the portfolio env step. | — |
| `EnsureHubOrgStep` | Map by IO org. Else `POST /organizations` `{ name: organisationName }` from the saga (`Measurabl`). | `io_hub_organisation_map` |
| `EnsureHubIdentityStep` | Portfolio from `deal_anchors`: `portfolioId` when `parentPortfolioIds` is empty (deal on the root portfolio); else `parentPortfolioIds[0]`. `GET /organizations/{hubOrgId}/users?search=`. Else `POST /users` `{ firstName: Measurabl, lastName: Portfolio, email: {portfolioId}@measurabl.com }`. | Hub Identity. `hubIdentityId` on context |
| `EnsureHubWalletStep` | Org only. Generate → derive `m/44'/60'/0'/0/0`. Keep mnemonic for transit. Onboard then funds that wallet with native NVNM (THE HUB UI or GET wallets). | Hub org wallet. `hubWalletId` on context |
| `EnsureHubIdentityWalletStep` | Portfolio only. Decrypt org mnemonic from `io_hub_organisation_map.mnemonic_ciphertext`, derive `m/44'/60'/0'/0/{n}` where `n` is `DISTINCT` resolved parent IDs for the org `+ 1`. Parent via `portfolioId` if `parentPortfolioIds` empty, else `parentPortfolioIds[0]`. | Hub identity wallet. `hubWalletId` on context |
| `InsertOrgMnemonicInTransitStep` | After org wallet create: Vault transit `inv-hub-tse/keys/{ioOrg}` then `inv-hub-tse/encrypt/{ioOrg}` from the mnemonic. Ciphertext stored on `io_hub_organisation_map.mnemonic_ciphertext`. Skip if wallet already existed (no mnemonic). | IO Vault transit `inv-hub-tse/` + `invhub.io_hub_organisation_map` |
| `SetNvnmNetworkStep` | `GET /connection-profile/organization/{hubOrgId}`. Else `POST` NVNM `{ networkId, url }` from `NVNM_NETWORK_TYPE` / `EVM_NVNM_URL`. | Hub connection profile |
| `SaveScopedKeysStep` | `GET /credentials-configurator/organization/{hubOrgId}/wallet/{walletId}`. Else `POST /credentials-configurator` and decode `privateKeyData`. | HubKeys on context (`hubKey` / `hubPrivate`) |
| `EnsureHubWebhookStep` | `GET /webhooks/organization/{hubOrgId}`. Else `POST /webhooks` `{ name, url, isSignatureEnabled: true, organizationId }` to `hub/transactions/on-complete`. Hub `verifyWebhookUrl` accepts `http://IPv4:port/...` or `https://domain/...`. URL from `HUB_ON_COMPLETE_WEBHOOK_URL` (local default `http://host.docker.internal:8893/hub/transactions/on-complete`, resolved to IPv4 before POST). | Hub webhook. `hubWebhookId` on context |
| `InsertHubKeysInVaultStep` | If org-level NVNM keys already in Vault, skip. Else `SetIntegrationKeysCommand` at organisation scope (`hub/Credentials/{ioOrg}/NVNM/{network}`). Portfolio keys stay in Hub — see [Identity Wallet Signing](Identity%20Wallet%20Signing.md). | IO Vault (org) |
| `CompleteOrganisationProvisioningStep` | Marks organisation context complete. Does **not** start portfolio / registry / sync. | — |
| `ResolveHubOrganisationStep` | Look up `io_hub_organisation_map` by IO org. Use known Hub id. Fail if missing. | — |
| `CompletePortfolioProvisioningStep` | Marks portfolio context complete. Then starts `RunRegistryProvisioningCommand` when `portfolioId` is set. | — |
| `EnsureRegistryFundsStep` | Ethers `eth_estimateGas(addRegistry)` from the identity address on `EVM_NVNM_URL` (Vault InveniamToken ABI; Hub estimate is org-wallet only). Leftover-aware parent top-up using Hub sign buffer on `2×` ethers gas (`max(hubGas*3, hubGas+30000)*gasPrice`; Hub smart-account estimate is ~2× EOA). Poll Hub until leftover covers that buffer. Skip when `deal_anchors.registry` already exists. | — |
| `EnsureRegistryStep` | If `deal_anchors.registry` is set, put it on context and skip create. Else `RegisterSymbolCommand` (`addRegistry`) as `{portfolioId}@measurabl.com`. v3 write returns `hubJobId`; `HubTransactionPendingEvent` starts the job-then-chain status poll. Job `completed` is submit only — success is on-chain + `RegistryCreated`. | Existing `transactions` Register path. |
| `StoreDealAnchorRegistrySaga` | On `HubSymbolRegisteringSucceededEvent` (on-complete webhook → NVNM `RegistryCreated` → `symbol`). `StoreDealAnchorRegistryCommand` inner-joins `deal_anchors` to `io_hub_organisation_map` on `organisation_id = io_organisation_id` and `deal_anchors.id = dealId`, stores `symbol` in `deal_anchors.registry`, then starts `RunDocumentProvisioningCommand` from `pending_document[taxonomyId]` (that key cleared after start). | `deal_anchors.registry` |
| `CompleteRegistryProvisioningStep` | If context already has registry, start `RunDocumentProvisioningCommand` immediately. Else park `{ uri, checksum, … }` at `pending_document[taxonomyId]` and return. Document sync starts from the register webhook, not a poll. | `deal_anchors.pending_document` |
| `EnsureDocumentFundsStep` | Ethers `eth_estimateGas(addRecord)` from the identity address on `EVM_NVNM_URL` (Hub estimate is org-wallet / `unauthorized`). Leftover-aware parent top-up using Hub sign buffer on `2×` ethers gas (`max(hubGas*3, hubGas+30000)*gasPrice`). Poll Hub until leftover covers that buffer. | — |
| `SyncDocumentStep` | `SyncDocumentCommand` (`addRecord`). `symbol` is `deal_anchors.registry`. `userEmail` `{portfolioId}@measurabl.com`. | Existing `transactions` Sync-Document path |
| `LogDocumentSyncFinishedSaga` | On `HubDocumentSyncingSucceededEvent`, log `document sync finished`. No command. | — |

Email is `{portfolioId}@measurabl.com`. The portfolio chain uses a separate `EnsureHubWalletStep` instance so organisation and portfolio `setNext` pointers do not collide.

`hubIdentityId` is context-only (create wallet). A later registry write authenticates with org Vault keys and sets `userEmail` to that email so Hub signs with the portfolio Identity wallet. Details: [Identity Wallet Signing](Identity%20Wallet%20Signing.md).

## Related pages

- [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md)

- [Wiki Index](INV-42559%20-%20Measurabl%20provision/wiki/index.md)
- [DevOps How To Onboard Organisation](DevOps%20How%20To%20Onboard%20Organisation.md)
- [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md)
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md)
- [Event Payloads](Event%20Payloads.md)
- [ADR-0001 Hub Onboarding Module](../decisions/ADR-0001%20Hub%20Onboarding%20Module.md)
