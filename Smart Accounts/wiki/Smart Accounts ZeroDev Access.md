---
name: Smart Accounts ZeroDev Access
date: 2026-08-11T15:42:00.000Z
tags:
  - smart-accounts
  - zerodev
  - access
  - credentials
  - config
---
# Smart Accounts — ZeroDev Project & Dashboard Access

Companion to [Smart Accounts Implementation State](Smart%20Accounts%20Implementation%20State.md), [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md),
[Smart Accounts Obtaining Config Values](Smart%20Accounts%20Obtaining%20Config%20Values.md), and [Smart Accounts UI Wiring and Selection](Smart%20Accounts%20UI%20Wiring%20and%20Selection.md).
Investigation trigger: "can we access https://dashboard.zerodev.app/ or not?"

---

## TL;DR

**No — not from anything in the repo.** We have the ZeroDev **project ID** (public, client-side
identifier) and confirmed the project is **live**, but there are **no ZeroDev dashboard login
credentials anywhere in the codebase**. Dashboard access needs the ZeroDev *account* login
(email / Google / GitHub / wallet) that owns or was invited to the project — which is not stored
in git.

---

## The project (real, in active use)

A single ZeroDev project is wired consistently across local, QA, and both cloud deploys:

- `ZERODEV_PROJECT_ID = 00d5dd30-2df5-4d84-a7dd-d00f18be64ad`
- `SMART_ACCOUNT_NETWORK = testnet`
- `INVENIAM_WALLET_ADDRESS = 0xfF26B89859E64E731c5396aC9114DA602C991F4f`
- `THIRDWEB_CLIENT_ID = 0760fd03744bd106de5388e8ed65e843` (thirdweb, for the embedded/passkey wallet)

**Where it's configured:**
- `inveniam-v2/apps/browser/shell/.env`, `.env.qa4`, `.env.qa5`, `.env.qa10`, `.env.qa13`
- `inveniam-v2/docker-compose.yml`
- `inveniam-v2/apps/browser/shell/deployment_to_kubernetes/values.aws.tfvars_template`
- `inveniam-v2/apps/browser/shell/deployment_to_kubernetes/values.azure.tfvars_template`

**Bundler/paymaster URL shape** (built in `smart-accounts-core/.../provide-smart-account-environment.ts`):
`https://rpc.zerodev.app/api/v3/00d5dd30-2df5-4d84-a7dd-d00f18be64ad` → per-chain `.../chain/{chainId}`.

## Liveness check (probed 2026-08-11)

`POST https://rpc.zerodev.app/api/v3/00d5dd30-.../chain/84532`:
- `eth_chainId` → `0x14a34` (84532, Base Sepolia) ✅
- `eth_supportedEntryPoints` → includes `0x0000000071727De22E5E9d8BAf0edAc6f37da032` (EntryPoint v0.7) ✅

So the project exists and its bundler is reachable on testnet.

## Why project ID ≠ dashboard access

The project ID is a **public client-side identifier** — it ships in the browser bundle and in the
`.env`/tfvars by design. It authorises *using* the bundler/paymaster RPC, but does **not**
authenticate to the dashboard. Managing the project (gas/sponsorship policy, limits, API keys,
team members) requires the owning ZeroDev account login. Searched the repos for any ZeroDev
account email / password / token / login — **none found** (only the project ID and public client IDs).

## Server-side note

The v2 **frontend** talks to ZeroDev directly (account creation, session keys, client-side UserOps
via kernel clients). The **hub-service** server path (`SMART_ACCOUNT_BUNDLER_URL` /
`SMART_ACCOUNT_PAYMASTER_URL` in `hub-service/src/config/environment.ts`) is **not set in any
committed config** — only the frontend has the ZeroDev project configured.

---

## Open questions — "where is ZeroDev?"

- **Who owns the ZeroDev account** that created project `00d5dd30-2df5-4d84-a7dd-d00f18be64ad`?
  (Which person / email / SSO? Individual dev account or an Inveniam org/team account?)
- **Where do the dashboard login credentials live** — team password manager (1Password/Bitwarden),
  HashiCorp Vault, or only in one engineer's head? Is there a shared "ZeroDev" vault entry?
- **Can we be invited to the project team** in the ZeroDev dashboard instead of sharing a login?
- **Is the paymaster sponsorship policy enabled and funded** for this project on the testnets
  (Sepolia / Base Sepolia / Amoy)? That is only visible/manageable from the dashboard. (Not yet
  probed — would require attempting a sponsored UserOp or dashboard access.)
- **Is there a separate mainnet project**, or is `00d5dd30-...` testnet-only? (`SMART_ACCOUNT_NETWORK=testnet`
  everywhere suggests testnet-only so far.)
- **hub-service gap:** since `SMART_ACCOUNT_BUNDLER_URL`/`PAYMASTER_URL` are unset server-side, does
  any real backend on-chain execution happen today, or is it all client-driven via the frontend?

## Next steps to actually gain access

1. Identify the project owner (ask web3/infra leads) and request a **ZeroDev team invite** to
   project `00d5dd30-2df5-4d84-a7dd-d00f18be64ad`.
2. Check the team secrets manager / Vault for a "ZeroDev" account entry.
