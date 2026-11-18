---
name: GA Events
date: 2026-09-11T15:47:00.000Z
tags:
  - nvnm-cite
  - nvnm-cite-inv-42043
  - nvnm-cite-inv-42554
  - inv-42043
  - inv-42554
  - wiki
  - architecture
  - analytics
  - privacy
---

# GA Events

**Summary**: Google Analytics event list for the NVNM Cite web page. Required funnel events plus extras, grouped by tier. Branch: `INV-42554-ga`.

**Sources**: `src/nvnm_cite/webapp/static/index.html`, `src/nvnm_cite/webapp/static/app.js`

**Last updated**: 2026-09-11

---

**Project**: NVNM Cite (`nvnm-cite`)  
**Ticket**: INV-42554  
**Branch**: `INV-42554-ga`  
**Application path**: `/Users/valeriyilihmetov/work/inveniam/nvnm/nvnm-cite`

Privacy: event name plus non-content params only. No file bytes, citation text, SHA-256, wallet address, firm, or case.

### Tier 1 — core funnel

**Required**
- `check_citations_started` — file dropped, text pasted, or sample clicked (`method` = `upload` / `paste` / `sample`)
- `check_citations_completed` — results rendered
- `continue_to_record_verification_click` — CTA after results

**Extra**
- `check_citations_failed` — check did not render results (error class only)
- `check_citations_completed` params — empty vs had citations; tally counts (`verified` / `not_found` / `not_covered` / `ambiguous` / `unparseable`); extraction warning yes/no; name-mismatch warning yes/no
- `check_citations_started` param — file type only (`pdf` / `docx` / `txt` / `md`), never the name
- `paste_area_opened` — they opened paste but may not have submitted
- `check_filter_chip_click` — they sliced the results table
- `check_not_covered_expanded` — they opened the out-of-coverage group
- `check_replay_opened` — they opened “Replay these lookups”
- `record_go_to_check_click` — they hit Record with no report and went back to Check

### Tier 2 — conversion to anchoring

**Required**
- `wallet_connect_click` — Connect wallet
- `wallet_connected` — wallet actually connected
- `registry_created` — “Create this registry with wallet” succeeded
- `receipt_signed_anchored` — “Sign & anchor with wallet” succeeded

**Extra**
- `wallet_disconnected` — they left the write path
- `wallet_wrong_network` / `wallet_switch_network` — they hit or cleared the chain gate
- `paste_upload_final_file_click` — they accepted that pasted text must not be anchored
- `registry_line_copied` — they took the filing line before anchoring
- `my_registries_click` — they listed existing matter registries
- `receipt_prepare_started` / `receipt_prepare_completed` / `receipt_prepare_blocked` — live re-check before sign (blocked reason: no doc / no wallet / missing fields — not the field values); completed param: registry-line tier `id` / `name` / `none`; whether create-registry was shown; whether same-name ambiguity was shown
- `registry_create_rejected` / `registry_create_reverted` — create started but did not land
- `receipt_sign_rejected` / `receipt_sign_reverted` — sign started but did not land
- `receipt_verify_now_click` / `receipt_decode_tx_click` / `receipt_view_explorer_click` — after-anchor follow-through

### Tier 3 — third-party verification

**Required**
- `verify_receipt_lookup` — Verify a receipt → Look up
- `inspect_transaction_decode` — Inspect a transaction → Decode

**Extra**
- `verify_receipt_lookup` also on file-drop (same lookup, `method` = `upload` / `hash`)
- `verify_hash_area_opened` — they opened paste-a-hash
- `verify_receipt_lookup` outcome — found / not found / no such registry / ambiguous / bad hash / error (no fingerprint)
- `verify_registry_candidate_click` — they picked a #id after a same-name collision
- `verify_replay_opened` — they opened “Replay the lookup yourself”
- `inspect_transaction_decode` outcome — bad format / not found / pending / confirmed / reverted / unknown selector (no tx hash)

### Tier 4 — navigation

**Required**
- Pageviews for all 5 sections (virtual pageview on tab change: Check, Record, Verify, Inspect, About)
- Footer clicks: `agents.md` / `openapi.json` / `llms.txt`

**Extra**
- FAQ item opened (which question, not the answer text)
- Outbound: CourtListener, Free Law Project, `@NVNM_Chain`

## Related pages

- [Web UI](INV-42043%20-%20NVNM-Cite/wiki/Web%20UI.md)
- [Wiki Index](INV-42043%20-%20NVNM-Cite/wiki/index.md)
