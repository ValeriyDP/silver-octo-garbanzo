---
name: DevOps How To Onboard Organisation
date: 2026-09-18T15:10:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - how-to
  - devops
  - vault
  - tse
---

# DevOps How To — Onboard Organisation

**Summary**: Operator runbook for IO org create → Hub onboard (`OrganizationToHubProvision`), the IO-only transit mount `inv-hub-tse/`, and per-Vault work. Living infra changelog vs `develop` on `INV-42559-measurabl-anchoring`.

**Infra to land the image** (env + Vault + migrations, no operator steps): [DevOps Infrastructure Landing](DevOps%20Infrastructure%20Landing.md).

**Sources**: `inveniam.io` branch `INV-42559-measurabl-anchoring` vs `origin/develop` (merge-base `efc0b7eb845`); working-tree TSE work. Helm per-env Vault addresses live in `helm_env_configs` (not in this repo).

**Last updated**: 2026-09-30

---

Living document. When Vault, Helm, or env for this flow changes, update **Infrastructure changelog** at the bottom in the same change.

## Two different “create org” steps

| Step | What it creates | Who | Trigger |
| --- | --- | --- | --- |
| 1. IO organisation | IAM resource, `organisations-ms` row, `invhub.organisations` snapshot | IAM / org-ms / hub-ms projectors | `CreateOrganisationRequestedEvent` (local: `create-org.sh`) |
| 2. Hub onboard | Hub organisation, NVNM profile, org wallet, webhook, Vault HubKeys, transit-wrapped mnemonic | `inv-hub-ms` | `OrganizationToHubProvision` |

Step 2 does **not** create the IO org. It needs an existing IO `organisationId`.

## Multi-env Vault (read this first)

IO Vault is **not one box**. Each environment (local compose, each k8s cluster / workload) has its **own** Vault address from `helm_env_configs` workloads. Transit engines and policies do **not** replicate.

| Who talks | Typical address (examples; confirm in `helm_env_configs`) | Role |
| --- | --- | --- |
| Local `inv-hub-ms` (compose) | `https://vault-dev.inveniam.io` | AWS IAM role `$USER` (`HUB_MS_VAULT_ROLE`) |
| k8s `inv-hub-ms` (e.g. dev01) | `https://vault.dev01.inveniam.io` | Kubernetes auth via `vault-k8s-init` / platform `inv-hub-ms` role |
| Other clusters (QA, prod, …) | Per-workload Vault URL | Same pattern: that cluster’s Vault + that env’s role |

Enabling `inv-hub-tse` on `vault-dev` does **nothing** for `vault.dev01`, QA, or prod. Repeat the mount + ACL on **every** IO Vault that an `inv-hub-ms` will call.

Do **not** put this TSE on Hub Vault (`vault-hub-dev.inveniam.io` / `hub-dev-tse` / keyring `wallets`). That is hub-api only.

Do **not** reuse an existing `hub-tse/` mount if you see it on `vault secrets list`. That is not this service’s engine. New path is `inv-hub-tse/`.

KV prefixes (`development/`, `hub/`) are also per Vault. `HUB_MS_VAULT_KV` is `hub` in compose and `helm/configs/hub.yaml`; do not assume another env’s KV mount name without checking that env’s values.

## TSE we need

One **new** Transit secrets engine on **each** IO Vault:

```hcl
vault secrets enable -path=inv-hub-tse transit
```

App env: `HUB_MS_VAULT_TSE_PATH=inv-hub-tse` (code default if unset).

After a **new** org wallet, `InsertOrgMnemonicInTransitStep` calls:

1. `POST {VAULT}/v1/inv-hub-tse/keys/{ioOrganisationId}` — create named key (400/409 = already exists)
2. `POST {VAULT}/v1/inv-hub-tse/encrypt/{ioOrganisationId}` — `{ plaintext: base64(mnemonic) }`
3. Store returned ciphertext on `invhub.io_hub_organisation_map.mnemonic_ciphertext` (not in Vault KV)

Key name is the IO organisation UUID. Not a shared `wallets` keyring. Decrypt uses the ciphertext from that row: `POST inv-hub-tse/decrypt/{ioOrganisationId}`.

### Policy (attach on that Vault)

Grant to: the k8s role used by `inv-hub-ms` **and** (for local compose) personal `$USER` roles.

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

`inv-hub-ms` decrypts the org mnemonic to derive wallets (`readTransitSecret`). Ciphertext lives in `invhub`, not Vault KV. Grant `decrypt` to that role only. Do **not** add a `hub/data/Mnemonic/*` path.

Existing HubKeys writes stay on KV (`hub/Credentials/{ioOrg}/NVNM/{network}`). That path already exists; confirm the same role can still `create`/`update` it. TSE does not replace HubKeys.

