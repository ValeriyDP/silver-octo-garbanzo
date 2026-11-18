---
name: Anchoring How To integration only
date: 2026-08-12T10:58:42.006Z
tags:
  - smart-accounts
  - anchoring
  - evm-precompile
  - nvnm-testnet
  - integration
---
Below is a rewritten **integration-centric HOW-TO**: focused on “I want to add anchoring to my app with minimum deep dive,” while still keeping the faucet / testnet gas setup.

> [!info] Related notes
> - [How-To Full Guide](How-To%20Full%20Guide.md) — full conceptual + CLI + EVM reference this guide is distilled from.
> - [How-To MetaMask](How-To%20MetaMask.md) — browser wallet signing path (no private keys in the app).
> - [Smart Accounts Obtaining Config Values](../Smart%20Accounts%20Obtaining%20Config%20Values.md) — where to source RPC URLs, chain IDs, and contract addresses.
> - [Smart Accounts Open Questions](../Smart%20Accounts%20Open%20Questions.md) — tracks unresolved anchoring/testnet items.

---

# Anchoring Module Integration Guide

## Goal

This guide explains how to integrate the **Anchoring Module** into an application with the least amount of chain-specific complexity.

You do **not** need to run a node, understand Cosmos internals, or use native chain CLI commands for the core app integration.

The recommended path is:

> Use the **EVM precompile** like a smart contract at a fixed address.

---

# 1. What anchoring means

Anchoring is the process of writing a cryptographic proof of some off-chain data to the blockchain.

Your application usually has:

- a file
- a JSON payload
- a document
- an attestation
- a report
- any other data object

Instead of storing the full data on-chain, your app stores:

- a checksum / hash of the data
- a URI pointing to the off-chain data
- metadata
- a status

Example:

```json
{
  "uri": "ipfs://bafy...",
  "checksum": "fe640e1b818c3d78f769700065d97869147a561e7ba40da8aaca08ac11e0108c",
  "checksumAlgo": "sha256",
  "metadata": "{\"documentId\":\"contract-123\"}",
  "status": "active"
}
```

The blockchain becomes a tamper-evident audit trail.

Later, anyone can:

1. fetch the original document,
2. recompute the checksum,
3. compare it with the on-chain checksum.

If the checksums match, the document matches what was anchored.

---

# 2. Recommended integration path

Use the EVM interface.

The Anchoring Module is exposed through an EVM precompile at:

```
0x0000000000000000000000000000000000000A00
```

You can call it using normal EVM tooling:

- `ethers.js`
- `viem`
- `web3.js`
- `web3.py`
- Foundry `cast`
- MetaMask / Rabby
- backend wallet/private key signer

For a normal application team, this is the simplest path.

---

# 3. What you need

## Required for app integration

You need:

1. **EVM wallet / signer**
    - MetaMask, Rabby, backend private key, WalletConnect, etc.
2. **Target chain EVM RPC**

    For NVNM testnet:

    ```
    https://evm.testnet.nvnmchain.io
    ```

3. **Gas token on the target chain**

    For NVNM testnet, the gas token is usually referred to as:

    ```
    mUSD / wmantraUSD / wmmUSD
    ```

    Naming varies across docs, but the practical point is: your EVM wallet needs gas on NVNM testnet.

4. **Anchoring precompile address**

    ```
    0x0000000000000000000000000000000000000A00
    ```

5. **Anchoring ABI / interface**

    Your app needs the ABI to call:

    - `addRegistry`
    - `addRecord`
    - `records`
    - optionally `grantRole`
    - optionally `updateRecordStatus`

---

## Optional tools

These are helpful, but not required in your application.

### `cast`

Useful for manual testing EVM transactions from terminal.

Install via Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Verify:

```bash
cast --version
```

### `nvnmchaind`

Optional.

Useful for:

- address conversion
- checking NVNM balance from CLI
- troubleshooting

Not required if your app only uses EVM RPC.

### `mantrachaind`

Optional for the app itself.

Useful if you need to manually fund your NVNM testnet wallet by bridging tokens from DuKong / MANTRA testnet.

---

# 4. What you do **not** need for basic app integration

For the simple EVM path, you do **not** need to:

- run a validator
- run a full node
- understand Cosmos SDK modules
- understand IBC internals
- use native Cosmos messages
- install `nvnmchaind` in your app
- install `mantrachaind` in your app
- use gRPC directly
- use REST directly

Your app can treat anchoring as a smart-contract-like interface.

---

# 5. High-level application flow

Your app needs three basic actions:

1. Create a registry.
2. Add records to that registry.
3. Query records for verification.

