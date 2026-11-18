---
name: Measurabl Provisioning DevOps
date: 2026-09-30T14:03:00.000Z
tags:
  - measurabl-provision
  - wiki
  - devops
  - vault
  - helm
---

# Measurabl Provisioning DevOps

**Summary**: What to land for IO Hub Service organisation provisioning. Vault transit, `invhub` schema, helm, webhook, and prove. THE HUB is unchanged.

**Sources**: `inveniam.io` `apps/hub-service` migrations and `config/database.ts` (`migrationsRun: true`). `helm_env_configs` `apps/inveniam/values/hub.yaml.gotmpl` versus `origin/master`. Cluster transit policy on the IO Hub Service Vault role.

**Last updated**: 2026-10-09

---

Audience: platform / DevOps. Application path: `~/work/inveniam/inveniam.io`. Helm values: `~/work/inveniam/helm_env_configs`.

## Scope

**THE HUB** is a third-party signer. Not part of IO. Black box. Do not change THE HUB repository, APIs, THE HUB Vault (`vault-hub-*`, `hub-tse/`, keyring `wallets`), or THE HUB key layout.

**IO Hub Service** is IO `inv-hub-ms` (`apps/hub-service`). It calls THE HUB HTTP API and receives THE HUB webhooks. This landing is IO Vault, `invhub`, and IO Hub Service env only.

Each environment is independent. Local Vault does not replicate to cluster Vault. Repeat mount, policy, and prove on every IO Vault that IO Hub Service will use.

Order: enable transit on **that** env’s IO Vault and attach the pod role → ship helm values → deploy IO Hub Service → prove tables and Vault.

## Separate transit (TSE)

THE HUB Vault already has a transit path (`hub-tse/`) and a wallets keyring. That engine is hub-api only. IO Hub Service must not mount it, write it, or share its policy.

IO Hub Service needs a wrapping key for the organisation HD seed. THE HUB `generate` / `derive` returns a mnemonic and a leaf in memory and persists the **key pair** on THE HUB, not the phrase. Later Identity wallets are further leaves on the **same** seed (`m/44'/60'/0'/0/{n}`). IO Hub Service must keep that seed. It cannot store plaintext. It cannot put the phrase on THE HUB. It cannot mix the phrase into HubKeys KV (those are `service-login` credentials for writes).

So IO Vault gets its **own** transit mount. Path = `HUB_MS_VAULT_TSE_PATH`:

| Runtime | Mount |
| --- | --- |
| Cluster | `inveniam-<env>-hub-tse` (helm default; no overlay sets `hub_ms_vault_tse_path`) |
| Local compose | `inv-hub-tse` |

Do not reuse `hub-tse/` if it already exists on IO Vault. That is a different engine.

Transit holds the **named wrapping key** (name = IO organisation UUID). It does not store the mnemonic. Encrypt returns ciphertext. Decrypt needs that ciphertext plus the role. Split knowledge: Vault alone or the database alone is not enough to recover the phrase. Decrypt is IO Hub Service only.

```bash
export VAULT_ADDR=<this env IO Vault URL>
vault secrets enable -path="$HUB_MS_VAULT_TSE_PATH" transit
```

Cluster IO Hub Service role:

```hcl
path "inveniam-<env>-hub-tse/keys/+"    { capabilities = ["update"] }
path "inveniam-<env>-hub-tse/encrypt/+" { capabilities = ["update"] }
path "inveniam-<env>-hub-tse/decrypt/+" { capabilities = ["update"] }
```

`+` is one path segment (the IO organisation UUID). Transit create-key is `update` on `keys/+`. There is no `read` or `list` on keys. `vault secrets list` and capabilities on `keys/probe` may 403 even when encrypt / decrypt work.

Local compose uses mount `inv-hub-tse` and is not this cluster policy.

## Ciphertext in IO Hub Service DB

`io_hub_organisation_map` is the 1:1 IO organisation ↔ THE HUB organisation row (`invhub`). Column `mnemonic_ciphertext` is the transit ciphertext.

On first org wallet create, IO Hub Service:

