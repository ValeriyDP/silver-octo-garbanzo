---
name: Smart Accounts Implementation State
date: 2026-08-07T19:56:44.942Z
tags:
  - smart-accounts
  - zerodev
  - erc-4337
  - iam-service
  - hub-service
  - implementation-state
---

# SmartAccounts Implementation State

Investigation of the SmartAccount interaction across `hub-service` and `iam-service`
(tokenization / on-chain document verification), focused on:

- `inveniam.io/apps/hub-service/src/tokenization/utils/smart-accounts`
- `inveniam.io/apps/iam-service/src/core/smart-accounts`

## Architecture at a glance

Two services split responsibilities cleanly:

- **`iam-service/core/smart-accounts`** — the **system of record / custody & governance layer**.
  Stores smart-account metadata, signers, session-key material (in Vault), and multisig
  "actions." It does **not** talk to the blockchain itself.
- **`hub-service/tokenization`** — the **on-chain execution layer**. Uses the stored session
  key to actually sign and submit ERC-4337 `UserOperation`s for document-verification /
  tokenization transactions.

The stack is **ZeroDev Kernel v3.1 + ERC-4337 (EntryPoint 0.7)**, using `@zerodev/sdk`,
`@zerodev/permissions`, and `viem`.

---

## hub-service side (the EVM interaction)

`smart-account-tokenization.provider.ts` is a fully-implemented `TokenizationProviderInterface`
that runs UserOps instead of forwarding to the legacy Hub API:

- **`write`** decodes a base64 payload → `{to, calldata, value}` → `sendUserOperation`.
- **`getTransactionStatus` / `getTransactionReport` / `getTransactionData`** read UserOp
  receipts via the bundler.
- **`read`** does raw `eth_call` via a viem public client.
- **`estimateTxCost`** returns 0 — **transactions are paymaster-sponsored (gasless)**.
- **`resend` / `cancel`** deliberately throw `NotImplementedException` (correct — UserOps
  are atomic).

### Signing model

`utils/smart-accounts/deserialize-session-key-account.ts`:

```ts
const signingKeyAccount = privateKeyToAccount(signingKey);
const modularSigner = await toECDSASigner({ signer: signingKeyAccount });
// ...
const sessionKeyAccount = await deserializePermissionAccount(
    publicClient, getEntryPoint('0.7'), KERNEL_V3_1, sessionKey, modularSigner
);
```

The on-chain agent = **an approved (serialized) session-key permission account** co-signed by
an **Inveniam delegate ECDSA key** (`SMART_ACCOUNT_SIGNING_KEY` from env). This is the standard
ZeroDev "session key held by backend, permissions pre-approved by the owner" pattern.

### Integration into the tx flow (wired end-to-end)

- `transactions.model.ts` → `shouldUseSmartAccount()` → `SmartAccountConfigProvider.isSmartAccountEnabled()`
  decides per-org / per-ledger whether to take the smart-account path, otherwise falls back to
  the Hub API.
- `SmartAccountConfigProvider` fetches the live session key from iam-service
  (`GET /iam/io-internal/smart-accounts/sessions`, ApiKey-guarded, 30s cache — `CACHE_TTL_MS`) and
  combines it with env bundler / paymaster URLs.
- `LedgerFactoryProvider.getSpecificLedgerBySmartAccount()` reuses the existing per-chain ledger
  providers (Ethereum/Base/Polygon/etc.) but swaps in the smart-account tokenization provider —
  so codec / persistence logic is unchanged.
- A background `UserOpReceiptPollingService` (interval + exponential backoff, 24h expiry) polls
  pending smart-account txs and settles them through the same `onComplete` path as the Hub webhook.

### Config (`environment.ts`) — testnet stage

Default chain IDs confirm a testnet stage:

| Ledger  | Chain ID    | Network        |
|---------|-------------|----------------|
| ETH     | 11155111    | Sepolia        |
| BASE    | 84532       | Base Sepolia   |
| POLYGON | 80002       | Polygon Amoy   |

Also configured: `SMART_ACCOUNT_BUNDLER_URL`, `SMART_ACCOUNT_PAYMASTER_URL`,
`SMART_ACCOUNT_SIGNING_KEY`, and polling tunables.

---

## iam-service side (custody & governance)

Full DDD/CQRS module (models, entities, repositories, commands, queries, events, Vault provider).
Capabilities:

- **`CreateSmartAccountCommand`** — persists a smart account per chain
  (`implementation = KERNEL_3_1`), attaches a user signing key, and writes the **session key
  private material to Vault** (path scoped by org/account/session).
- **Session-key lifecycle** — `RenewSessionKeyCommand` (adds new key to Vault + DB),
  `RevokeSessionKeyCommand`.
