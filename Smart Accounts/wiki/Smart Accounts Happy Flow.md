---
name: Smart Accounts Happy Flow
date: 2026-08-07T19:56:44.942Z
tags:
  - smart-accounts
  - zerodev
  - erc-4337
  - tokenization
  - hub-service
  - iam-service
---
# SmartAccounts — Happy Flow, Minimum Services & Frontend Gap Analysis

Companion to [Smart Accounts Implementation State](Smart%20Accounts%20Implementation%20State.md). This document describes what it takes
to make the SmartAccount tokenization / document-verification feature actually work end-to-end:
the minimum set of services to launch, the required config, the full happy-flow sequence, and
the concrete gap on the frontend (with the exact API calls it must make).

---

## 1. What "working" means

A document-verification / tokenization transaction for an organisation is submitted on-chain as a
**gasless ERC-4337 UserOperation** signed by a **ZeroDev Kernel v3.1 session key** (held by the
backend), instead of being forwarded to the legacy Hub API.

The routing is automatic: `hub-service` takes the smart-account path **iff** iam-service reports
an active session key for that `organisationId` + `chainId` (see `transactions.model.ts →
shouldUseSmartAccount()`), and the hub has bundler/paymaster URLs configured.

---

## 2. Minimum services to launch

### Core (required)

| Service (compose) | Port | Why it's needed |
|---|---|---|
| `inv-db` (Postgres + eventstore) | 5432 | iam + hub domain data and event store |
| `inv-rabbitmq` | 5672 | CQRS event/command bus for both services |
| `inv-redis-cache` | 6379 | Both services depend on it at boot |
| `inv-iam-ms` | 8904 | Smart-account custody, session-key vault, `/io-internal/smart-accounts/sessions` |
| `inv-hub-ms` | 8893 | On-chain execution (UserOp write/read/poll) |
| `inv-api-ngx` | 8881 | Local reverse proxy both services boot behind |

### External / infra dependencies (not app containers)

| Dependency | Why |
|---|---|
| **HashiCorp Vault** (`vault-dev.inveniam.io`) | Session-key private material is read/written here (`SmartAccountsVaultService`) |
| **FusionAuth** (dev tenant) | Issues the org JWT (`OrgTokenGuard`) for all smart-account API calls |
| **ZeroDev Bundler** (per chain) | `SMART_ACCOUNT_BUNDLER_URL/chain/{chainId}` — submits UserOps + receipts |
| **ZeroDev Paymaster** (per chain, funded) | `SMART_ACCOUNT_PAYMASTER_URL/chain/{chainId}` — sponsors gas |
| **EVM RPC / testnet** | Sepolia (11155111), Base Sepolia (84532), Polygon Amoy (80002) |

### Optional (only for full UI / real document trigger)

- `inv-front` (8880) — only if you drive the flow through the UI. **Note: it has no
  smart-account code yet (see §5).**
- Whatever service currently originates the verification transaction into hub (e.g.
  data-room / deals / metachain flows). For a pure backend demo you can call hub's transaction
  API directly and skip these.

> Everything else in `docker-compose.yml` (ai, deals, dataroom, workflows, mongo, immudb,
> provenance, etc.) is **not** required for this feature.

---

## 3. Required configuration (currently missing in dev)

These are **not** set in `docker-compose.yml` today and must be added for the feature to work:

### hub-service (`inv-hub-ms`)

```yaml
- SMART_ACCOUNT_BUNDLER_URL=https://rpc.zerodev.app/api/v3/<PROJECT_ID>   # or self-hosted
- SMART_ACCOUNT_PAYMASTER_URL=https://rpc.zerodev.app/api/v3/<PROJECT_ID>
- SMART_ACCOUNT_SIGNING_KEY=0x<inveniam-delegate-private-key>            # co-signer (viem PK)
- SMART_ACCOUNT_ETH_CHAIN_ID=11155111
- SMART_ACCOUNT_BASE_CHAIN_ID=84532
- SMART_ACCOUNT_POLYGON_CHAIN_ID=80002
- INV_IAM_SERVICE_KEY=<shared-service-api-key>   # Bearer key for /io-internal call
```

### iam-service (`inv-iam-ms`)