### Prove the mount (per Vault)

```bash
export VAULT_ADDR=<that env's IO Vault URL>
# login the way that env expects (AWS IAM locally; do not use Hub Vault login)

vault secrets list | grep inv-hub-tse
# expect: inv-hub-tse/    transit    ...

vault token capabilities inv-hub-tse/keys/probe
vault token capabilities inv-hub-tse/encrypt/probe
vault token capabilities inv-hub-tse/decrypt/probe
```

`vault secrets list` may 403 for developer roles; that is expected on some policies. Then use `token capabilities` on the paths above.

## How to onboard an organisation

### A. Create the IO organisation (if it does not exist)

Local compose helper (does **not** FusionAuth-invite; assigns an **existing** user as Administrator):

```bash
# inveniam.io
./create-org.sh "<org name>" <existing_user_id>
```

Prints `ORG_ID`. That value is `organisationId` for step B.

Shared/QA/prod: use the existing IAM create-org path for that environment. Do not invent a new org row in SQL.

### B. Hub onboard (`OrganizationToHubProvision`)

**Preconditions on that environment**

| Check | Why |
| --- | --- |
| `inv-hub-ms` image includes this branch | Onboard module is new vs `develop` |
| `invhub` migrations applied | `io_hub_organisation_map` |
| `HUB_URL` points at the Hub API for that env | Admin HTTP |
| `HUB_ADMIN_EMAIL` / `HUB_ADMIN_PASSWORD` | Hub admin login |
| `HUB_ON_COMPLETE_WEBHOOK_URL` | Cluster-reachable `inv-hub-ms` webhook URL (`https` hostname or `http://IPv4:port/…`) |
| `EVM_NVNM_URL` + `NVNM_NETWORK_TYPE` | Hub NVNM connection profile |
| `HUB_MS_VAULT_ENDPOINT` = **this env’s IO Vault** | Not Hub Vault |
| `HUB_MS_VAULT_ROLE` / k8s Vault role | Login |
| `HUB_MS_VAULT_KV` | Ciphertext + HubKeys |
| `HUB_MS_VAULT_TSE_PATH=inv-hub-tse` | Mount from section above **already enabled + ACL’d** |

Local emit (compose Rabbit `dev-exchange`):

```bash
./apps/hub-service/scripts/emit-organization-to-hub-provision.sh <organisationId> "<organisationName>"
```

Shared environments: publish the same event on that env’s broker. Payload: `organisationId`, `organisationName` only. Consumer: `hub` (`EventsConstants`).

**Done when**

- `invhub.io_hub_organisation_map` has `(io_organisation_id, hub_organisation_id)`
- Hub UI shows the organisation
- If a **new** org wallet was created: transit key `inv-hub-tse/keys/{ioOrg}` exists and `mnemonic_ciphertext` is set on the map row
- Replay / existing wallet: mnemonic step is skipped (no mnemonic on context)
- Organisation NVNM wallet holds native gas (send on `EVM_NVNM_URL` to the address from THE HUB UI or `GET {HUB_URL}/organizations/{hubOrganisationId}/wallets/ledger-type/NVNM`). Onboard is not complete until that send lands.

**Organisation wallet top-up (during this onboard)**

After the wallet exists, before treating onboard as done:

1. Read `hub_organisation_id` from `io_hub_organisation_map`.
2. Take the NVNM address from THE HUB UI or `GET {HUB_URL}/organizations/{hubOrganisationId}/wallets/ledger-type/NVNM`.
3. Send native NVNM to that address on the same RPC as `EVM_NVNM_URL`. Size for later Identity top-ups.

Logs: `docker logs inv-hub-ms | rg client-provisioning` (or the k8s equivalent). Failures on TSE are Vault 403 / “Couldn’t create Vault transit secret”.

## Helm / k8s notes

`helm/configs/hub.yaml` on this branch still only sets `HUB_MS_VAULT_KV: "hub"` (same as `develop`). It does **not** yet set TSE path, Hub admin, webhook, or `EVM_NVNM_URL`.

Those must land in `helm_env_configs` (gotmpl + per-env overlay) **and** be copied into this changelog when added:

- `HUB_MS_VAULT_TSE_PATH=inv-hub-tse`
- `HUB_MS_VAULT_ENDPOINT` already per-workload — confirm it is the **IO** Vault, not Hub
- `HUB_ADMIN_EMAIL` / `HUB_ADMIN_PASSWORD` (secret refs, not literals in git)
- `HUB_ON_COMPLETE_WEBHOOK_URL` — cluster-reachable URL of `inv-hub-ms` on-complete
- `EVM_NVNM_URL`

Auth on the pod stays Kubernetes (`vault-k8s-init`). Policy attach is on the **Vault role that init uses for that cluster**, not on `sso-developer-role`.