- **Multisig governance** via `smart-account-actions` — `propose` → `sign` → `execute` →
  `cancel`, with per-signer **weights** and a **configurable threshold**. The `sign` command
  accumulates the signed weight across all signers and marks the action `SIGNED` once
  `signedWeight >= threshold` (real weighted multi-signer logic — see
  `sign-smart-account-action.command.ts`). **Account creation, however, still hard-codes a single
  signer**: `create-smart-account.command.ts` sets `threshold = 50` and the sole signer's
  `weight = 50` with the literal comment `// default to one signer for now`, so freshly created
  accounts are effectively single-signer until additional signers are added via governance.
- **Internal endpoint** serves the active session key to hub-service, reading material from Vault.

---

## Key observation: the on/off-chain boundary (assumption)

**The backend does not deploy contracts or perform the on-chain governance itself.**
Two strong signals:

1. `CreateSmartAccount` / `RenewSessionKey` **receive the session key and the smart-account
   `address` from the client** — the account is created / counterfactually derived and the
   session key is approved **client-side** (frontend, using the owner's passkey/EOA). The
   backend only records and custodies.
2. `ExecuteSmartAccountActionCommand` **receives a `userOperationHash` from the client** and
   merely records success + mutates its own DB projection (add/remove signer, create/revoke
   session key). The actual signer/session governance UserOp is submitted by the client, not
   iam-service.

### Reasonable assumptions about deployed contracts

- **ZeroDev Kernel v3.1 accounts** (ERC-4337, EntryPoint v0.7) are the deployed smart-account
  contracts, using the standard ZeroDev factory + validator / permission plugins.
- A **ZeroDev bundler + paymaster** (self-hosted or ZeroDev-hosted, given the
  `${url}/chain/${chainId}` URL shape) are provisioned per chain and **sponsor gas**.
- Only the **hub-service session key path signs on-chain automatically** (for automated document
  verification / tokenization); **human-initiated governance is client-signed**.

---

## Maturity assessment

| Area | State |
|---|---|
| hub UserOp write/read/status/report | ✅ Implemented + unit tests |
| Session-key deserialization (ZeroDev) | ✅ Implemented + tests |
| Hub↔iam session fetch + caching + fallback | ✅ Implemented + tests |
| Receipt polling / settlement | ✅ Implemented + tests |
| iam CRUD, session lifecycle, Vault custody | ✅ Implemented + tests |
| Multisig actions (propose/sign/execute) | ✅ **Weighted multi-signer threshold implemented** (`sign` accumulates `signedWeight >= threshold`). Two `TODO`s remain: (1) `create` hard-codes a single signer (`threshold = 50`, signer `weight = 50`, `// default to one signer for now`); (2) when a user holds multiple signing keys for one account, `propose`/`sign` just use the first (`smartAccountUserSigningKeys[0]`). |
| On-chain account creation / session approval | ⛔ **Not in backend** — delegated to client |
| Networks | 🧪 **Testnets only** (Sepolia / Base Sepolia / Amoy defaults) |

**Bottom line:** a well-structured, largely feature-complete **testnet-stage** integration.
The backend acts as an ERC-4337 relayer + session-key custodian + governance ledger; contract
deployment and owner-side approvals live on the client. The weighted multi-signer threshold
logic is implemented; main gaps before production: multi-signer **onboarding** (account creation
hard-codes a single signer, and per-user multi-key selection is a `TODO`), mainnet chain-ID /
bundler / paymaster config, and hardening around the delegate signing key custody.

---

## Key files

**hub-service**

- `src/tokenization/utils/smart-accounts/deserialize-session-key-account.ts`
- `src/tokenization/utils/smart-accounts/get-chain-from-id.ts`
- `src/tokenization/smart-account-tokenization.provider.ts`
- `src/tokenization/tokenization.service.ts`
- `src/transactions/application/services/smart-account-config.provider.ts`
- `src/transactions/application/providers/ledger-factory.provider.ts`
- `src/transactions/domain/models/transactions.model.ts` (`shouldUseSmartAccount`)
- `src/transactions/domain/services/userop-receipt-polling.service.ts`
- `src/config/environment.ts` (`smartAccount` block)

**iam-service**

- `src/core/smart-accounts/application/controllers/internal-smart-accounts.controller.ts`
- `src/core/smart-accounts/application/controllers/smart-accounts.controller.ts`
- `src/core/smart-accounts/infrastructure/queries/get-active-session-key.query.ts`
- `src/core/smart-accounts/infrastructure/providers/smart-accounts-vault.service.ts`
- `src/core/smart-accounts/domain/commands/create-smart-account.command.ts`
- `src/core/smart-accounts/domain/commands/renew-session-key.command.ts`
- `src/core/smart-accounts/domain/commands/smart-account-actions/{propose,sign,execute,cancel}-smart-account-action.command.ts`
