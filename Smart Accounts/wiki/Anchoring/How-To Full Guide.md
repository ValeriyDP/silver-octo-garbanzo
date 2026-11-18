---
name: How-To Full Guide
date: 2026-08-12T10:25:18.593Z
tags:
  - smart-accounts
  - anchoring
  - evm-precompile
  - nvnm-testnet
  - cosmos-cli
  - integration
---
Yes — there **is** information in the workspace about how to use the anchoring module, but it is spread across several docs. The most relevant pages are:

- [**Anchoring Module: Technical Specification**](https://app.notion.com/p/Anchoring-Module-Technical-Specification-2ee5c45f06f081dd8baac008e3cf2f34?pvs=21) — core module concepts, CLI commands, registries, records, RBAC, queries.[^1]
- [Anchoring Module: EVM Precompile Technical Specification](https://app.notion.com/p/Anchoring-Module-EVM-Precompile-Technical-Specification-2ee5c45f06f0815686bac34ec0895f93?pvs=21) — how applications call the anchoring module through the EVM precompile at `0x0000000000000000000000000000000000000A00`.[^2]
- [📑 Document Anchoring Workflow (EVM Precompile)](https://app.notion.com/p/Document-Anchoring-Workflow-EVM-Precompile-2f75c45f06f080b494f0ea1c881b9fa0?pvs=21) — beginner-friendly workflow for creating a registry, anchoring a document, and verifying it later.[^3]
- [nvnm-testnet-1 — Faucet & Network Info](https://app.notion.com/p/nvnm-testnet-1-Faucet-Network-Info-3435c45f06f08014a0affaf958225630?pvs=21) and [faucet-and-testnet-tokens](https://app.notion.com/p/faucet-and-testnet-tokens-3495c45f06f080a7989ed4fe1d269415?pvs=21) — wallet setup, testnet faucet/token flow, binaries, `cast`, CLI commands, testnet endpoints.[^4][^5]
- [Anchoring Module Upgrade: v1.1.0 → v1.2.0 Integration Guide](https://app.notion.com/p/Anchoring-Module-Upgrade-v1-1-0-v1-2-0-Integration-Guide-3b35c45f06f0808da7a9c308ef32aba6?pvs=21) — **important latest integration note**: apps should use numeric `registry_id`, not registry name, in newer versions.[^6]

Below is the practical “from zero” guide based on those docs.

> [!info] Related notes
> - [How-To Integration Only](How-To%20Integration%20Only.md) — condensed integration-centric path (backend/EVM signer, `cast`, faucet setup).
> - [How-To MetaMask](How-To%20MetaMask.md) — browser wallet signing path (no private keys in the app).
> - [Smart Accounts Obtaining Config Values](../Smart%20Accounts%20Obtaining%20Config%20Values.md) — where to source RPC URLs, chain IDs, and contract addresses.

---

## 1. What the anchoring module does

The anchoring module lets your application store a **cryptographic proof** of some off-chain data on-chain.

Typical example:

1. Your app has a file, document, JSON payload, report, or attestation.
2. Your app computes a checksum, usually `sha256`.
3. The actual file/data stays off-chain — S3, IPFS, your backend, etc.
4. You write the checksum + URI + metadata to the anchoring module.
5. Later, anyone can recompute the checksum and compare it to the on-chain record.

The chain is **not** verifying the file for you. It is an **attestation ledger**: it records that an authorized wallet anchored a checksum at a specific time.[^3]

---

## 2. Core concepts you need to know

### Registry

A **registry** is a logical container for records — like a folder or table.

Example registries:

- `legal-contracts`
- `customer-documents`
- `ai-agent-attestations`
- `kyc-reports`

Creating a registry gives you a `registryId`. You need this ID when adding records.[^1]

> Important: the newer v1.2.0 integration guide says registry names are no longer reliable identifiers. Your application should store and use the numeric `registry_id` / `registryId`.[^6]

### Record

A **record** is one anchored item inside a registry.

It usually contains:

- `registryId` — which registry this belongs to
- `uri` — where the off-chain document/data lives
- `checksum` — hash of the file/data
- `checksumAlgo` — for example `sha256`
- `metadata` — optional stringified JSON
- `status` — for example `active`, `revoked`, `deprecated`

The module supports versioning. Re-anchoring the same checksum in the same registry can create a new version/index depending on module behavior.[^1]

### Roles

The module uses RBAC permissions:

- `admin` — can add/update records and grant/revoke roles
- `editor` — can add records and update status
- reads/queries are public; no viewer role is required

The creator of a registry automatically becomes admin for that registry.[^1][^2]

---

## 3. Integration options

There are two main ways to integrate.

### Option A — EVM integration

Use this if your application is EVM-style:

- Solidity
- ethers.js
- web3.js
- web3.py
- MetaMask/Rabby
- Foundry `cast`
- JSON-RPC

The anchoring module is exposed through an **EVM precompile** at:

```
0x0000000000000000000000000000000000000A00
```

Your app sends EVM transactions to this address, with ABI-encoded calls like:

- `addRegistry(...)`
- `addRecord(...)`
- `records(...)`
- `registries(...)`
- `grantRole(...)`
- `revokeRole(...)`
- `updateRecordStatus(...)`

This is likely the easiest path for application developers.[^2]

### Option B — Native Cosmos CLI / SDK integration

Use this if your application or backend works directly with Cosmos SDK messages.

CLI examples include:

```bash
inveniamd tx anchoring add-registry --name <name>
inveniamd tx anchoring add-record --record <path-to-record-json>
inveniamd q anchoring params
inveniamd q anchoring registry --id <registry-id>
inveniamd q anchoring records --registry-id <registry-id> --checksum <checksum>
```

The technical spec contains these native CLI commands.[^1]

---

## 4. What you need to install

For testnet onboarding, the docs mention these tools.

### Required / commonly used

1. **Go**
    - Needed if building chain binaries from source.
2. **Git**
    - Needed to clone repositories.
3. **`mantrachaind`**
    - MANTRA / DuKong chain CLI.
    - Used for provider-chain transactions and IBC transfer steps.
4. **`nvnmchaind`**
    - NVNM Chain CLI.
    - Used for NVNM address conversion and balance checks.
5. **Foundry / `cast`**
    - Used for EVM contract calls and transactions.
6. **Wallet**
    - MetaMask/Rabby for EVM flows.
    - Keplr may be relevant for Cosmos flows.
    - The docs also explain importing the same wallet into CLI keyrings.

The faucet guide gives install options for the binaries and Foundry.[^5]

---

## 5. Install chain binaries

### Option A — build from source

```bash
# MANTRA Chain / DuKong
git clone https://github.com/MANTRA-Chain/mantrachain.git
cd mantrachain
make install
cd ..

# NVNM Chain
git clone https://github.com/MANTRA-Chain/nvnmchain.git
cd nvnmchain
make install
cd ..
```

Verify:

```bash
mantrachaind version
nvnmchaind version
```

Some docs reference `mantrachaind-v8`; releases may ship as `mantrachaind`, so you may need an alias depending on your local setup.[^5]

### Option B — download releases

The docs also mention using prebuilt binaries from GitHub releases:

- MANTRA Chain releases
- NVNM Chain releases

Then make them executable and move them into your path:

```bash
chmod +x mantrachaind nvnmchaind
sudo mv mantrachaind /usr/local/bin/
sudo mv nvnmchaind /usr/local/bin/
```

[^5]

---

## 6. Install Foundry / `cast`

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc    # or ~/.zshrc on macOS
foundryup
```

Verify:

```bash
cast --version
```

Windows users likely need WSL, because Foundry’s install script expects a Unix-like shell.[^5]

---

## 7. Wallet and address setup

NVNM has both Cosmos and EVM address formats.

You may see:

| Format | Example prefix | Used for |
|---|---|---|
| EVM | `0x...` | MetaMask, Rabby, `cast`, EVM transactions |
| MANTRA L1 Bech32 | `mantra1...` | DuKong / MANTRA Cosmos CLI |
| NVNM Bech32 | `nvnm1...` | NVNM Cosmos CLI and IBC destination |

Important warning from the faucet doc: **do not manually replace `mantra1` with `nvnm1`**. Derive the NVNM address properly from your EVM address.[^5]

To derive your `nvnm1` address from your EVM `0x` address:

```bash
nvnmchaind q evm 0x-to-bech32 0x<your_hex_address> \
  --node https://rpc.testnet.nvnmchain.io
```

Example output:

```
nvnm15p343p22pupsunvp50exm86vz0808ccpmxaxx8
```

[^5]

---

## 8. Add NVNM testnet to MetaMask / EVM wallet

Use these testnet settings:

```
Network Name: NVNM Testnet
RPC URL: https://evm.testnet.nvnmchain.io
Chain ID: 787111
Currency Symbol: mUSD
Block Explorer: https://explorer.evm.testnet.nvnmchain.io
```

Another network-info page lists the same EVM Chain ID and EVM RPC endpoint for `nvnm-testnet-1`.[^4]

---

## 9. Testnet faucet / getting gas tokens

The testnet gas token is **wmantraUSD** on `nvnm-testnet-1`.[^4]

There are two relevant notes:

1. The older network-info doc says NVNM testnet has a faucet for wmantraUSD.[^4]
2. The detailed faucet guide says a dedicated faucet at `faucet.testnet.nvnmchain.io` was being provisioned, and until live, tokens must be bridged from `mantra-dukong-1`.[^5]

The most complete documented route is:

1. Get DuKong `amantra` for gas.
2. Mint `mantraUSD` on DuKong.
3. Wrap it into `wmantraUSD`.
4. Convert ERC-20 to Cosmos denom.
5. IBC transfer to NVNM.
6. Verify balance on NVNM.

### Step 1 — get DuKong testnet gas

Use:

```
https://faucet.dukong.mantrachain.io/
```

You need `amantra` to pay gas on DuKong.[^5]

### Step 2 — mint mantraUSD on DuKong

Use the DuKong `mantraUSD` contract:

```
0x4B545d0758eda6601B051259bD977125fbdA7ba2
```

The docs say to use the `mint` function on the Blockscout Write tab. Amount uses 6 decimals:

```
1,000 tokens  = 1000000000
10,000 tokens = 10000000000
```

[^5]

### Step 3 — set environment variables

```bash
MANTRA_USD_ADDRESS="0x4B545d0758eda6601B051259bD977125fbdA7ba2"
WRAPPED_MANTRA_USD_ADDRESS="0x36A28B8C8FFD00bEE440dB8273D57451FBeAf767"
WRAPPED_MANTRA_USD_DENOM="erc20:0x36A28B8C8FFD00bEE440dB8273D57451FBeAf767"

PRIVATE_KEY=0x<your_private_key>
NVNM_ADDRESS=nvnm1<your_address>

AMOUNT_MANTRA_USD="1000000000"
AMOUNT_WMANTRA_USD="1000000000000000000000"
```

[^5]

### Step 4 — approve and wrap

Approve:

```bash
cast send $MANTRA_USD_ADDRESS "approve(address,uint256)" \
  $WRAPPED_MANTRA_USD_ADDRESS $AMOUNT_MANTRA_USD \
  --rpc-url https://evm.dukong.mantrachain.io \
  --private-key $PRIVATE_KEY --chain 5887
```

Wrap:

```bash
HEX_ADDRESS=$(nvnmchaind q evm bech32-to-0x $NVNM_ADDRESS)

cast send $WRAPPED_MANTRA_USD_ADDRESS "depositFor(address,uint256)" \
  $HEX_ADDRESS $AMOUNT_MANTRA_USD \
  --rpc-url https://evm.dukong.mantrachain.io \
  --private-key $PRIVATE_KEY --chain 5887
```

[^5]

### Step 5 — convert ERC-20 to Cosmos denom

```bash
mantrachaind-v8 tx erc20 convert-erc20 \
  $WRAPPED_MANTRA_USD_ADDRESS $AMOUNT_WMANTRA_USD \
  --from <your_key_name> \
  --yes --chain-id mantra-dukong-1 \
  --gas auto --gas-adjustment 2 \
  --gas-prices 40000000000amantra \
  --keyring-backend test \
  --node https://rpc.dukong.mantrachain.io
```

[^5]

### Step 6 — IBC transfer to NVNM

```bash
mantrachaind-v8 tx ibc-transfer transfer transfer channel-13 \
  $NVNM_ADDRESS \
  ${AMOUNT_WMANTRA_USD}${WRAPPED_MANTRA_USD_DENOM} \
  --from <your_key_name> --yes \
  --chain-id mantra-dukong-1 \
  --gas auto --gas-adjustment 2 \
  --gas-prices 40000000000amantra \
  --home ~/.mantrachain --keyring-backend test \
  --node https://rpc.dukong.mantrachain.io
```

`channel-13` is the DuKong → NVNM transfer channel.[^5]

### Step 7 — verify NVNM balance

```bash
nvnmchaind query bank balance \
  $NVNM_ADDRESS \
  ibc/00E24F149F01782E2C423BDB114C98D6C657DFC583124389192187BF8DC3A1AD \
  --node https://rpc.testnet.nvnmchain.io
```

Expected:

```yaml
balance:
  amount: "1000000000000000000000"
  denom: ibc/00E24F149F01782E2C423BDB114C98D6C657DFC583124389192187BF8DC3A1AD
```

[^5]

---

## 10. Network endpoints you will need

For `nvnm-testnet-1`:

```
RPC:       https://rpc.testnet.nvnmchain.io
REST/API:  https://api.testnet.nvnmchain.io
gRPC:      https://grpc.testnet.nvnmchain.io
EVM RPC:   https://evm.testnet.nvnmchain.io
Explorer:  https://explorer.evm.testnet.nvnmchain.io
Chain ID:  nvnm-testnet-1
EVM ID:    787111
```

[^4]

For DuKong provider chain:

```
RPC:      https://rpc.dukong.mantrachain.io
EVM RPC:  https://evm.dukong.mantrachain.io
Chain ID: mantra-dukong-1
EVM ID:   5887
Faucet:   https://faucet.dukong.mantrachain.io/
```

[^5]

---

## 11. First anchoring integration flow

Once your wallet has gas on NVNM, the simplest app flow is:

1. Create or choose a registry.
2. Store the returned `registryId`.
3. Generate a checksum of your document/data.
4. Store the actual file/data somewhere off-chain.
5. Call `addRecord`.
6. Later call `records` to verify the stored checksum.

---

## 12. EVM precompile integration

### Precompile address

```
0x0000000000000000000000000000000000000A00
```

[^2]

### Current v1.2.0 Solidity-style interface

The upgrade guide gives this reference interface:

```solidity
interface IAnchoringPrecompile {
    struct Record {
        string uri;
        string checksum;
        string checksumAlgo;
        string metadata;
        string timestamp;
        string status;
        uint64 recordId;
        uint64 index;
        bool isLatest;
        uint64 registryId;
    }

    struct Registry {
        uint64 id;
        string name;
        string description;
        string creator;
        string createdAt;
        string metadata;
    }

    function addRegistry(
        string name,
        string description,
        string metadata
    ) external returns (uint64 registryId);

    function addRecord(
        Record record
    ) external returns (uint64 recordId);

    function updateRecordStatus(
        uint64 registryId,
        uint64 recordId,
        uint64 index,
        string status
    ) external;

    function records(
        uint64 registryId,
        string checksum,
        uint64 recordId,
        uint64 index,
        PageRequest pagination
    ) external returns (Record[] records, PageResponse pagination);

    function registries(
        uint64 registryId,
        PageRequest pagination
    ) external returns (Registry[] registries, PageResponse pagination);

    function grantRole(
        uint64 registryId,
        string checksum,
        address account,
        string role
    ) external;

    function revokeRole(
        uint64 registryId,
        string checksum,
        address account,
        string role
    ) external;
}
```

The important part: `addRecord` now uses `registryId`, not registry name.[^6]

### Step A — create a registry

Conceptually:

```solidity
uint64 registryId = anchoring.addRegistry(
    "legal-contracts",
    "Anchoring for legal contracts",
    "{\"app\":\"my-app\",\"env\":\"testnet\"}"
);
```

Store `registryId` in your backend/database. Do not rely on the name as unique.[^6]

### Step B — generate checksum in your app

Example in Node.js:

```js
import crypto from "crypto";
import fs from "fs";

const fileBuffer = fs.readFileSync("./contract.pdf");
const checksum = crypto
  .createHash("sha256")
  .update(fileBuffer)
  .digest("hex");

console.log(checksum);
```

You choose the checksum format, but your app should be consistent. The docs note the keeper does not enforce canonical checksum format.[^3]

### Step C — upload/store your file

Examples:

```
s3://my-bucket/contracts/contract-123.pdf
ipfs://<cid>
https://my-app.example/documents/contract-123.pdf
```

The chain stores the URI as a string. It does not store the actual file.[^1]

### Step D — add a record

Conceptually:

```solidity
IAnchoringPrecompile.Record memory record = IAnchoringPrecompile.Record({
    uri: "ipfs://...",
    checksum: "<sha256-hash>",
    checksumAlgo: "sha256",
    metadata: "{\"documentId\":\"contract-123\"}",
    timestamp: "",
    status: "active",
    recordId: 0,
    index: 0,
    isLatest: false,
    registryId: registryId
});

uint64 recordId = anchoring.addRecord(record);
```

Fields like `timestamp`, `recordId`, `index`, and `isLatest` are chain-set, so on input you generally pass empty/zero defaults.[^2][^6]

### Step E — query records for verification

Use:

```solidity
records(
    registryId,
    checksum,
    0,
    0,
    pagination
)
```

Then compare the returned on-chain checksum with a freshly recomputed checksum of the file.[^2][^6]

---

## 13. Native CLI anchoring examples

The technical spec gives these command shapes.

### Create registry

```bash
inveniamd tx anchoring add-registry \
  --name demo123 \
  --description "demo123 anchoring module" \
  --from <wallet-name> \
  --node <rpc-node> \
  --gas auto \
  --gas-adjustment 2 \
  --gas-prices <gas-price> \
  --chain-id <chain-id> \
  -y
```

A transaction example in the workspace used:

```bash
inveniamd tx anchoring add-registry \
  --name demo123 \
  --description "demo123 anchoring module" \
  --from manveniam-qa1 \
  --node https://rpc.inveniam.mantrachain.io:443 \
  --gas auto \
  --gas-adjustment 2 \
  --gas-prices 40000000000ibc/5F4B5CA93AEF7604997725F3CD016F8B6CB2F709E919EF21A854416EEB04991F \
  --chain-id manveniam-1 \
  -y
```

[^7]

### Query registry

```bash
inveniamd q anchoring registry \
  --name demo123 \
  --node https://rpc.inveniam.mantrachain.io:443 \
  -o json
```

Note: for newer v1.2.0-style integrations, prefer ID-based logic instead of name-based logic.[^6]

### Add record

The technical spec describes:

```bash
inveniamd tx anchoring add-record \
  --record <path-to-record-json>
```

The record JSON should contain:

```json
{
  "registry_id": 1,
  "uri": "ipfs://...",
  "checksum": "...",
  "checksum_algo": "sha256",
  "metadata": "{\"documentId\":\"contract-123\"}",
  "status": "active"
}
```

The exact JSON field names may depend on the current binary/proto version, so for implementation I would treat the v1.2.0 guide as authoritative: use `registry_id`, not registry name.[^1][^6]

### Query records

```bash
inveniamd q anchoring records \
  --registry-id <registry-id> \
  --checksum <checksum>
```

[^1]

---

## 14. Roles and permissions in practice

Basic pattern:

1. Registry creator is admin.
2. Admin can grant `editor` to another wallet.
3. Editors can add records.
4. Admins can revoke roles.

EVM grant example:

```python
await DOCUMENT_PRECOMPILE.fns.grantRole(
    registry_id,
    "",              # empty checksum = registry-level role
    user_address,    # EVM 0x address
    "editor"
).transact(w3, admin_account, to=DOCUMENT_ADDRESS)
```

Record-level grant:

```python
await DOCUMENT_PRECOMPILE.fns.grantRole(
    registry_id,
    "abc123def456",  # checksum-specific role
    user_address,
    "admin"
).transact(w3, admin_account, to=DOCUMENT_ADDRESS)
```

Only `admin` and `editor` are enforced roles; viewer-style reads are public.[^2][^3]

---

## 15. Minimal application architecture

For a normal backend app, I would implement it like this:

### Your database tables

**registries**

| field | purpose |
|---|---|
| `id` | local DB ID |
| `chain_registry_id` | numeric on-chain registry ID |
| `name` | display name |
| `description` | display description |
| `created_tx_hash` | tx hash |

**anchored_records**

| field | purpose |
|---|---|
| `id` | local DB ID |
| `chain_registry_id` | registry ID |
| `chain_record_id` | on-chain record ID |
| `checksum` | SHA-256 hash |
| `checksum_algo` | `sha256` |
| `uri` | S3/IPFS/backend URI |
| `metadata` | JSON metadata |
| `status` | `active`, etc. |
| `tx_hash` | transaction hash |
| `created_at` | local timestamp |

### Backend flow

1. User uploads file.
2. Backend stores file in S3/IPFS.
3. Backend computes SHA-256.
4. Backend submits `addRecord` transaction.
5. Backend stores tx hash and record info.
6. Backend exposes “Verify” button.
7. On verify, backend recomputes SHA-256 and queries `records`.

---

## 16. Important caveats / open items

A few docs contain older or conflicting details, so watch these:

1. **Use `registryId`, not registry name**, for new integrations. This is the most important upgrade note.[^6]
2. Some older workflow examples show legacy ABI shapes or `eth_sendTransaction`; the workflow doc itself says the earlier JSON-RPC example is outdated and should use signed raw transactions.[^3]
3. The detailed workflow doc contains “TBD — MANTRA” items around some ABI details in older versions. For current implementation, use the latest v1.2.0 guide as the integration baseline.[^3][^6]
4. The testnet faucet situation appears to have changed over time: one page says a dedicated faucet exists/was available, while another says it was being provisioned and gives the manual bridging path. The manual bridging path is fully documented and should work as the fallback.[^4][^5]

---

## 17. Short checklist for someone starting from zero

1. Install:
    - Go
    - Git
    - `mantrachaind`
    - `nvnmchaind`
    - Foundry / `cast`
2. Create/import wallet:
    - MetaMask/Rabby for EVM
    - Import key/mnemonic into CLI keyring if using Cosmos commands
3. Add NVNM testnet to wallet:
    - RPC: `https://evm.testnet.nvnmchain.io`
    - Chain ID: `787111`
4. Derive your NVNM address:

    ```bash
    nvnmchaind q evm 0x-to-bech32 0x<your_hex_address> \
      --node https://rpc.testnet.nvnmchain.io
    ```

5. Get testnet gas:
    - Try NVNM testnet faucet if available.
    - Otherwise use DuKong faucet + mint/wrap/IBC bridge flow.
6. In your app:
    - Connect to EVM RPC: `https://evm.testnet.nvnmchain.io`
    - Use precompile: `0x0000000000000000000000000000000000000A00`
    - Call `addRegistry`
    - Store returned `registryId`
    - Compute SHA-256 of file/data
    - Store file off-chain
    - Call `addRecord`
    - Query `records` for verification
7. For permissions:
    - Registry creator is admin.
    - Use `grantRole` to give other wallets `editor` or `admin`.

---

## Bottom line

There **is** enough information to create a how-to guide, but it is not currently in one single clean beginner document. The closest existing beginner docs are [📑 Document Anchoring Workflow (EVM Precompile)](https://app.notion.com/p/Document-Anchoring-Workflow-EVM-Precompile-2f75c45f06f080b494f0ea1c881b9fa0?pvs=21) and [faucet-and-testnet-tokens](https://app.notion.com/p/faucet-and-testnet-tokens-3495c45f06f080a7989ed4fe1d269415?pvs=21). For actual implementation, combine those with [Anchoring Module Upgrade: v1.1.0 → v1.2.0 Integration Guide](https://app.notion.com/p/Anchoring-Module-Upgrade-v1-1-0-v1-2-0-Integration-Guide-3b35c45f06f0808da7a9c308ef32aba6?pvs=21), because the upgrade guide has the latest registry-ID-based integration model.

---

[^1]: [Anchoring Module: Technical Specification](https://app.notion.com/p/Anchoring-Module-Technical-Specification-2ee5c45f06f081dd8baac008e3cf2f34?pvs=21)
[^2]: [Anchoring Module: EVM Precompile Technical Specification](https://app.notion.com/p/Anchoring-Module-EVM-Precompile-Technical-Specification-2ee5c45f06f0815686bac34ec0895f93?pvs=21)
[^3]: [📑 Document Anchoring Workflow (EVM Precompile)](https://app.notion.com/p/Document-Anchoring-Workflow-EVM-Precompile-2f75c45f06f080b494f0ea1c881b9fa0?pvs=21)
[^4]: [nvnm-testnet-1 — Faucet & Network Info](https://app.notion.com/p/nvnm-testnet-1-Faucet-Network-Info-3435c45f06f08014a0affaf958225630?pvs=21)
[^5]: [faucet-and-testnet-tokens](https://app.notion.com/p/faucet-and-testnet-tokens-3495c45f06f080a7989ed4fe1d269415?pvs=21)
[^6]: [Anchoring Module Upgrade: v1.1.0 → v1.2.0 Integration Guide](https://app.notion.com/p/Anchoring-Module-Upgrade-v1-1-0-v1-2-0-Integration-Guide-3b35c45f06f0808da7a9c308ef32aba6?pvs=21)
[^7]: [Transaction example via cosmos message and precompile](https://app.notion.com/p/Transaction-example-via-cosmos-message-and-precompile-2fd5c45f06f08080bf12cc51353eddc0?pvs=21)
