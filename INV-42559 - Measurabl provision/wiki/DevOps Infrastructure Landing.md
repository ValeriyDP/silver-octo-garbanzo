---
name: DevOps Infrastructure Landing
date: 2026-09-22T12:38:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - devops
  - vault
  - env
---

# DevOps — infrastructure to land INV-42559

Standalone handoff for **`inv-hub-ms`** on `INV-42559-measurabl-anchoring`. Do this on **every** environment that will run this image (local Vault ≠ cluster Vault; nothing replicates).

This is not an onboarding runbook. It is only what infrastructure must change before the image can create a Hub org, wrap the org mnemonic, and complete Register / Sync.

**Do not** change Hub Vault (`vault-hub-*`, `hub-tse/`, keyring `wallets`). That is hub-api only.

---

## 1. Order of work

1. Enable transit mount `inv-hub-tse/` + attach ACL on **that env’s IO Vault**.
2. Set the env vars below on `inv-hub-ms` (`helm_env_configs` / secrets — not literals in git).
3. Deploy the image. Hub-service migrations run with the app.
4. Prove Vault paths and that the new tables exist.

---

## 2. Database (`invhub`)

Migrations ship in the image. Confirm after deploy:

| Table / column | Migration | Why |
| --- | --- | --- |
| `deal_anchors` | `1789471435157` | Deal projector; `registry` + portfolio ids |
| `deal_anchors.pending_document` | `1789600000000` | jsonb map keyed by `taxonomyId` until register webhook |
| `io_hub_organisation_map` | `1789548200000` | IO org ↔ Hub org; `mnemonic_ciphertext` |

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_name IN ('deal_anchors', 'io_hub_organisation_map')
ORDER BY table_name, ordinal_position;
```

Expect `deal_anchors.pending_document` and `io_hub_organisation_map.mnemonic_ciphertext`.

---

## 3. ENV updates (`inv-hub-ms`)

### New — must set per environment

| Variable | Example / shape | Notes |
| --- | --- | --- |
| `HUB_ADMIN_EMAIL` | Hub admin user | Secret. Used for `POST {HUB_URL}/auth/login`. |
| `HUB_ADMIN_PASSWORD` | | Secret. Same login. |
| `HUB_ON_COMPLETE_WEBHOOK_URL` | `https://<inv-hub-ms-host>/hub/transactions/on-complete` | Hub must be able to POST this. Hub accepts **`https://` hostname** or **`http://IPv4:port/...`**. Not `http://service-name`. |
| `EVM_NVNM_URL` | testnet: `https://evm.testnet.nvnmchain.io` | NVNM JSON-RPC. Used for Hub connection profile **and** identity `eth_estimateGas` / parent top-up. |
| `HUB_MS_VAULT_TSE_PATH` | `inv-hub-tse` | Must match the mount in §4. Code default is `inv-hub-tse` if unset; set it explicitly. |

### Confirm already present (do not point at Hub Vault)

| Variable | Must be |
| --- | --- |
| `HUB_URL` | That env’s **Hub API** (not IO) |
| `HUB_MS_VAULT_ENDPOINT` | That env’s **IO Vault** (`vault-dev` / `vault.dev01` / QA / prod). **Not** `vault-hub-*` |
| `HUB_MS_VAULT_ROLE` | Role `vault-k8s-init` uses for `inv-hub-ms` on that cluster (local compose: `$USER` / `HUB_MS_VAULT_ROLE`) |
| `HUB_MS_VAULT_KV` | Existing KV mount (compose / helm default `hub`) |
| `NVNM_NETWORK_TYPE` | `testnet` or that env’s NVNM network id (Hub profile `networkId`) |
| `HUB_WRITE_API_VERSION` | `v3` (job id + poll). Already used on compose. |

`helm/configs/hub.yaml` on this branch still only sets `HUB_MS_VAULT_KV`. The new vars must land in **`helm_env_configs`** (gotmpl + per-env overlay).

---

## 4. Vault setup (IO Vault only)

Repeat on **each** IO Vault that an `inv-hub-ms` will call.

### Mount

```bash
export VAULT_ADDR=<this env IO Vault URL>
# login the way that env expects (k8s auth on cluster; AWS IAM locally)

vault secrets enable -path=inv-hub-tse transit
```

Do **not** reuse `hub-tse/` if `vault secrets list` shows it. That is a different engine.

### Policy (attach to the `inv-hub-ms` Vault role on that Vault)

Also attach to local `$USER` roles if developers run compose against this Vault.

