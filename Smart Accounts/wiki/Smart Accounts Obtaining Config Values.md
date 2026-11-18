---
name: Smart Accounts Obtaining Config Values
date: 2026-08-07T19:56:44.942Z
tags:
  - smart-accounts
  - zerodev
  - config
  - environment
  - setup
---

# SmartAccounts — Obtaining the Config Values

Companion to [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md). Clarifies where each required env value actually
comes from. Key point: **only the bundler/paymaster is a true external dependency** — the rest
are self-generated or hard-coded constants.

---

## Value-by-value

| Var | Status | How to get it |
|---|---|---|
| `INV_IAM_SERVICE_KEY` | Already known | Hard-coded `IO_KEY` in `shared-modules/ApiKeyValidator/src/constants.ts`: `e4092ace-bcf8-45e0-b3a9-5cb0ef8e7af4`. iam's `ApiKeyGuard` does a literal string compare — no Vault/config needed. hub just sends it as `Authorization: Bearer <key>`. |
| `SMART_ACCOUNT_ETH_CHAIN_ID` | Public constant | `11155111` (Sepolia). Already defaulted in `hub-service/src/config/environment.ts`. |
| `SMART_ACCOUNT_BASE_CHAIN_ID` | Public constant | `84532` (Base Sepolia). Already defaulted. |
| `SMART_ACCOUNT_POLYGON_CHAIN_ID` | Public constant | `80002` (Polygon Amoy). Already defaulted. |
| `SMART_ACCOUNT_SIGNING_KEY` | Self-generate | Any EVM private key — the backend delegate co-signer. `echo 0x$(openssl rand -hex 32)`. |
| `SMART_ACCOUNT_BUNDLER_URL` | External (free) | ZeroDev project RPC (or Pimlico/Alchemy, or self-host). **Only real dependency.** |
| `SMART_ACCOUNT_PAYMASTER_URL` | External (free) | Same ZeroDev project id → same base URL; enable a gas/sponsorship policy. |

> `ApiKeyGuard.canActivate()` → `isEqual(IO_KEY, apiKey)`; `IO_KEY` is a compile-time constant.
> So the "shared service key" is not a secret you provision — it already ships in the repo.

---

## The values that are *created*, not obtained

The **smart-account address** and **session key** are **not** given to you — they are produced at
runtime (Phase A of [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md)):

1. Run the ZeroDev SDK client-side to create a Kernel v3.1 account (→ `address`, `index`).
2. Generate + owner-approve a session key, serialize it (→ the `sessionKey` string).
3. `POST /iam/smart-accounts` to persist.

This is why everything depends on the bundler/paymaster: without them (and a chain that has the
Kernel contracts) you cannot create the account or session in the first place.

---

## Fastest path to a working flow

1. **ZeroDev free tier** → project on **Base Sepolia** → one base URL for both bundler & paymaster;
   enable the gas policy for sponsorship.
2. `echo 0x$(openssl rand -hex 32)` → `SMART_ACCOUNT_SIGNING_KEY`.
3. `INV_IAM_SERVICE_KEY=e4092ace-bcf8-45e0-b3a9-5cb0ef8e7af4`.
4. Chain IDs: rely on defaults (or set Base Sepolia `84532`).
5. Seed Phase A (ZeroDev SDK script → `POST /iam/smart-accounts`).
6. Trigger a tx → hub auto-routes (see [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md) §4).

### If you want zero external providers
Fully-local = Anvil **fork** of Base Sepolia (so Kernel + EntryPoint exist) + self-hosted bundler
(alto) + deploy/fund a local verifying paymaster + **patch** `deserialize-session-key-account.ts`
to drop ZeroDev's hosted paymaster and the `/chain/{chainId}` URL shape. Much more work.

---

## Gas / faucet

**No faucet needed for the sponsored happy path.** Every UserOp is paymaster-sponsored
(`estimateTxCost()` returns `0`), so:

- **Smart account** needs no ETH — its gas, including first-time **deployment** (`initCode` in the
  UserOp), is covered by the paymaster.
- **`SMART_ACCOUNT_SIGNING_KEY`** (delegate co-signer) never submits a tx; the **bundler** does →
  no ETH.
- **Owner (passkey/EOA)** approves the session key via an **off-chain signature**
  (`serializePermissionAccount`), not an on-chain tx → no gas.

With a ZeroDev project on Base Sepolia and its **gas/sponsorship policy enabled**, ZeroDev covers
testnet gas. The only "funding" concern is your paymaster **policy limits** on the dashboard, not a
wallet faucet.

**When you *would* need a faucet:**
- Paymaster disabled / non-sponsored → smart account must hold testnet ETH (not the current code
  path — paymaster is mandatory in `write()`).
- Fully-local Anvil fork → no real faucet; Anvil pre-funds accounts with fake ETH used to
  deploy/fund the local paymaster.
