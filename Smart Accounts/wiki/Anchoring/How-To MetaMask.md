---
name: How-To MetaMask
date: 2026-08-12T11:56:24.474Z
tags:
  - smart-accounts
  - anchoring
  - evm-precompile
  - nvnm-testnet
  - metamask
  - frontend
---
Yes — for a beginner guide, **do not ask users to get or paste a private key**.

Use **MetaMask directly in the browser**. The wallet signs transactions for the user. Your app never sees the private key.

> [!info] Related notes
> - [How-To Integration Only](How-To%20Integration%20Only.md) — backend/EVM integration path (private-key signer, `cast`, faucet setup).
> - [How-To Full Guide](How-To%20Full%20Guide.md) — full conceptual + CLI + EVM reference.
> - [Smart Accounts Obtaining Config Values](../Smart%20Accounts%20Obtaining%20Config%20Values.md) — where to source RPC URLs, chain IDs, and contract addresses.

This note covers the browser/MetaMask signing path. Add it to the guide as follows.

---

# MetaMask integration example

## Important: you do not need the private key

If you are building a browser app, users should connect MetaMask and approve transactions there.

Your app should **not** ask users for:

- private key
- seed phrase
- recovery phrase
- mnemonic

MetaMask keeps the private key inside the wallet and signs transactions when the user confirms.

The app only receives the user’s public address, for example:

```
0x1234...
```

---

# 1. Add NVNM testnet to MetaMask

In MetaMask, add a custom network:

```
Network name: NVNM Testnet
RPC URL: https://evm.testnet.nvnmchain.io
Chain ID: 787111
Currency symbol: mUSD
Block explorer: https://explorer.evm.testnet.nvnmchain.io
```

If MetaMask asks for the Chain ID in hex, use:

```
0xC0297
```

---

# 2. Connect MetaMask in your app

Install `ethers`:

```bash
npm install ethers
```

Example:

```js
import { ethers } from "ethers";

async function connectMetaMask() {
  if (!window.ethereum) {
    throw new Error("MetaMask is not installed");
  }

  // Ask user to connect wallet
  const accounts = await window.ethereum.request({
    method: "eth_requestAccounts"
  });

  const userAddress = accounts[0];

  // Browser provider uses MetaMask
  const provider = new ethers.BrowserProvider(window.ethereum);

  // Signer is controlled by MetaMask
  // Your app does NOT know the private key
  const signer = await provider.getSigner();

  return {
    provider,
    signer,
    userAddress
  };
}
```

---

# 3. Switch MetaMask to NVNM testnet

```js
async function switchToNvnmTestnet() {
  if (!window.ethereum) {
    throw new Error("MetaMask is not installed");
  }

  const chainIdHex = "0xC0297"; // 787111

  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: chainIdHex }]
    });
  } catch (switchError) {
    // 4902 means the network is not added yet
    if (switchError.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: chainIdHex,
            chainName: "NVNM Testnet",
            nativeCurrency: {
              name: "mUSD",
              symbol: "mUSD",
              decimals: 18
            },
            rpcUrls: ["https://evm.testnet.nvnmchain.io"],
            blockExplorerUrls: ["https://explorer.evm.testnet.nvnmchain.io"]
          }
        ]
      });
    } else {
      throw switchError;
    }
  }
}
```

---

# 4. Create anchoring contract instance

```js
import { ethers } from "ethers";

const ANCHORING_PRECOMPILE =
  "0x0000000000000000000000000000000000000A00";

const anchoringAbi = [
  "function addRegistry(string name,string description,string metadata) returns (uint64)",
  "function addRecord((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId) record) returns (uint64)",
  "function records(uint64 registryId,string checksum,uint64 recordId,uint64 index,(bytes key,uint64 offset,uint64 limit,bool countTotal,bool reverse) pagination) view returns ((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId)[] records,(bytes nextKey,uint64 total) pagination)"
];

async function getAnchoringContract() {
  await switchToNvnmTestnet();

  const { signer, userAddress } = await connectMetaMask();

  const anchoring = new ethers.Contract(
    ANCHORING_PRECOMPILE,
    anchoringAbi,
    signer
  );

  return {
    anchoring,
    userAddress
  };
}
```

---

# 5. Create a registry with MetaMask

This will open MetaMask and ask the user to approve the transaction.

```js
async function createRegistry() {
  const { anchoring, userAddress } = await getAnchoringContract();

  const tx = await anchoring.addRegistry(
    "customer-documents",
    "Anchoring registry for customer documents",
    JSON.stringify({
      app: "my-app",
      createdBy: userAddress,
      environment: "testnet"
    })
  );

  console.log("Transaction sent:", tx.hash);

  const receipt = await tx.wait();

  console.log("Registry created:", receipt.hash);

  return receipt;
}
```

Important:

> The user pays gas from their MetaMask wallet.

So before calling this, the wallet must have NVNM testnet gas tokens.

---

# 6. Anchor a document with MetaMask

Example: anchor text or JSON data.

```js
async function sha256Text(text) {
  const encoded = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);

  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
```

Add record:

