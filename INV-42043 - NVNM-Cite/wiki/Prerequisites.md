---
name: Prerequisites
date: 2026-08-31T13:25:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Prerequisites

**Summary**: What to know before reading or running NVNM-Cite. Domain invariants first, then tools. You can boot the local web app with almost none of the write-path setup.

**Sources**: [CLAUDE.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/CLAUDE.md), [README.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/README.md), [docs/web-demo.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/web-demo.md), [pyproject.toml](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/pyproject.toml), [.env.example](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/.env.example) (source: those files)

**Last updated**: 2026-08-31

---

## Hold these invariants

Do not violate them, and do not explain the product as if they were optional. (source: CLAUDE.md)

1. **Citations stay plaintext.** Identifiers are never hashed. The only hash in the system is the SHA-256 of the checked document inside a receipt.
2. **Existence only.** No holdings, no propositions, no good-law flags. If citator data ever enters, it is a named citator's attested claim, never an NVNM assertion.
3. **A chain WRITE happens only at filing time**, and only when someone explicitly anchors. Drafting checks are live `eth_call` reads. Those reads are point-to-point (no mempool, no on-chain trace). The win is non-repudiation, not secrecy: anyone can replay the same `records()` call. The local SQLite index is a rebuildable cache, never the lookup authority.
4. **Third parties can own registries.** Writes are deny-by-default (creator = admin). There is no single global shared registry. Court registries are populated by Inveniam; receipts live in per-firm-per-case registries owned by the filing wallet.
5. **The normalizer is in the trust boundary.** Its spec is open and versioned. Every receipt records the version used.
6. **The product name is NVNM Chain.** Never "Inveniam Chain".
7. **Receipts do not list cited cases.** They bind document SHA-256 + provenance + a non-identifying status tally.

Registry names are **not unique** on chain (anchoring v1.2.0). Reads and writes key on the numeric registry `#id`. The pinned manifests in `src/nvnm_cite/chain/registry_manifest_*.json` are the name→id trust anchor for court registries. (source: CLAUDE.md)

## What the product is (and is not)

| It is | It is not |
| ----- | --------- |
| A check that a citation exists as a canonical key | A claim that the case supports your argument |
| A receipt that a specific document was checked | Publication of the brief or its authority list |
| Provenance you can replay | A vendor's word that a check happened |

(source: docs/brief-for-firms.md, README.md)

## Chain picture (enough to start)

| | Mainnet (default for reads and demos) | Testnet (writes in development) |
| --- | --- | --- |
| EVM chain ID | 1611 | 787111 |
| RPC | https://evm.nvnmchain.io | https://evm.testnet.nvnmchain.io |
| Explorer | https://evm.explorer.nvnmchain.io | https://explorer.evm.testnet.nvnmchain.io |

Mainnet holds the live corpus: 2,114 court registries, about 11.94M citation records, ids 69–2182. (source: CLAUDE.md, README.md)

**Never write to mainnet from a session.** Local signing to mainnet is gated on both `NVNM_MAINNET_WRITE_OK=1` and a distinct `NVNM_MAINNET_KEY` — neither belongs in `.env`. (source: CLAUDE.md, .env.example)

Chain ID 58887 / manveniam-1 is retired. Do not use it. (source: CLAUDE.md)

## Tools for a local read-only boot

You need **one** of these, plus network access to the public mainnet RPC. The server holds no keys and signs nothing. (source: docs/DEPLOYMENT.md, webapp `__init__.py`)

- **Python 3.11+** and **[uv](https://docs.astral.sh/uv/)** (`uv sync`, `uv run …`). (source: README.md, pyproject.toml)
- **or Docker**, using the repo `Dockerfile` (same image shape as production). (source: Dockerfile, docs/DEPLOYMENT.md)

You do **not** need, for Check / Verify / Inspect:

- A `.env` file
- A funded wallet
- A local SQLite corpus or chain index
- Kubernetes
- A CourtListener token

You **do** need extra setup only for:

| Goal                                      | Extra                                                                                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Anchor a receipt from the CLI             | Testnet key in `.env` (`NVNM_TESTNET_KEY`). Get an explicit OK before any write. (source: CLAUDE.md, .env.example)                          |
| Anchor from the web UI                    | A browser wallet (MetaMask or compatible) on the network the server selected. The page never sees a private key. (source: docs/web-demo.md) |
| Incremental corpus updates                | `COURTLISTENER_TOKEN`. (source: .env.example)                                                                                               |
| Operator load / reconcile / index rebuild | CLI operator commands; not first-day work. (source: cli.py)                                                                                 |

## Repo state files (if you will change code)

All multi-session state lives in three files in the app repo, not in this vault: `CLAUDE.md` (rules), `IMPLEMENTATION_PLAN.md` (position), `DECISIONS.md` (memory). (source: README.md)

This vault (`wiki/` + `decisions/`) is the investigation notebook for INV-42043. Do not treat it as a second copy of those three files.

## Related pages

- [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md)
- [Audience](INV-42043%20-%20NVNM-Cite/wiki/Audience.md)
- [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
