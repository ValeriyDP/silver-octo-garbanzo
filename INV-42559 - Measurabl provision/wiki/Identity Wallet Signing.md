---
name: Identity Wallet Signing
date: 2026-09-16T19:41:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# Identity Wallet Signing

**Summary**: A registry signed as the portfolio Identity uses org HubKeys from Vault for `service-login`, then Hub picks the Identity wallet from `userEmail` on the write. Identity keys stay in Hub. `hubIdentityId` is not stored in IO.

**Sources**: Hub `POST /ledgers/write` (`hub/apps/backend/src/transactions-process/ledgers.controller.ts`, `validate-transaction-payload.service.ts`); [Hub Onboarding Chain](Hub%20Onboarding%20Chain.md).

**Last updated**: 2026-09-30

---

Identity (portfolio) wallet keys are **not** in Vault. The leaf is derived from the org mnemonic (`readTransitSecret` + `m/44'/60'/0'/0/{n}`), then stored on Hub. Vault holds organisation HubKeys (`hub/Credentials/{ioOrg}/NVNM/{network}`) for `service-login`. IO does not copy identity keys.

The write field is **`userEmail`**, not `userName`. Vault `userName` (`client-onboarding@inveniam.io`) is metadata on the org secret. Hub write never reads it.

On `POST /ledgers/write`:

| `userEmail` | Signer |
| --- | --- |
| omitted | Organisation wallet |
| `{portfolioId}@measurabl.com` | Identity wallet of the same ledger type as the org wallet (`isIndividual` when that wallet has encoded keys) |

Hub lookup: `getIdentityByOrgIdAndEmail(orgId, userEmail)` → that identity’s NVNM wallet. That email is the one `EnsureHubIdentityStep` already creates.

Silent fallback: if the identity is missing, not `Identity Active`, or has no NVNM wallet, Hub does **not** fail — it signs with the org wallet. For a registry “as identity”, the email must match and the identity NVNM wallet must exist.

Organisation native gas is during onboard (THE HUB UI or `GET {HUB_URL}/organizations/{hubOrganisationId}/wallets/ledger-type/NVNM`). Identity wallets are not topped up by hand.

## Quote before register / sync

`EnsureRegistryFundsStep` and `EnsureDocumentFundsStep` run **before** the write steps:

1. Quote: `GET /ledgers/get-wallet-info?userEmail=`, `GET /ledgers/balance/{hubWalletId}`, then ethers `eth_estimateGas` from the identity address using the Vault InveniamToken ABI (`addRegistry` / `addRecord`). Do not call Hub `/ledgers/estimate`.
2. If leftover already covers Hub’s sign buffer on `2×` ethers gas (`max(hubGas * 3, hubGas + 30000) * gasPrice`), proceed
3. Else re-read leftover (`GET /ledgers/balance/{hubWalletId}`) immediately before the parent send, transfer only `required - leftover`, then poll until leftover covers the buffer (3 min) or fail

Parent signer: decrypt `io_hub_organisation_map.mnemonic_ciphertext`, derive `m/44'/60'/0'/0/0`, sign with ethers on `EVM_NVNM_URL`. Identity `to` address: context / get-wallet-info, else Hub GET wallets by `hubWalletId` or name `Measurabl Portfolio` (`keys.encoded` cipher) then `POST /wallets/keys/decode` `{ cipherString }` for `address`. Amount is the sign-buffer deficit, not a fresh full top-up, so unused gas from earlier writes does not accumulate. Do not log mnemonic, cipher, keys, or address.

## `hubIdentityId` is not persisted in IO

It lives only on the in-memory identity-chain context, and only for `POST /organizations/{hubOrgId}/users/{id}/wallets` at create time.

Later reconstruct: `hubOrganisationId` from `io_hub_organisation_map` + resolved portfolio from `deal_anchors` (`portfolioId` when `parentPortfolioIds` is empty, else `parentPortfolioIds[0]`) → email `{portfolioId}@measurabl.com` → Hub identity by org + email. Same lookup Hub uses on write.

## Related pages

- [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md)

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Hub Onboarding Chain](Hub%20Onboarding%20Chain.md)
- [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md)
- [Identity Provisioner](Identity%20Provisioner.md)
- [Event Payloads](Event%20Payloads.md)
- [ADR-0001 Hub Onboarding Module](../decisions/ADR-0001%20Hub%20Onboarding%20Module.md)
