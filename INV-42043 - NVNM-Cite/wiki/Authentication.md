---
name: Authentication
date: 2026-09-01T06:09:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Authentication

**Summary**: The web app has **no user accounts, no login, no session, no API keys**. Check and Verify are open. The only “who are you” on the product path is a **browser wallet** that signs a receipt. That is chain identity, not app auth.

**Sources**: [src/nvnm_cite/webapp/static/agents.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/static/agents.md), [docs/DEPLOYMENT.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/DEPLOYMENT.md), [docs/web-demo.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/web-demo.md), [src/nvnm_cite/webapp/static/app.js](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/static/app.js) (source: those files)

**Last updated**: 2026-09-01

---

## What is not there

No signup, password, OAuth, JWT, cookie session, or API-key gate on `/api/*`. Agent docs say it in one line: “No authentication and no API keys. Reads are free.” (source: agents.md)

The public container holds **no secrets** and never signs. TLS is the ingress’s job. (source: docs/DEPLOYMENT.md)

Eyecite is a library, not a login system. Nothing is “auth built around eyecite.”

## What exists instead

| Kind | Where | What it is |
| ---- | ----- | ---------- |
| Wallet (EIP-1193) | Record tab / header | MetaMask (or compatible) connects; `eth_requestAccounts`. The receipt’s attester **is** the `0x` address. Server prepares calldata; wallet signs; server never holds the key. Check and Verify never need this. (source: app.js, docs/web-demo.md) |
| Chain write ACL | NVNM anchoring precompile | Deny-by-default. Creator = admin. `grantRole` / `revokeRole` for editors. The page pre-flights with `eth_estimateGas`; a missing grant shows as unauthorized **before** the wallet popup. (source: docs/web-demo.md, service.py) |
| CourtListener token | Loader only (`COURTLISTENER_TOKEN`) | REST v4 incremental updates. Not used by the website Check path. (source: .env.example, update.py) |
| Mainnet signing gate | CLI / config | `NVNM_MAINNET_WRITE_OK=1` + `NVNM_MAINNET_KEY`. Ops-only; never in `.env` or a session. (source: CLAUDE.md) |

## Related pages

- [Audience](NVNM-Cite%20(INV-42043)/wiki/Audience.md)
- [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md)
- [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