- Must accept the same service key on `ApiKeyGuard` for `GET /iam/io-internal/smart-accounts/sessions`
  (the `@inveniam/apikeyvalidator` key must match hub's `INV_IAM_SERVICE_KEY`).
- Vault + WebAuthn RP already configured in compose (`WEBAUTHN_RP_ID`, etc.).

### On-chain prerequisites (assumptions about deployed contracts)

- ZeroDev **Kernel v3.1 factory + validator/permission plugins** deployed on each target chain
  (standard ZeroDev addresses — assumed already deployed).
- The **paymaster is funded** on each chain.
- For each smart account: the owner (passkey/EOA) has **already approved the session-key
  permission on-chain / counterfactually** so the serialized `sessionKey` deserializes to a
  valid permission account.

---

## 4. Happy flow (end-to-end)

### Phase A — Provision a smart account + session key (one-time, per org/chain)

> This phase is **client/owner-driven**. The backend only records + custodies.

1. **Client** creates (counterfactually) a ZeroDev Kernel v3.1 account for the owner
   (passkey or ECDSA signer), derives its `address` and `index`.
2. **Client** generates a **session key** and has the owner approve its permissions, then
   **serializes** the permission account (this serialized blob is the `sessionKey` string).
3. **Client → iam** persists it:

   ```http
   POST /iam/smart-accounts
   Authorization: Bearer <org-jwt>
   Content-Type: application/json

   {
     "address": "0x<kernelAccountAddress>",
     "index": 0,
     "chainIds": [84532],
     "signingKey": { "type": "PASSKEY", "signerAddress": "0x<owner>", "passkeyId": "<uuid?>" },
     "sessions": [
       { "chainId": 84532, "sessionKey": "<serializedPermissionAccount>", "expiry": "<epochMs>" }
     ]
   }
   ```

   iam writes the `sessionKey` to Vault and stores metadata (`implementation = KERNEL_3_1`,
   threshold 50 = single signer).

### Phase B — Automatic on-chain execution (per verification/tokenization tx)

4. Something triggers a normal tokenization/verification transaction into **hub-service** for
   that org + ledger (existing transaction API — unchanged for the caller).
5. **hub** `transactions.model → shouldUseSmartAccount()` calls iam:

   ```http
   GET /iam/io-internal/smart-accounts/sessions?organisationId=<org>&chainId=84532
   Authorization: Bearer <INV_IAM_SERVICE_KEY>
   ```

   iam reads the active session key from Vault and returns:

   ```json
   {
     "smartAccountAddress": "0x...",
     "chains": [{ "chainId": 84532, "session": { "key": "<serialized>", "expiry": "..." } }]
   }
   ```

6. **hub** builds a `SmartAccountTokenizationProvider`, deserializes the session key
   (`deserializePermissionAccount` + delegate `SMART_ACCOUNT_SIGNING_KEY`), and submits a
   **sponsored UserOperation** via the bundler → returns the `userOpHash` as the transaction id.
7. **hub** `UserOpReceiptPollingService` polls the bundler for the receipt (backoff, 24h expiry)
   and settles the transaction (`applied` / `failed`) through the same `onComplete` path as the
   legacy webhook.

### Phase C — Governance actions (optional: add/remove signer, rotate/revoke session key)

> Multisig actions are **client-signed**; iam is the coordination ledger.

- `POST /iam/smart-accounts/:address/actions` (propose, with proposer `signature` + `publicKey`)
- `POST /iam/smart-accounts/:address/actions/:id/sign` (co-signers add signatures)
- `POST /iam/smart-accounts/:address/actions/:id/execute` (client submits the UserOp, passes
  back `userOperationHash`; iam updates its projection)
- `POST /iam/smart-accounts/:address/renew-session-key` / `.../revoke-session-key`

---

## 5. Frontend analysis — what exists vs. what's missing

### Current state (gap)

Searched `apps/frontend` for `smart-account | zerodev | permissionless | viem |
account-abstraction | passkey | webauthn | session-key | bundler`:

- **No smart-account implementation exists.** No ZeroDev/permissionless/viem AA deps in
  `apps/frontend/package.json`.
- The only reference is the enum value `TokenizationPartnersEnum.SmartAccount`, used **only in a
  test** (`hub-connector.test.ts`).
- Worse: `hub-connector.ts → findTransactionByProviderType()` **hard-filters to
  `TokenizationPartnersEnum.ICP`** and ignores `SmartAccount` settings entirely:

  ```ts
  (parsedConf.tokenizationPartner ?? TokenizationPartnersEnum.ICP) === TokenizationPartnersEnum.ICP
  ```

- The existing EVM tokenization stack is **Tokeny + Web3Modal** (`tokeny-*`, `ethereum-*`
  services) — a completely separate, wallet-based path. None of it produces ZeroDev session keys.

**Conclusion:** the frontend cannot currently create a smart account, generate/approve a session
key, or drive governance. The backend happy-flow (Phase B) works headless once Phase A data
exists, but **Phase A and Phase C have no UI/client today.**

### What the frontend must implement

Because the on-chain/crypto pieces are client-side, the frontend needs both **new crypto logic**
and **new API calls**. Per the request, the API calls are the priority:

#### New client-side crypto (libraries to add)

- `viem`, `@zerodev/sdk`, `@zerodev/permissions` (+ passkey/WebAuthn signer or ECDSA signer) —
  mirror what `hub-service/utils/smart-accounts` does, but for **account creation + session-key
  serialization + owner approval**, which the backend never does.

#### New API calls (against `iam-service`, base `http://localhost:8881/iam`, `Authorization: Bearer <org-jwt>`)

| Action | Method & Path | Body (key fields) |
|---|---|---|
| Create smart account + first session | `POST /iam/smart-accounts` | `address, index, chainIds[], signingKey{type,signerAddress,passkeyId?}, sessions[{chainId,sessionKey,expiry}]` |
| List smart accounts | `GET /iam/smart-accounts` | — (query filters) |
| Get one | `GET /iam/smart-accounts/:smartAccountAddress` | — |
| List signers | `GET /iam/smart-accounts/:smartAccountAddress/signers` | — |
| Renew (rotate) session key | `POST /iam/smart-accounts/:smartAccountAddress/renew-session-key` | `chainId, session{sessionKey,expiry}` |
| Revoke session key | `POST /iam/smart-accounts/:smartAccountAddress/revoke-session-key` | `chainId, ...` |
| List user signing keys | `GET /iam/user-signing-keys` | — |
| Propose governance action | `POST /iam/smart-accounts/:smartAccountAddress/actions` | `chainId, rawCallData, signature, publicKey, type, params` |
| Sign action | `POST /iam/smart-accounts/:smartAccountAddress/actions/:id/sign` | `chainId, signature, publicKey` |
| Execute action | `POST /iam/smart-accounts/:smartAccountAddress/actions/:id/execute` | `chainId, userOperationHash` |
| List actions | `GET /iam/smart-accounts/:smartAccountAddress/actions` | — |

> The verification/tokenization **transaction trigger itself needs no new frontend call** — the
> existing transaction flow into hub-service auto-routes once a session exists. The one caveat:
> if the UI is meant to *choose* the SmartAccount partner, `hub-connector.ts` must stop
> hard-filtering to `ICP`.

---

## 6. Minimal bring-up checklist

1. Start infra: `inv-db`, `inv-rabbitmq`, `inv-redis-cache`, `inv-api-ngx`.
2. Start `inv-iam-ms` and `inv-hub-ms` with the §3 env additions (bundler, paymaster, signing key,
   shared service key, chain IDs).
3. Ensure Vault + FusionAuth reachable; paymaster funded on the target testnet.
4. **Seed Phase A** — either via the (to-be-built) frontend, or by scripting the ZeroDev
   account+session creation and calling `POST /iam/smart-accounts`.
5. Trigger a verification/tokenization tx for that org/chain → confirm hub logs
   "Using smart account path", a `userOpHash` is returned, and the poller settles it.

### Blocking gaps summary

- ⛔ **Frontend**: no create-account / session-key / governance UI or API wiring (§5).
- ⛔ **Frontend**: `hub-connector` ignores `SmartAccount` partner (hard-coded `ICP`).
- ⚙️ **Config**: `SMART_ACCOUNT_*` + `INV_IAM_SERVICE_KEY` not in dev compose.
- ⚙️ **Infra**: ZeroDev bundler/paymaster (funded) + matching iam ApiKey must be provisioned.
- 🔐 **Custody**: production hardening of the delegate `SMART_ACCOUNT_SIGNING_KEY`.