## PR vs `develop` — infrastructure surface

Compared `INV-42559-measurabl-anchoring` to `origin/develop` (plus uncommitted TSE/event-split work that belongs in the same PR). Application-only files omitted unless they force infra.

| Change | In commits vs `develop` | Working tree (not committed yet) | DevOps action |
| --- | --- | --- | --- |
| `invhub.io_hub_organisation_map` (+ `mnemonic_ciphertext`) | Table in commits vs `develop`; ciphertext column on the same migration | Yes | Run hub-service migrations |
| `HUB_ADMIN_EMAIL` / `HUB_ADMIN_PASSWORD` | Yes — `environment.ts` | Local values in untracked `docker-compose.override.yml` | Set per env (secret) |
| `HUB_ON_COMPLETE_WEBHOOK_URL` | Yes — `environment.ts` | Local default in override | Public/cluster URL Hub can POST |
| `EVM_NVNM_URL` | Yes — `environment.ts` `networkUrl.NVNM` | Local override `https://evm.testnet.nvnmchain.io` | Set per env |
| `HUB_MS_VAULT_TSE_PATH` + `createTransitSecret` / `readTransitSecret` | No | Yes — default `inv-hub-tse`; compose line added | New transit mount + encrypt/decrypt ACL on **each** IO Vault |
| Event `OrganizationToHubProvision` → `hub` | No | Yes | Broker routing already event-name based; rebuild `@inveniam/events` |
| `HUB_MS_VAULT_ENDPOINT` / `ROLE` / `KV` | Already on `develop` + compose | TSE path only | Reuse; add TSE policy |
| `helm/configs/hub.yaml` TSE / admin / webhook | No change vs `develop` | No | **Still missing** — add in `helm_env_configs` |
| New IO transit `inv-hub-tse/` | — | Requested; not in Vault yet | Enable + policy per Vault |
| Hub TSE `hub-dev-tse` / `hub-tse/wallets` | Unchanged | Unchanged | No change. Do not reuse. |

`create-org.sh` and the emit scripts are local helpers (untracked / new). They are not a deploy artifact.

## Verify after deploy

```bash
# 1) migrations
# invhub.io_hub_organisation_map must include mnemonic_ciphertext

# 2) this Vault (repeat per env)
vault secrets list | grep inv-hub-tse

# 3) onboard
# publish OrganizationToHubProvision

# 4) map + ciphertext (do not print the secret; existence is enough)
# SELECT io_organisation_id, hub_organisation_id,
#        mnemonic_ciphertext IS NOT NULL AS has_ciphertext
# FROM io_hub_organisation_map;
```

## Infrastructure changelog

Append a dated row when Vault, Helm, env, or tables for this flow change. Newest at the bottom.

| Date | Env / Vault | Change | Ticket / PR |
| --- | --- | --- | --- |
| 2026-09-18 | all (code) | App default TSE path `inv-hub-tse`. Do not reuse `hub-tse/`. | INV-42559 working tree |
| 2026-09-18 | local compose | `HUB_MS_VAULT_TSE_PATH=inv-hub-tse` in `docker-compose.yml`. Compose still uses `HUB_MS_VAULT_ENDPOINT=https://vault-dev.inveniam.io`. | INV-42559 working tree |
| 2026-09-18 | vs `develop` | New `invhub` table `io_hub_organisation_map`. New env: admin Hub login, on-complete webhook, `EVM_NVNM_URL`. | `INV-42559-measurabl-anchoring` |
| 2026-09-18 | `vault-dev.inveniam.io` | Mount `inv-hub-tse/` enabled. Manual `keys/probe` + encrypt/decrypt round-trip (`alpha beta gamma`). | local |
| — | other IO Vaults | **Pending:** same `inv-hub-tse` mount + ACL (not replicated from vault-dev). | DevOps |
| 2026-09-18 | `invhub` | Ciphertext stored on `io_hub_organisation_map.mnemonic_ciphertext`, not Vault KV. | INV-42559 working tree |
| — | `vault-dev` + k8s roles | **Pending:** ACL on `inv-hub-ms` role and local `$USER` (`keys/*` create/update/read, `encrypt/*` + `decrypt/*` update). No `hub/data/Mnemonic/*`. CLI test used an admin-capable token. | DevOps |
| — | `helm_env_configs` | **Pending:** TSE path, Hub admin secrets, webhook URL, `EVM_NVNM_URL` on `inv-hub-ms`. | DevOps |

## Related pages

- [Wiki Index](INV-42559%20-%20Measurabl%20provision/wiki/index.md)
- [Organisation Provisioning Chain](Hub%20Onboarding%20Chain.md)
- [Open Questions](INV-42559%20-%20Measurabl%20provision/wiki/Open%20Questions.md) (#10 TSE decrypt)