```
Application
   |
   | 1. addRegistry(...)
   v
Anchoring Precompile
   |
   | returns registryId
   v
Application stores registryId
   |
   | 2. addRecord(...)
   v
Anchoring Precompile
   |
   | stores checksum + URI + metadata
   v
Application can later query records(...)
```

---

# 6. Core concepts

## Registry

A registry is a logical container for records.

Think of it as a project, folder, or namespace.

Examples:

```
legal-contracts
kyc-documents
ai-agent-attestations
customer-reports
```

When you create a registry, the chain returns a numeric `registryId`.

Your application must store this `registryId`.

Do **not** rely on registry name as the main identifier.

Use:

```
registryId
```

not:

```
registry name
```

---

## Record

A record is one anchored item.

It contains:

- `registryId`
- `uri`
- `checksum`
- `checksumAlgo`
- `metadata`
- `status`

Example:

```json
{
  "registryId": 12,
  "uri": "s3://my-bucket/contracts/contract-123.pdf",
  "checksum": "fe640e1b818c3d78f769700065d97869147a561e7ba40da8aaca08ac11e0108c",
  "checksumAlgo": "sha256",
  "metadata": "{\"documentId\":\"contract-123\",\"type\":\"contract\"}",
  "status": "active"
}
```

---

## Checksum

The checksum is the hash of your off-chain data.

Recommended:

```
sha256
```

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

---

## URI

The URI points to where the original data is stored.

Examples:

```
ipfs://bafy...
s3://my-bucket/documents/file.pdf
https://api.myapp.com/documents/123
```

The chain does **not** store the file itself.

It stores only the reference and proof.

---

## Metadata

Metadata is an opaque string.

Recommended format:

```json
{
  "documentId": "contract-123",
  "type": "contract",
  "source": "my-app",
  "createdBy": "user-456"
}
```

Pass it as a stringified JSON value:

```js
const metadata = JSON.stringify({
  documentId: "contract-123",
  type: "contract",
  source: "my-app"
});
```

---

## Status

Status is also a free-form string.

Recommended values:

```
active
revoked
deprecated
superseded
draft
verified
```

Your app defines the meaning.

---

# 7. EVM precompile interface

Use this precompile address:

```
0x0000000000000000000000000000000000000A00
```

Use this integration model:

```solidity
interface IAnchoringPrecompile {
    struct PageRequest {
        bytes key;
        uint64 offset;
        uint64 limit;
        bool countTotal;
        bool reverse;
    }

    struct PageResponse {
        bytes nextKey;
        uint64 total;
    }

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
    ) external returns (
        Record[] memory records,
        PageResponse memory pagination
    );

    function registries(
        uint64 registryId,
        PageRequest pagination
    ) external returns (
        Registry[] memory registries,
        PageResponse memory pagination
    );

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

---

# 8. Step-by-step app integration

## Step 1 — connect to the EVM RPC

For NVNM testnet:

```
https://evm.testnet.nvnmchain.io
```

Example with `ethers.js`:

```js
import { ethers } from "ethers";

const RPC_URL = "https://evm.testnet.nvnmchain.io";
const provider = new ethers.JsonRpcProvider(RPC_URL);

const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
```

---

## Step 2 — create a contract instance

```js
import { ethers } from "ethers";

const ANCHORING_PRECOMPILE =
  "0x0000000000000000000000000000000000000A00";

const anchoringAbi = [
  "function addRegistry(string name,string description,string metadata) returns (uint64)",
  "function addRecord((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId) record) returns (uint64)",
  "function records(uint64 registryId,string checksum,uint64 recordId,uint64 index,(bytes key,uint64 offset,uint64 limit,bool countTotal,bool reverse) pagination) view returns ((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId)[] records,(bytes nextKey,uint64 total) pagination)"
];

const anchoring = new ethers.Contract(
  ANCHORING_PRECOMPILE,
  anchoringAbi,
  signer
);
```

---

## Step 3 — create a registry once

A registry should usually be created once per app, customer, project, or data category.

Example:

```js
const tx = await anchoring.addRegistry(
  "customer-documents",
  "Anchoring registry for customer documents",
  JSON.stringify({
    app: "my-app",
    environment: "testnet"
  })
);

const receipt = await tx.wait();

console.log("Registry creation tx:", receipt.hash);
```

Depending on how return values are exposed by your tooling, you may need to get the `registryId` from:

- transaction logs,
- return value simulation,
- a follow-up query,
- your backend/admin setup process.

Once you have it, store it in your app config/database.

Example:

```
ANCHORING_REGISTRY_ID=12
```

Important:

> Store the numeric `registryId`. Do not use registry name as the permanent identifier.

---

## Step 4 — prepare data to anchor

Example for a file:

```js
import crypto from "crypto";
import fs from "fs";

