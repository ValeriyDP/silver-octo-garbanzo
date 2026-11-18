---
name: Audience
date: 2026-08-31T13:15:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
---

# Audience

**Summary**: Who NVNM-Cite is built for, by tab and by role — and who it is not for.

**Sources**: [docs/web-demo.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/web-demo.md), [docs/brief-for-firms.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/brief-for-firms.md), [README.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/README.md) (source: those files)

**Last updated**: 2026-08-31

---

The product is lawyer-facing. The web app is the primary surface; the CLI is the same verifier and the same locked receipt v1. (source: docs/web-demo.md)

## Product users

| Who | What they do | Chain traffic |
| --- | ------------ | ------------- |
| Drafting lawyer | Check citations in a brief before filing | Live keyed `records()` reads. Read-only, no gas. |
| Filing lawyer, or their AI agent | Re-check, then record a filing receipt from their own wallet | Read-only re-check, then one wallet-signed `addRecord`. |
| Opposing counsel, clerks, judges | Verify a receipt against a document (or its SHA-256) | Read-only `records()` lookup. Free, no wallet. |
| Anyone | Inspect an anchoring transaction and read it as plaintext | Read-only decode. |

(source: docs/web-demo.md)

The firm-facing one-pager is aimed at **law firms** that need a narrow, stand-behind-able fact: every cited case is a real canonical citation, and they can prove they checked a specific document at a specific time. The problem it names is fabricated or garbled cites (drafting error, copy-paste, AI) and the sanctions / malpractice / reputation cost of those. (source: docs/brief-for-firms.md)

Receipts live in a **per-firm-per-case registry owned by the filing party's wallet**. NVNM is not a write-gatekeeper for those receipts. (source: docs/brief-for-firms.md, CLAUDE.md)

The site also teaches **AI agents** the HTTP API (`llms.txt`, `agents.md`, `openapi.json` at the site root). There is no nvnm-cite MCP server. (source: README.md, IMPLEMENTATION_PLAN.md)

## Operators and this investigation

| Who | Why they are here |
| --- | ----------------- |
| Inveniam / NVNM engineers | Build and change the verifier, normalizer, receipts, webapp, CLI. |
| Devops | Run the public container (`ghcr.io/nvnm-chain/nvnm-cite`) at nvnmcite.com. Stateless, no secrets, no database. (source: docs/DEPLOYMENT.md) |
| This wiki (INV-42043) | Engineer onboarding and investigation notes. You are reading it. |

## Not the audience

NVNM-Cite is **not** a citator, a research platform, or a substitute for Westlaw / Lexis / CourtListener search. It does not tell you whether a case is good law or whether it supports a proposition. (source: README.md, docs/brief-for-firms.md)

It is also not a general-purpose NVNM Chain wallet or explorer. Transaction inspect is only for anchoring txs the app can decode. (source: docs/web-demo.md — inferred from the tab list; the explorer itself is Blockscout.)

## Related pages

- [Onboarding](INV-42043%20-%20NVNM-Cite/wiki/Onboarding.md)
- [Prerequisites](INV-42043%20-%20NVNM-Cite/wiki/Prerequisites.md)
- [Run Locally](INV-42043%20-%20NVNM-Cite/wiki/Run%20Locally.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
