---
name: ABI anchoring
date: 2026-08-12T12:05:17.054Z
tags:
---
Below is a **v1.2.0-style ABI** for the Anchoring precompile based on the latest integration guide.

Precompile address:

```
0x0000000000000000000000000000000000000A00
```

## Human-readable ABI for `ethers.js`

```jsx
export const ANCHORING_PRECOMPILE_ADDRESS =
  "0x0000000000000000000000000000000000000A00";

export const ANCHORING_ABI = [
  "function addRegistry(string name,string description,string metadata) returns (uint64 registryId)",

  "function addRecord((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId) record) returns (uint64 recordId)",

  "function updateRecordStatus(uint64 registryId,uint64 recordId,uint64 index,string status)",

  "function records(uint64 registryId,string checksum,uint64 recordId,uint64 index,(bytes key,uint64 offset,uint64 limit,bool countTotal,bool reverse) pagination) view returns ((string uri,string checksum,string checksumAlgo,string metadata,string timestamp,string status,uint64 recordId,uint64 index,bool isLatest,uint64 registryId)[] records,(bytes nextKey,uint64 total) pagination)",

  "function registries(uint64 registryId,(bytes key,uint64 offset,uint64 limit,bool countTotal,bool reverse) pagination) view returns ((uint64 id,string name,string description,string creator,string createdAt,string metadata)[] registries,(bytes nextKey,uint64 total) pagination)",

  "function grantRole(uint64 registryId,string checksum,address account,string role)",

  "function revokeRole(uint64 registryId,string checksum,address account,string role)"
];
```

---

## Full JSON ABI

```json
[
  {
    "type": "function",
    "name": "addRegistry",
    "stateMutability": "nonpayable",
    "inputs": [
      {
        "name": "name",
        "type": "string"
      },
      {
        "name": "description",
        "type": "string"
      },
      {
        "name": "metadata",
        "type": "string"
      }
    ],
    "outputs": [
      {
        "name": "registryId",
        "type": "uint64"
      }
    ]
  },
  {
    "type": "function",
    "name": "addRecord",
    "stateMutability": "nonpayable",
    "inputs": [
      {
        "name": "record",
        "type": "tuple",
        "components": [
          {
            "name": "uri",
            "type": "string"
          },
          {
            "name": "checksum",
            "type": "string"
          },
          {
            "name": "checksumAlgo",
            "type": "string"
          },
          {
            "name": "metadata",
            "type": "string"
          },
          {
            "name": "timestamp",
            "type": "string"
          },
          {
            "name": "status",
            "type": "string"
          },
          {
            "name": "recordId",
            "type": "uint64"
          },
          {
            "name": "index",
            "type": "uint64"
          },
          {
            "name": "isLatest",
            "type": "bool"
          },
          {
            "name": "registryId",
            "type": "uint64"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "recordId",
        "type": "uint64"
      }
    ]
  },
  {
    "type": "function",
    "name": "updateRecordStatus",
    "stateMutability": "nonpayable",
    "inputs": [
      {
        "name": "registryId",
        "type": "uint64"
      },
      {
        "name": "recordId",
        "type": "uint64"
      },
      {
        "name": "index",
        "type": "uint64"
      },
      {
        "name": "status",
        "type": "string"
      }
    ],
    "outputs": []
  },
  {
    "type": "function",
    "name": "records",
    "stateMutability": "view",
    "inputs": [
      {
        "name": "registryId",
        "type": "uint64"
      },
      {
        "name": "checksum",
        "type": "string"
      },
      {
        "name": "recordId",
        "type": "uint64"
      },
      {
        "name": "index",
        "type": "uint64"
      },
      {
        "name": "pagination",
        "type": "tuple",
        "components": [
          {
            "name": "key",
            "type": "bytes"
          },
          {
            "name": "offset",
            "type": "uint64"
          },
          {
            "name": "limit",
            "type": "uint64"
          },
          {
            "name": "countTotal",
            "type": "bool"
          },
          {
            "name": "reverse",
            "type": "bool"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "records",
        "type": "tuple[]",
        "components": [
          {
            "name": "uri",
            "type": "string"
          },
          {
            "name": "checksum",
            "type": "string"
          },
          {
            "name": "checksumAlgo",
            "type": "string"
          },
          {
            "name": "metadata",
            "type": "string"
          },
          {
            "name": "timestamp",
            "type": "string"
          },
          {
            "name": "status",
            "type": "string"
          },
          {
            "name": "recordId",
            "type": "uint64"
          },
          {
            "name": "index",
            "type": "uint64"
          },
          {
            "name": "isLatest",
            "type": "bool"
          },
          {
            "name": "registryId",
            "type": "uint64"
          }
        ]
      },
      {
        "name": "pagination",
        "type": "tuple",
        "components": [
          {
            "name": "nextKey",
            "type": "bytes"
          },
          {
            "name": "total",
            "type": "uint64"
          }
        ]
      }
    ]
  },
  {
    "type": "function",
    "name": "registries",
    "stateMutability": "view",
    "inputs": [
      {
        "name": "registryId",
        "type": "uint64"
      },
      {
        "name": "pagination",
        "type": "tuple",
        "components": [
          {
            "name": "key",
            "type": "bytes"
          },
          {
            "name": "offset",
            "type": "uint64"
          },
          {
            "name": "limit",
            "type": "uint64"
          },
          {
            "name": "countTotal",
            "type": "bool"
          },
          {
            "name": "reverse",
            "type": "bool"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "registries",
        "type": "tuple[]",
        "components": [
          {
            "name": "id",
            "type": "uint64"
          },
          {
            "name": "name",
            "type": "string"
          },
          {
            "name": "description",
            "type": "string"
          },
          {
            "name": "creator",
            "type": "string"
          },
          {
            "name": "createdAt",
            "type": "string"
          },
          {
            "name": "metadata",
            "type": "string"
          }
        ]
      },
      {
        "name": "pagination",
        "type": "tuple",
        "components": [
          {
            "name": "nextKey",
            "type": "bytes"
          },
          {
            "name": "total",
            "type": "uint64"
          }
        ]
      }
    ]
  },
  {
    "type": "function",
    "name": "grantRole",
    "stateMutability": "nonpayable",
    "inputs": [
      {
        "name": "registryId",
        "type": "uint64"
      },
      {
        "name": "checksum",
        "type": "string"
      },
      {
        "name": "account",
        "type": "address"
      },
      {
        "name": "role",
        "type": "string"
      }
    ],
    "outputs": []
  },
  {
    "type": "function",
    "name": "revokeRole",
    "stateMutability": "nonpayable",
    "inputs": [
      {
        "name": "registryId",
        "type": "uint64"
      },
      {
        "name": "checksum",
        "type": "string"
      },
      {
        "name": "account",
        "type": "address"
      },
      {
        "name": "role",
        "type": "string"
      }
    ],
    "outputs": []
  }
]
```

## Notes

- This is the **registry-id-based ABI**, not the older registry-name-based version.
- `addRecord`, `records`, and `registries` changed in v1.2.0.
- For new integrations, use `registryId` everywhere.
- `addRegistry`, `grantRole`, `revokeRole`, and `updateRecordStatus` are unchanged compared with the referenced upgrade guide.
- The precompile address is fixed:

```
0x0000000000000000000000000000000000000A00
```