1. `update` `$TSE/keys/{ioOrganisationId}`
2. `update` `$TSE/encrypt/{ioOrganisationId}` with the mnemonic
3. Writes the returned ciphertext to `io_hub_organisation_map.mnemonic_ciphertext`

Replay against an existing wallet skips encrypt (no mnemonic on the handler). Later Identity-wallet derive: read ciphertext from the row, `update` `$TSE/decrypt/{ioOrganisationId}`, derive the next leaf, discard the phrase.

The wrapping key never leaves Vault. The phrase is not in Vault KV, not in THE HUB, and not in HubKeys. Only ciphertext is in `invhub`. Do not print it. Existence is enough:

```sql
SELECT io_organisation_id,
       hub_organisation_id,
       mnemonic_ciphertext IS NOT NULL AS has_ciphertext
FROM io_hub_organisation_map;
```

## Schema

Migrations live in `apps/hub-service/src/migrations/`. TypeORM runs them automatically on IO Hub Service startup (`migrationsRun: true` in `apps/hub-service/src/config/database.ts`). There is no separate migrate job.

| File | Establishes |
| --- | --- |
| `1789471435157-add-deal-anchors-table.ts` | `deal_anchors` |
| `1789600000000-add-deal-anchors-pending-document.ts` | `deal_anchors.pending_document` |
| `1789548200000-add-io-hub-organisation-map-table.ts` | `io_hub_organisation_map` (`mnemonic_ciphertext`) |
| `1789700000000-add-io-hub-organisation-map-identity-wallet-index.ts` | `io_hub_organisation_map.identity_wallet_index` |

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_name IN ('deal_anchors', 'io_hub_organisation_map')
ORDER BY table_name, ordinal_position;
```

Required: `deal_anchors.pending_document`, `io_hub_organisation_map.mnemonic_ciphertext`, `io_hub_organisation_map.identity_wallet_index`.

## Helm (IO Hub Service)

`helm_env_configs` versus `origin/master` (that repo has no `develop`). Chart in inveniam.io does not add these keys. Wiring: `apps/inveniam/values/hub.yaml.gotmpl`.

```gotmpl
HUB_ADMIN_EMAIL: vault://{{ $vaultKv }}/service/hub/thehub/admin/email
HUB_ADMIN_PASSWORD: vault://{{ $vaultKv }}/service/hub/thehub/admin/password
HUB_ON_COMPLETE_WEBHOOK_URL: "https://{{ .Values | getOrNil "url_api" | default (printf "%s-api.%s" $env .Values.zone_name) }}/hub/transactions/on-complete"
EVM_NVNM_URL: {{ .Values.blockchain_nvnm_network_rpc }}
HUB_MS_VAULT_TSE_PATH: {{ .Values | getOrNil "hub_ms_vault_tse_path" | default (printf "inveniam-%s-hub-tse" $env) }}
```

| Variable | Source | Role |
| --- | --- | --- |
| `HUB_ADMIN_EMAIL` / `HUB_ADMIN_PASSWORD` | Vault `service/hub/thehub/admin/{email,password}` | THE HUB `POST /auth/login` for onboard. Values are not in git |
| `HUB_ON_COMPLETE_WEBHOOK_URL` | `https://{url_api or {env}-api.{zone}}/hub/transactions/on-complete` | THE HUB POSTs job complete here. Cluster: `https://` hostname. Not a Kubernetes service DNS name |
| `EVM_NVNM_URL` | `blockchain_nvnm_network_rpc` | NVNM JSON-RPC (THE HUB profile + IO Hub Service `eth_estimateGas` / parent top-up) |
| `HUB_MS_VAULT_TSE_PATH` | default `inveniam-{env}-hub-tse` | Must equal the transit mount on **this** IO Vault |

`blockchain_nvnm_network_rpc`: non-live default `https://evm.testnet.nvnmchain.io` (`defaults.yaml`). Live overlays `https://evm.nvnmchain.io`. An overlay that sets `blockchain_nvnm_network_type: mainnet` without the RPC inherits the non-live URL.

Already in the same gotmpl. `HUB_MS_VAULT_ENDPOINT` must be **IO** Vault, not THE HUB Vault:

