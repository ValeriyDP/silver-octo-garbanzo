---
name: Run Locally
date: 2026-08-31T13:25:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - how-to
---

# Run Locally

**Summary**: How to start NVNM-Cite on this machine — `uv` for a source checkout, or the repo `Dockerfile` for the same container the public site uses. Reads default to mainnet. No `.env` and no wallet are required to check a brief.

**Sources**: [README.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/README.md), [Dockerfile](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/Dockerfile), [.dockerignore](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/.dockerignore), [docs/web-demo.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/web-demo.md), [docs/DEPLOYMENT.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/docs/DEPLOYMENT.md), [src/nvnm_cite/webapp/__main__.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/__main__.py) (source: those files)

**Last updated**: 2026-08-31

---

## Web app (do this first)

```bash
cd /Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite
uv sync
uv run python -m nvnm_cite.webapp
```

Then open http://127.0.0.1:8787. (source: README.md, docs/web-demo.md)

The process prints the URL, network label, chain id, RPC, and data-dir. Bind defaults to `127.0.0.1:8787`. (source: webapp `__main__.py`)

Useful flags (`uv run python -m nvnm_cite.webapp --help`):

| Flag | Default | Notes |
| ---- | ------- | ----- |
| `--host` | `127.0.0.1` | Use `0.0.0.0` only if you intend to expose it. |
| `--port` | `8787` | |
| `--network` | `mainnet` (or `NVNM_NETWORK`) | `testnet` only when you mean to. |
| `--rpc` | that network's public RPC | |
| `--data-dir` | `data` | Optional local `corpus.sqlite` / `chain_index.sqlite`. Status-panel counts only; chain is still the lookup authority. |
| `--telemetry` | off | Do not turn on unless you intend aggregate by-citation counts. |

(source: webapp `__main__.py`, docs/web-demo.md)

First exercise: upload `tests/fixtures/briefs/extracted/mata-avianca-nysd-ecf24-reply-memo.txt`. *Varghese* (the ChatGPT-invented cite) should be NOT_FOUND. (source: docs/web-demo.md)

Uploads are parsed in memory and discarded with the response. Drafting checks read NVNM Chain live. You need outbound HTTPS to the RPC. (source: webapp `__init__.py`)

## Same check from the CLI

```bash
cd /Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite
uv run nvnm-cite check tests/fixtures/briefs/extracted/mata-avianca-nysd-ecf24-reply-memo.txt
```

Read-only. No gas. Add `--json` for the full report. (source: cli.py)

## Docker (repo Dockerfile)

The checkout has a multi-stage `Dockerfile`: Python 3.11-slim, locked `uv` env, non-root uid 10001, no secrets, telemetry off. The image CMD is `python -m nvnm_cite.webapp --host 0.0.0.0 --port 8787 --data-dir /app/data`. `.dockerignore` is an allowlist (`pyproject.toml`, `uv.lock`, `README.md`, `src/`) so `.env` and local databases never enter the build. (source: Dockerfile, .dockerignore)

Build this checkout and run it:

```bash
cd /Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite
docker build -t nvnm-cite:local .
docker run --rm -p 8787:8787 nvnm-cite:local
```

Then open http://127.0.0.1:8787. Same first exercise as above. Never mount a `.env` into the container. (source: docs/DEPLOYMENT.md)

Optional runtime overrides (all optional; image defaults are production):

```bash
docker run --rm -p 8787:8787 -e NVNM_NETWORK=testnet nvnm-cite:local
```

`NVNM_MAINNET_RPC` overrides the RPC URL. (source: docs/DEPLOYMENT.md)

To run the **published** image instead of this checkout (may not match local `main`):

```bash
docker run --rm -p 8787:8787 ghcr.io/nvnm-chain/nvnm-cite:latest
```

(source: docs/DEPLOYMENT.md)

## Tests

```bash
cd /Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite
uv run pytest
```

(source: README.md, pyproject.toml)

## What you should not do on day one

- Do not send a chain write. CLI `anchor` is a dry-run plan unless you pass `--anchor`. Get an explicit OK first. (source: CLAUDE.md, cli.py)
- Do not put a mainnet key in `.env`. Mainnet writes are ops-only and dual-gated. (source: .env.example)
- Do not print `.env` values, keys, or seed phrases into this vault or into chat. (source: CLAUDE.md)
- Do not assume the public site is the same commit as this checkout. Live nvnmcite.com and `main` have drifted before. (source: IMPLEMENTATION_PLAN.md — unverified as of this page's date; treat as a standing caution)

## If it will not start

| Symptom | What to check |
| ------- | ------------- |
| `uv` not found | Install uv, then `uv sync`. Python must be 3.11+. Or skip uv and use the Dockerfile path above. (source: README.md, Dockerfile) |
| Docker build fails | Need Docker Desktop (or a daemon). First build compiles an arm64 C++ extension in the build stage if you are on Apple Silicon; that is expected. (source: Dockerfile) |
| Check tab hangs or 502 | Public RPC unreachable. `GET /api/status` — look at `.chain.rpc_ok` and `.chain.chain_id_ok`. (source: docs/DEPLOYMENT.md) |
| Wrong chain | Confirm the banner / process log says mainnet 1611 unless you passed `--network testnet`. (source: webapp `__main__.py`) |
| Want testnet | `uv run python -m nvnm_cite.webapp --network testnet`. Testnet does not hold the production corpus. (source: CLAUDE.md) |

## Related pages

- [Onboarding](NVNM-Cite%20(INV-42043)/wiki/Onboarding.md)
- [Prerequisites](NVNM-Cite%20(INV-42043)/wiki/Prerequisites.md)
- [Audience](NVNM-Cite%20(INV-42043)/wiki/Audience.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