```hcl
path "inv-hub-tse/keys/*" {
  capabilities = ["create", "update", "read"]
}

path "inv-hub-tse/encrypt/*" {
  capabilities = ["update"]
}

path "inv-hub-tse/decrypt/*" {
  capabilities = ["update"]
}
```

Decrypt is required. The service unwraps the org mnemonic to derive identity wallets. Ciphertext lives in `invhub.io_hub_organisation_map.mnemonic_ciphertext`, not in Vault KV. Do **not** add a `hub/data/Mnemonic/*` path.

Existing HubKeys KV (`hub/Credentials/{ioOrg}/NVNM/{network}`) stays as-is. Confirm the same role can still `create` / `update` that path. TSE does not replace HubKeys.

### What the app calls

Key name = IO organisation UUID.

1. `POST {VAULT}/v1/inv-hub-tse/keys/{ioOrganisationId}` — create named key (400/409 = already exists)
2. `POST {VAULT}/v1/inv-hub-tse/encrypt/{ioOrganisationId}` — `{ "plaintext": "<base64 mnemonic>" }`
3. Store ciphertext on the map row
4. Later: `POST {VAULT}/v1/inv-hub-tse/decrypt/{ioOrganisationId}` — `{ "ciphertext": "<from db>" }`

### Prove (per Vault)

```bash
export VAULT_ADDR=<this env IO Vault URL>

vault secrets list | grep inv-hub-tse
# expect: inv-hub-tse/    transit

# if secrets list 403s (some developer policies), use:
vault token capabilities inv-hub-tse/keys/probe
vault token capabilities inv-hub-tse/encrypt/probe
vault token capabilities inv-hub-tse/decrypt/probe
# expect: create and/or update on keys; update on encrypt and decrypt
```

Optional round-trip with an admin-capable token (not required in prod):

```bash
vault write -f inv-hub-tse/keys/probe
vault write inv-hub-tse/encrypt/probe plaintext=$(printf 'alpha beta gamma' | base64)
# then decrypt the returned ciphertext
vault delete inv-hub-tse/keys/probe
```

---

## 5. Broker

New events are consumed by **`hub`** only (`OrganizationToHubProvision`, `ClientDLTTransaction`). Routing is event-name based via `@inveniam/events`. No new queue. Rebuild / ship the events package with the image.

---

## 6. Verify after deploy

```text
[ ] invhub tables: deal_anchors (+ pending_document), io_hub_organisation_map (+ mnemonic_ciphertext)
[ ] inv-hub-ms has the five new env vars; HUB_MS_VAULT_ENDPOINT is IO Vault
[ ] vault secrets list (or token capabilities) shows inv-hub-tse/ on that env’s IO Vault
[ ] inv-hub-ms role can keys/* + encrypt/* + decrypt/*
[ ] Hub can POST HUB_ON_COMPLETE_WEBHOOK_URL (Hub error 1301 = unreachable; 1307 = bad URL shape)
```

On first successful `OrganizationToHubProvision` for a **new** org wallet:

```sql
SELECT io_organisation_id,
       hub_organisation_id,
       mnemonic_ciphertext IS NOT NULL AS has_ciphertext
FROM io_hub_organisation_map;
```

Do not print ciphertext. Existence is enough. Replay / existing wallet skips the mnemonic write.

App logs: marker `client-provisioning`. TSE failures look like Vault 403 or “Couldn’t create Vault transit secret”.

If a required env is missing, the first chain step fails **before** Hub login and logs the inbound event **payload** (not CoR context) so it can be replayed after config is fixed. Grep `required env is missing`.

- org: `eventName: OrganizationToHubProvision` + `payload: { organisationId, organisationName }` → `scripts/emit-organization-to-hub-provision.sh`
- document / ClientDLT: `eventName: ClientDLTTransaction` + `payload: { dealId, taxonomyId, organisationId, uri, checksum, checksumAlgo }` → `scripts/emit-client-dlt-transaction.sh`

---

## 7. Not this ticket

| Item | Why |
| --- | --- |
| Hub Vault / `hub-tse/` / `wallets` keyring | Unchanged |
| FusionAuth invite / new IO org process | Unchanged |
| Funding the Hub org wallet with NVNM native gas | During onboard, not an env var |
| Changing Hub estimate / write APIs | Out of scope |

---

## Related (optional)

Operator onboard steps (create IO org, emit events): [DevOps How To Onboard Organisation](DevOps%20How%20To%20Onboard%20Organisation.md).