function sha256File(path) {
  const fileBuffer = fs.readFileSync(path);

  return crypto
    .createHash("sha256")
    .update(fileBuffer)
    .digest("hex");
}

const checksum = sha256File("./contract.pdf");
```

Upload the file somewhere:

```js
const uri = "s3://my-bucket/contracts/contract-123.pdf";
```

Prepare metadata:

```js
const metadata = JSON.stringify({
  documentId: "contract-123",
  type: "contract",
  source: "my-app"
});
```

---

## Step 5 — add a record

```js
const registryId = 12;

const record = {
  uri,
  checksum,
  checksumAlgo: "sha256",
  metadata,
  timestamp: "",      // set by chain
  status: "active",
  recordId: 0,        // set by chain
  index: 0,           // set by chain
  isLatest: false,    // set by chain
  registryId
};

const tx = await anchoring.addRecord(record);
const receipt = await tx.wait();

console.log("Anchored record tx:", receipt.hash);
```

Store the transaction hash and local metadata in your database.

Recommended local record:

```json
{
  "registryId": 12,
  "uri": "s3://my-bucket/contracts/contract-123.pdf",
  "checksum": "fe640e1b818c3d78f769700065d97869147a561e7ba40da8aaca08ac11e0108c",
  "checksumAlgo": "sha256",
  "status": "active",
  "txHash": "0x..."
}
```

---

## Step 6 — verify a record later

To verify a document:

1. Fetch the original document.
2. Recompute its checksum.
3. Query the anchoring module.
4. Compare the checksums.

```js
const pagination = {
  key: "0x",
  offset: 0,
  limit: 10,
  countTotal: false,
  reverse: false
};

const [records] = await anchoring.records(
  registryId,
  checksum,
  0,
  0,
  pagination
);

if (records.length === 0) {
  console.log("No anchored record found");
} else {
  const anchored = records[0];

  if (anchored.checksum === checksum) {
    console.log("Document verified");
  } else {
    console.log("Checksum mismatch");
  }
}
```

---

# 9. Minimal `cast` testing

You can use `cast` to test calls manually.

Set variables:

```bash
export RPC_URL="https://evm.testnet.nvnmchain.io"
export PRIVATE_KEY="0x<your_private_key>"
export ANCHORING="0x0000000000000000000000000000000000000A00"
```

Create a registry:

```bash
cast send $ANCHORING \
  "addRegistry(string,string,string)" \
  "customer-documents" \
  "Anchoring registry for customer documents" \
  '{"app":"my-app","environment":"testnet"}' \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

For `addRecord`, because it uses a tuple, using a proper script with `ethers.js` or `viem` is usually easier than hand-writing the `cast` command.

---

# 10. Permissions

The module has two main roles:

```
admin
editor
```

## Admin

Can:

- add records
- update record status
- grant roles
- revoke roles

The creator of a registry becomes admin for that registry.

## Editor

Can:

- add records
- update record status

## Public reads

Reading/querying records is public.

No viewer role is required.

---

## Grant editor role

Example:

```js
await anchoring.grantRole(
  registryId,
  "",              // empty checksum means registry-level role
  "0xUserAddress",
  "editor"
);
```

## Grant record-level role

```js
await anchoring.grantRole(
  registryId,
  checksum,        // checksum-specific role
  "0xUserAddress",
  "editor"
);
```

For most simple integrations, you can start with one backend/admin wallet and skip role management until needed.

---

# 11. Testnet faucet and gas setup

Your app wallet needs gas on NVNM testnet before it can send anchoring transactions.

For NVNM testnet:

```
Chain ID: 787111
EVM RPC: https://evm.testnet.nvnmchain.io
Explorer: https://explorer.evm.testnet.nvnmchain.io
```

Gas token naming varies in docs:

```
mUSD / wmantraUSD / wmmUSD
```

The important point is that your EVM wallet needs the NVNM testnet gas token.

---

## Option A — use NVNM testnet faucet, if available

Try the NVNM testnet faucet:

```
https://faucet.testnet.nvnmchain.io/
```

If it is live, this is the easiest path.

Use your EVM address:

```
0x...
```

Then check your balance in MetaMask/Rabby or the explorer:

```
https://explorer.evm.testnet.nvnmchain.io
```

---

## Option B — manual funding via DuKong bridge

If the faucet is unavailable, use the manual route.