| Variable | Source | Must be |
| --- | --- | --- |
| `HUB_URL` | `https://{url_hub or hub-{env}-api.{zone}}` | That env’s THE HUB API |
| `HUB_MS_VAULT_ENDPOINT` | `.Values.vault_address` | That env’s IO Vault. Not `vault-hub-*` |
| `HUB_MS_VAULT_ROLE` | `vault_role`, else `{Environment.Name}-cluster-inv-hub-pod-role` | IO Hub Service pod role on that cluster |
| `HUB_MS_VAULT_KV` | `hub-{env}-inveniam` | Existing IO KV for HubKeys |
| `NVNM_NETWORK_TYPE` | `blockchain_nvnm_network_type` (non-live `testnet`; live `mainnet`) | THE HUB profile `networkId` |
| `HUB_WRITE_API_VERSION` | `ms_hub_write_api_version` (`v3` in `defaults.yaml`) | `v3` |

Optional quote knobs are not in helm. Code defaults: `NVNM_GAS_PRICE_HEADROOM_PERCENT` (`120`), `NVNM_ADD_RECORD_EOA_GAS_STAND_IN` (`166014`).

Existing organisation HubKeys stay in IO Vault KV. TSE does not replace them.

## Broker

`OrganizationToHubProvision` and `ClientDLTTransaction` are consumed by IO Hub Service only. No new queue. Ship the events package with the image.

## Prove

```text
[ ] invhub columns above exist after pod start (migrations already ran)
[ ] five new env vars on IO Hub Service; HUB_MS_VAULT_ENDPOINT is IO Vault
[ ] HUB_MS_VAULT_TSE_PATH equals the transit mount on that IO Vault
[ ] IO Hub Service role can update keys/+ encrypt/+ decrypt/+
[ ] THE HUB can POST HUB_ON_COMPLETE_WEBHOOK_URL (1301 = unreachable, 1307 = bad URL shape)
[ ] first new-wallet onboard: map row has ciphertext (do not print it)
```

Logs: marker `client-provisioning`. TSE failures: Vault 403 or “Couldn’t create Vault transit secret”. Missing required env: fail before THE HUB login; grep `required env is missing`. Replay body is the inbound payload.

Local:

```bash
./apps/hub-service/scripts/emit-organization-to-hub-provision.sh <organisationId> "<organisationName>"
./apps/hub-service/scripts/emit-client-dlt-transaction.sh
```

SNS:

```bash
SNS_TOPIC_ARN="<...>" \
AWS_PROFILE=<...> \
./apps/hub-service/scripts/emit-organization-to-hub-provision-sns.sh <organisationId> "<organisationName>"

SNS_TOPIC_ARN="<...>" \
AWS_PROFILE=<...> \
./apps/hub-service/scripts/emit-client-dlt-transaction-sns.sh <organisationId> <dealId> <taxonomyId>
```

`taxonomyId` must be `data_room_file_taxonomies.id`.

## Native funding

Two wallets. Do not mix them.

**Organisation wallet** — during onboard, after `EnsureHubWalletStep`. IO Hub Service creates the wallet; onboard then funds it.

1. Read `hub_organisation_id` from `io_hub_organisation_map` for that IO org.
2. Take the NVNM address from THE HUB UI, or `GET {HUB_URL}/organizations/{hubOrganisationId}/wallets/ledger-type/NVNM`.
3. Send **native** NVNM (the funding for writes on that network) to that address on the same RPC as `EVM_NVNM_URL` (non-live testnet vs live mainnet).
4. Size the pile for later Identity top-ups: the organisation wallet is the parent that pays Identities.
5. Onboard is not complete until that wallet holds funding.

**Identity wallet** — not an ops send. On `ClientDLTTransaction`, `EnsureRegistryFundsStep` / `EnsureDocumentFundsStep` quote the Identity, then the organisation leaf `m/44'/60'/0'/0/0` sends `required − leftover` on `EVM_NVNM_URL`. Leftover already covering the buffer: no transfer. Organisation wallet empty because onboard skipped the top-up: that step fails; taxonomy sync does not start.

THE HUB `write()` `value` stays `0`. Do not use THE HUB write to fund either wallet.

## Out of scope

THE HUB is unchanged. This landing does not create FusionAuth users.