```js
async function anchorDocument() {
  const { anchoring } = await getAnchoringContract();

  const registryId = 12; // use the registryId you created earlier

  const documentText = "Hello, this is my document";
  const checksum = await sha256Text(documentText);

  const record = {
    uri: "https://my-app.example/documents/123",
    checksum,
    checksumAlgo: "sha256",
    metadata: JSON.stringify({
      documentId: "123",
      type: "demo"
    }),
    timestamp: "",      // chain sets this
    status: "active",
    recordId: 0,        // chain sets this
    index: 0,           // chain sets this
    isLatest: false,    // chain sets this
    registryId
  };

  const tx = await anchoring.addRecord(record);

  console.log("Anchor tx sent:", tx.hash);

  const receipt = await tx.wait();

  console.log("Document anchored:", receipt.hash);

  return {
    checksum,
    txHash: receipt.hash
  };
}
```

MetaMask will show a transaction confirmation popup. The user clicks **Confirm**. Your app never touches the private key.

---

# 7. Verify anchored document

```js
async function verifyDocument() {
  const { anchoring } = await getAnchoringContract();

  const registryId = 12;
  const documentText = "Hello, this is my document";
  const checksum = await sha256Text(documentText);

  const pagination = {
    key: "0x",
    offset: 0,
    limit: 10,
    countTotal: false,
    reverse: false
  };

  const result = await anchoring.records(
    registryId,
    checksum,
    0,
    0,
    pagination
  );

  const records = result[0];

  if (records.length === 0) {
    return {
      verified: false,
      reason: "No on-chain record found"
    };
  }

  return {
    verified: records[0].checksum === checksum,
    record: records[0]
  };
}
```

---

# 8. Minimal HTML example

```html
<button id="connect">Connect MetaMask</button>
<button id="create-registry">Create Registry</button>
<button id="anchor">Anchor Demo Document</button>

<script type="module">
  import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.13.2/+esm";

  const ANCHORING_PRECOMPILE =
    "0x0000000000000000000000000000000000000A00";

  const anchoringAbi = [
    "function addRegistry(string name,string description,string metadata) returns (uint64)",
    "function addRecord((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId) record) returns (uint64)"
  ];

  async function switchToNvnmTestnet() {
    const chainIdHex = "0xC0297";

    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: chainIdHex }]
      });
    } catch (error) {
      if (error.code === 4902) {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [{
            chainId: chainIdHex,
            chainName: "NVNM Testnet",
            nativeCurrency: {
              name: "mUSD",
              symbol: "mUSD",
              decimals: 18
            },
            rpcUrls: ["https://evm.testnet.nvnmchain.io"],
            blockExplorerUrls: ["https://explorer.evm.testnet.nvnmchain.io"]
          }]
        });
      } else {
        throw error;
      }
    }
  }

  async function getContract() {
    if (!window.ethereum) {
      alert("Please install MetaMask");
      throw new Error("MetaMask not installed");
    }

    await switchToNvnmTestnet();

    await window.ethereum.request({
      method: "eth_requestAccounts"
    });

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    return new ethers.Contract(
      ANCHORING_PRECOMPILE,
      anchoringAbi,
      signer
    );
  }

  async function sha256Text(text) {
    const encoded = new TextEncoder().encode(text);
    const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);

    return Array.from(new Uint8Array(hashBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
  }

  document.getElementById("connect").onclick = async () => {
    await getContract();
    alert("MetaMask connected");
  };

  document.getElementById("create-registry").onclick = async () => {
    const anchoring = await getContract();

    const tx = await anchoring.addRegistry(
      "customer-documents",
      "Anchoring registry for customer documents",
      JSON.stringify({ app: "demo" })
    );

    alert("Transaction sent: " + tx.hash);

    const receipt = await tx.wait();

    alert("Registry created: " + receipt.hash);
  };

  document.getElementById("anchor").onclick = async () => {
    const anchoring = await getContract();

    const registryId = 12; // replace with your real registryId
    const documentText = "Hello, this is my document";
    const checksum = await sha256Text(documentText);

    const record = {
      uri: "https://my-app.example/documents/123",
      checksum,
      checksumAlgo: "sha256",
      metadata: JSON.stringify({ documentId: "123" }),
      timestamp: "",
      status: "active",
      recordId: 0,
      index: 0,
      isLatest: false,
      registryId
    };

    const tx = await anchoring.addRecord(record);

    alert("Anchor transaction sent: " + tx.hash);

    const receipt = await tx.wait();

    alert("Document anchored: " + receipt.hash);
  };
</script>
```

---

# 9. What to say in the guide

Replace any private-key-first explanation with this wording:

> For browser-based applications, users should connect MetaMask or another EVM wallet. The application never asks for or stores private keys. MetaMask signs the transaction after the user confirms it. Private-key examples are only for backend scripts, local testing, or admin automation.

---

# 10. When private keys are used

Private keys are only needed if you are doing:

- backend automation
- server-side scripts
- CLI testing with `cast`
- CI jobs
- admin-only registry setup scripts

Even then, do not paste private keys into code or docs.

Use environment variables or secret managers:

```bash
PRIVATE_KEY=0x...
```

But for a user-facing integration:

> **Use MetaMask. Do not ask for private keys.**
