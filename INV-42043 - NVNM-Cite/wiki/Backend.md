---
name: Backend
date: 2026-09-01T06:10:00.000Z
tags:
  - nvnm-cite-inv-42043
  - inv-42043
  - wiki
  - architecture
---

# Backend

**Summary**: No Flask, FastAPI, Django, or other web framework. The site is Python’s stdlib `ThreadingHTTPServer` + `BaseHTTPRequestHandler` in `webapp/server.py`. Runtime deps are eyecite, reporters-db, courts-db, and pdfplumber only.

**Sources**: [src/nvnm_cite/webapp/server.py](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/src/nvnm_cite/webapp/server.py), [pyproject.toml](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/pyproject.toml), [DECISIONS.md](file:///Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite/DECISIONS.md) 2026-06-11 (source: those files)

**Last updated**: 2026-09-01

---

`server.py` opens with: “Stdlib HTTP server for the web demo. No frameworks, no new deps.” (source: server.py)

`pyproject.toml` dependencies: `courts-db`, `eyecite`, `pdfplumber`, `reporters-db`. Dev: `pytest`. No uvicorn, gunicorn, or ASGI stack. (source: pyproject.toml)

The handler serves static files from `webapp/static/` and a handful of `/api/*` routes. Uploads are raw bytes in memory. Business logic lives in `webapp/service.py` and `verifier/`, not in a framework. [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md) is the same no-framework choice on the client.

## Related pages

- [Open Questions](NVNM-Cite%20(INV-42043)/wiki/Open%20Questions.md) — Q6: web framework + SQLAlchemy
- [Web UI](NVNM-Cite%20(INV-42043)/wiki/Web%20UI.md)
- [Authentication](NVNM-Cite%20(INV-42043)/wiki/Authentication.md)
- [How Check Finds Citations](NVNM-Cite%20(INV-42043)/wiki/How%20Check%20Finds%20Citations.md)
- [Wiki Index](NVNM-Cite%20(INV-42043)/wiki/index.md)