This route is more complex, but it is only for getting testnet gas. Your application does **not** need to implement this.

High-level flow:

```
Get DuKong gas
  ↓
Mint mantraUSD on DuKong
  ↓
Wrap mantraUSD into wmantraUSD
  ↓
Convert ERC-20 to Cosmos denom
  ↓
IBC transfer to NVNM
  ↓
Use resulting token as gas on NVNM
```

---

## Manual funding prerequisites

Install:

- `mantrachaind` or `mantrachaind-v8`
- `cast`
- optionally `nvnmchaind`

You need:

- EVM wallet private key
- DuKong testnet gas token: `amantra`
- NVNM destination address

---

## Step 1 — get DuKong gas

Use:

```
https://faucet.dukong.mantrachain.io/
```

Request `amantra` for your wallet.

---

## Step 2 — mint mantraUSD on DuKong

Use the DuKong mantraUSD contract:

```
0x4B545d0758eda6601B051259bD977125fbdA7ba2
```

Open the Write tab in DuKong Blockscout and call:

```
mint
```

Amounts use 6 decimals:

```
1,000 tokens  = 1000000000
10,000 tokens = 10000000000
```

---

## Step 3 — set environment variables

```bash
export MANTRA_USD_ADDRESS="0x4B545d0758eda6601B051259bD977125fbdA7ba2"
export WRAPPED_MANTRA_USD_ADDRESS="0x36A28B8C8FFD00bEE440dB8273D57451FBeAf767"
export WRAPPED_MANTRA_USD_DENOM="erc20:0x36A28B8C8FFD00bEE440dB8273D57451FBeAf767"

export PRIVATE_KEY="0x<your_private_key>"

export AMOUNT_MANTRA_USD="1000000000"
export AMOUNT_WMANTRA_USD="1000000000000000000000"
```

---

## Step 4 — get your NVNM address

If you have `nvnmchaind`, derive it from your EVM address:

```bash
nvnmchaind q evm 0x-to-bech32 0x<your_hex_address> \
  --node https://rpc.testnet.nvnmchain.io
```

Set it:

```bash
export NVNM_ADDRESS="nvnm1<your_address>"
```

If you do not want to install `nvnmchaind`, use wallet/explorer tooling that gives you the correct NVNM-compatible address, or ask the team for the recommended address-conversion method.

---

## Step 5 — approve mantraUSD

```bash
cast send $MANTRA_USD_ADDRESS "approve(address,uint256)" \
  $WRAPPED_MANTRA_USD_ADDRESS $AMOUNT_MANTRA_USD \
  --rpc-url https://evm.dukong.mantrachain.io \
  --private-key $PRIVATE_KEY \
  --chain 5887
```

---

## Step 6 — wrap mantraUSD into wmantraUSD

If you have `nvnmchaind`:

```bash
HEX_ADDRESS=$(nvnmchaind q evm bech32-to-0x $NVNM_ADDRESS)
```

Then:

```bash
cast send $WRAPPED_MANTRA_USD_ADDRESS "depositFor(address,uint256)" \
  $HEX_ADDRESS $AMOUNT_MANTRA_USD \
  --rpc-url https://evm.dukong.mantrachain.io \
  --private-key $PRIVATE_KEY \
  --chain 5887
```

---

## Step 7 — convert ERC-20 to Cosmos denom on DuKong

```bash
mantrachaind-v8 tx erc20 convert-erc20 \
  $WRAPPED_MANTRA_USD_ADDRESS $AMOUNT_WMANTRA_USD \
  --from <your_key_name> \
  --yes \
  --chain-id mantra-dukong-1 \
  --gas auto \
  --gas-adjustment 2 \
  --gas-prices 40000000000amantra \
  --keyring-backend test \
  --node https://rpc.dukong.mantrachain.io
```

If your binary is named `mantrachaind`, use that instead of `mantrachaind-v8`.

---

## Step 8 — IBC transfer to NVNM

```bash
mantrachaind-v8 tx ibc-transfer transfer transfer channel-13 \
  $NVNM_ADDRESS \
  ${AMOUNT_WMANTRA_USD}${WRAPPED_MANTRA_USD_DENOM} \
  --from <your_key_name> \
  --yes \
  --chain-id mantra-dukong-1 \
  --gas auto \
  --gas-adjustment 2 \
  --gas-prices 40000000000amantra \
  --home ~/.mantrachain \
  --keyring-backend test \
  --node https://rpc.dukong.mantrachain.io
```

`channel-13` is the DuKong → NVNM testnet transfer channel.

---

## Step 9 — verify balance

With `nvnmchaind`:

```bash
nvnmchaind query bank balance \
  $NVNM_ADDRESS \
  ibc/00E24F149F01782E2C423BDB114C98D6C657DFC583124389192187BF8DC3A1AD \
  --node https://rpc.testnet.nvnmchain.io
```

Or check your EVM wallet / Blockscout explorer:

```
https://explorer.evm.testnet.nvnmchain.io
```

If the balance does not appear immediately, wait a few minutes. IBC transfers can take time.

---

# 12. Network reference

## NVNM testnet

```
Chain ID: nvnm-testnet-1
EVM Chain ID: 787111
EVM RPC: https://evm.testnet.nvnmchain.io
RPC: https://rpc.testnet.nvnmchain.io
REST/API: https://api.testnet.nvnmchain.io
gRPC: https://grpc.testnet.nvnmchain.io
Explorer: https://explorer.evm.testnet.nvnmchain.io
```

## DuKong testnet

```
Chain ID: mantra-dukong-1
EVM Chain ID: 5887
RPC: https://rpc.dukong.mantrachain.io
EVM RPC: https://evm.dukong.mantrachain.io
Faucet: https://faucet.dukong.mantrachain.io/
```

## Anchoring precompile

```
0x0000000000000000000000000000000000000A00
```

---

# 13. Recommended app database model

## `anchoring_registries`

```sql
id
chain_id
registry_id
name
description
metadata
created_tx_hash
created_at
```

Example:

```json
{
  "chainId": 787111,
  "registryId": 12,
  "name": "customer-documents",
  "description": "Anchoring registry for customer documents",
  "metadata": {
    "app": "my-app",
    "environment": "testnet"
  },
  "createdTxHash": "0x..."
}
```

## `anchored_records`

```sql
id
registry_id
record_id
index
uri
checksum
checksum_algo
metadata
status
tx_hash
created_at
```

Example:

```json
{
  "registryId": 12,
  "recordId": 34,
  "index": 1,
  "uri": "s3://my-bucket/contracts/contract-123.pdf",
  "checksum": "fe640e1b818c3d78f769700065d97869147a561e7ba40da8aaca08ac11e0108c",
  "checksumAlgo": "sha256",
  "metadata": {
    "documentId": "contract-123"
  },
  "status": "active",
  "txHash": "0x..."
}
```

---

# 14. Recommended implementation checklist

## One-time setup

- [ ] Add target chain RPC to your app config.
- [ ] Add anchoring precompile address.
- [ ] Add anchoring ABI.
- [ ] Fund your wallet with testnet gas.
- [ ] Create one registry.
- [ ] Store `registryId`.

## Per document / payload

- [ ] Store the document off-chain.
- [ ] Generate SHA-256 checksum.
- [ ] Prepare metadata.
- [ ] Call `addRecord`.
- [ ] Store tx hash and record details.

## Verification

- [ ] Fetch original document.
- [ ] Recompute SHA-256 checksum.
- [ ] Query `records`.
- [ ] Compare local checksum with on-chain checksum.
- [ ] Show verified / mismatch result to user.

---

# 15. Common mistakes

## Mistake 1 — using registry name as ID

Do not do this:

```js
registry: "customer-documents"
```

Prefer:

```js
registryId: 12
```

Registry names are display labels, not reliable identifiers.

---

## Mistake 2 — trying to store the full document on-chain

Do not store the full file on-chain.

Store:

```
checksum + URI + metadata
```

The file itself should live in:

```
S3 / IPFS / your backend / another storage system
```

---

## Mistake 3 — expecting the chain to verify your document

The chain stores the checksum.

Your app verifies by recomputing the checksum and comparing it with the on-chain record.

---

## Mistake 4 — requiring users to install CLIs

End users should not need:

- `nvnmchaind`
- `mantrachaind`
- Cosmos CLI knowledge

The app should hide that complexity.

Only developers/admins may need CLIs for faucet/manual funding or troubleshooting.

---

## Mistake 5 — forgetting gas

Every write transaction needs gas.

Before calling:

```
addRegistry
addRecord
grantRole
updateRecordStatus
```

make sure the signer wallet has gas on the target chain.

---

# 16. Final recommendation

For a simple integration, document it like this:

## Required

```
EVM wallet
EVM RPC
Gas token
Anchoring ABI
Precompile address
```

## Optional

```
cast
nvnmchaind
mantrachaind
```

## Main app calls

```
addRegistry
addRecord
records
```

## Main user journey

```
Upload document
  → hash document
  → store document off-chain
  → anchor checksum on-chain
  → verify later by comparing checksums
```

That is the cleanest integration-centric approach.
