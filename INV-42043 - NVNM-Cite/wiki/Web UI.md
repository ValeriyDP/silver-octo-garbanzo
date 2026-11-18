---
name: Web UI
date: 2026-08-31T13:39:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - architecture
---

# Web UI

**Summary**: The browser UI is raw JavaScript on a static HTML/CSS page. There is no jQuery, no React/Vue, no bundler. The `$` you see in `app.js` is a one-line `getElementById` helper.

**Sources**: [src/nvnm_cite/webapp/static/app.js](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/static/app.js), [src/nvnm_cite/webapp/static/index.html](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/static/index.html), [src/nvnm_cite/webapp/server.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/server.py), [docs/web-demo.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/web-demo.md), [src/nvnm_cite/webapp/__init__.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/__init__.py) (source: those files)

**Last updated**: 2026-08-31

---

## Stack

| Layer | What it is | What it is not |
| ----- | ---------- | -------------- |
| Markup | `static/index.html` — one page, five tab panels | SPA framework, templates |
| Style | `static/app.css` + self-hosted fonts (Source Serif 4, Public Sans, IBM Plex Mono) | Tailwind, CSS-in-JS |
| Behavior | `static/app.js` — one `"use strict"` file, `defer` | jQuery, React, Vue, Alpine, HTMX |
| Server | stdlib `ThreadingHTTPServer` in `webapp/server.py` | Flask, FastAPI, Node |

`index.html` loads only `/app.css` and `/app.js`. No CDN, no npm packages in the page. (source: index.html)

The page comment and the package docstring both call it a **no-framework** static page. (source: webapp `__init__.py`, docs/web-demo.md)

## Why `$` looks like jQuery

It is not jQuery. The whole library is this line:

```javascript
const $ = (id) => document.getElementById(id);
```

(source: app.js)

DOM work is vanilla: `document.createElement`, `textContent`, `classList`, `addEventListener`, `fetch` (via local `apiGet` / upload helpers). Dynamic values are rendered **only** with `textContent` — never `innerHTML`. (source: app.js header comment)

## Trust rules that shape the JS

- The page **never sees a private key** and **contains no JavaScript ABI**. The server prepares calldata; the user's wallet (`window.ethereum`, MetaMask or compatible) signs. (source: app.js, docs/web-demo.md)
- Network identity (chain id, RPC, explorer, gas token) is **server-fed** from `GET /api/status`. Nothing chain-specific is hardcoded in the page. (source: app.js)
- CSP is strict: `script-src 'self'; style-src 'self'; connect-src 'self'` — the browser talks only to this origin. Wallet RPC is via the injected provider, not a third-party script. (source: server.py)

## Boot

On load: `initTabs`, `initCheck`, `initWallet`, `initRecord`, `initVerify`, `initInspect`, then `loadStatus()` and a 60 s status poll. (source: app.js)

## Related pages

- [Backend](NVNM-Cite%20(INV-42043)/wiki/Backend.md) — stdlib HTTP server; no web framework
- [Authentication](NVNM-Cite%20(INV-42043)/wiki/Authentication.md) — no login; wallet is for signing only
- [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md) — Q1: could we use a modern frontend framework?
- [Onboarding](NVNM-Cite%20(INV-42043)/wiki/Onboarding.md)
- [Run Locally](NVNM-Cite%20(INV-42043)/wiki/Run%20Locally.md)
- [Audience](NVNM-Cite%20(INV-42043)/wiki/Audience.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
- [GA Events](NVNM-Cite%20(INV-42554)/GA%20Events.md) — INV-42554 event list for this page
