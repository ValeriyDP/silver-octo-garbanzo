---
name: QA Person Graveyard
date: 2026-09-07T18:49:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - qa
  - how-to
---

# QA Person Graveyard

**Summary**: API-call script for QA to verify [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) on **person erase only**. After erase, the sidecar must refuse a new ingest for the same `user_id` (`410` / `subject_erased`) and must not decrypt old content (`410` / `erased` on GET; verify `result: erased`). This page is for testers, not implementers.

**Sources**: [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md); sidecar doors in repo `docs/api/API_SPECIFICATION.md` (Content Sidecar Endpoints); local users in `docs/guides/GETTING_STARTED.md`; start path in [New Developer Onboarding](New%20Developer%20Onboarding.md).

**Last updated**: 2026-09-08 (Taskfile developer path: `USER_ID` / `RECORD_ID` / `SIDECAR_URL`, `sidecar:*`, `start:sidecar:replica`).

---

All calls go to the **content sidecar**, not the core.

| Service | Default URL | This feature? |
| --- | --- | --- |
| Content sidecar | `http://localhost:8081` | **Yes** — ingest, read, verify, erase |
| Anchoring core | `http://localhost:8000` | No — proofs stay; a core GET after erase is not a fail |

Local start (app repo): `task start:api` then `task start:sidecar`. Health: `curl -s http://localhost:8081/health`.

QA can stay on the curl steps below. **Developers** use the same script via `task` — see [Taskfile (developer)](#taskfile-developer).

## Tokens

Local FusionAuth, tenant `dev-company`. You need **two** users — `writer` cannot erase; `company_admin` cannot ingest.

| User | Password | Roles | Use for |
| --- | --- | --- | --- |
| `writer@test.local` | `writer123` | `writer` + `reader` | ingest, read, verify |
| `companyadmin@test.local` | `companyadmin123` | `company_admin` | preview, erase, ledger |

```bash
FA=http://localhost:9011
APP=b21c6087-f7d6-4cdd-9ae4-79778ee8ee17   # local FusionAuth application id

WRITER=$(curl -s -X POST "$FA/oauth2/token" \
  -d "grant_type=password&client_id=$APP&username=writer@test.local&password=writer123&scope=openid offline_access" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

ADMIN=$(curl -s -X POST "$FA/oauth2/token" \
  -d "grant_type=password&client_id=$APP&username=companyadmin@test.local&password=companyadmin123&scope=openid offline_access" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

SIDECAR=http://localhost:8081
USER=qa.forget.$(date +%s)@example.test
```

Every `/v1/...` request needs `Authorization: Bearer <token>`. The sidecar refuses a token without a `company_id` claim.

## Taskfile (developer)

Same checks as the curl script. Work from `trace-chain/InveniamIndicia`. `sidecar:*` uses **httpie** (`http`) and **jq** (not Python). `task` fetches the FusionAuth token (`writer@test.local` on ingest/read; `companyadmin@test.local` on erase). `task push:event` still builds the faker payload in Python — that is event generation, not the HTTP client.

`sidecar:get` / `sidecar:verify` / `push:event` **exit 1** on 410. That is expected after erase — read the `HTTP` line, do not treat a non-zero exit as a broken Taskfile.

Pin **one** subject. Bare `task push:event` mints a random `user_id` each time; you cannot erase/reingest that person.

```bash
export USER_ID=qa.forget.$(date +%s)@example.test
```

### Start

```bash
task start:api        # terminal 1 — core + FusionAuth
task start:sidecar    # terminal 2 — replica A on :8081
```

If `task push:event` returns **500 `pseudonymization_failed`**, it is not `USER_ID`. `vault server -dev` is in-memory: a restart (or `vault:up` after the machine slept) wipes Transit keys, but Postgres still holds the old wrapped tenant secret (`tenant_pseudonym_keys`, minted 2026-09-02 on this machine). Unwrap fails. Local recovery:

```bash
docker exec indicia-postgres psql -U indicia -d indicia_sidecar \
  -c "DELETE FROM tenant_pseudonym_keys WHERE company_id = 'dev-company';"
```

Then retry `USER_ID="$USER_ID" task push:event`. The sidecar mints a new secret against the current Vault. No sidecar restart needed. Old ciphertext from before the Vault wipe is already unreadable — that is expected on `-dev`.

### 1. Baseline ingest and read

```bash
USER_ID="$USER_ID" task push:event
```

Copy `record_id` from the JSON (`HTTP 202`).

```bash
RECORD_ID=<paste> task sidecar:get
RECORD_ID=<paste> task sidecar:verify
```

**Pass:** get **200** + canary in content; verify `result` is `match`. `tier2.user_id` is not `$USER_ID`.

### 2. Preview

```bash
USER_ID="$USER_ID" task sidecar:preview
```

**Pass:** **200**, `record_count` ≥ 1, `already_erased` false. `RECORD_ID=… task sidecar:get` still 200.

### 3. Erase

```bash
USER_ID="$USER_ID" task sidecar:erase
USER_ID="$USER_ID" task sidecar:erase    # re-POST
task sidecar:ledger
```

**Pass:** first **200**, `already_erased` false; second **200**, `already_erased` true, timestamps unchanged; ledger `count` ≥ 1, pseudonyms only.

### 4. Read / verify after erase

```bash
RECORD_ID=<paste> task sidecar:get
RECORD_ID=<paste> task sidecar:verify
```

**Pass:** get **410** `erased` (task exits 1); verify **200** `result: erased` + `event_root`.

### 5. Re-ingest the same person

```bash
USER_ID="$USER_ID" task push:event
```

**Pass:** **410** `subject_erased` (task exits 1). No new `record_id`.

**Fail if:** **202**.

### 6. Isolation

```bash
USER_ID=qa.other.$(date +%s)@example.test task push:event
```

**Pass:** **202**.

### 7. Optional Redis flush

```bash
task redis:flush              # docker exec indicia-redis redis-cli FLUSHALL
RECORD_ID=<paste> task sidecar:get
USER_ID="$USER_ID" task push:event
```

**Pass:** get 410 `erased`; push 410 `subject_erased`.

### 8. Two replicas

```bash
task start:sidecar:replica    # terminal 3 — replica B on :8082
```

Do **not** run `task start:sidecar` twice.

```bash
USER_ID="$USER_ID" task push:event                          # ingest on A
RECORD_ID=<paste> SIDECAR_URL=http://localhost:8082 task sidecar:get   # warm B
USER_ID="$USER_ID" task sidecar:erase                       # erase on A
RECORD_ID=<paste> SIDECAR_URL=http://localhost:8082 task sidecar:get   # 410 erased
USER_ID="$USER_ID" SIDECAR_URL=http://localhost:8082 task push:event   # 410 subject_erased
```

**Pass:** second get on B is **410** `erased`, not 200 plaintext. Push to B is **410** `subject_erased`.

### Task map

| Step | Command | Needs |
| --- | --- | --- |
| Start A | `task start:api` then `task start:sidecar` | — |
| Start B | `task start:sidecar:replica` | A already healthy |
| Ingest | `USER_ID=… task push:event` | — |
| Preview / erase | `USER_ID=… task sidecar:preview` / `sidecar:erase` | — |
| Ledger | `task sidecar:ledger` | — |
| Read / verify | `RECORD_ID=… task sidecar:get` / `sidecar:verify` | — |
| Hit B | prefix `SIDECAR_URL=http://localhost:8082` | B running |
| Flush Redis | `task redis:flush` | `indicia-redis` container up |

## Event body (reuse)

`agent.run.analyze` schema version 2 — the door validates before it seals.

```bash
event_json() {
  local run_id="$1"
  cat <<EOF
{
  "event_type": "agent.run.analyze",
  "schema_version": 2,
  "company_id": "dev-company",
  "timestamp": "2026-09-07T12:00:00Z",
  "user_id": "$USER",
  "agent_id": "agent-qa",
  "agent_type": "analyzer",
  "model_id": "claude-opus-5",
  "requested_by": "$USER",
  "run_id": "$run_id",
  "fulfillment_status": "success",
  "duration_ms": 100,
  "gen_ai.input.messages": "QA-CANARY-plaintext"
}
EOF
}
```

Use a **new** `Idempotency-Key` on every ingest you expect to be a real attempt. Replaying the same key within 24 hours can return the cached **202** without hitting the forget fence — accepted, not a leak. That is not the remint test.

---

## 1. Baseline — ingest and read (not erased)

```bash
IDEMP=qa-$(date +%s)-1
curl -sS -D - -X POST "$SIDECAR/v1/events" \
  -H "Authorization: Bearer $WRITER" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $IDEMP" \
  -d "$(event_json run-qa-1)"
```

**Pass:** HTTP **202**. Body has `record_id`, `event_id`, `event_root`. Save `RECORD_ID`.

```bash
curl -sS -D - -H "Authorization: Bearer $WRITER" "$SIDECAR/v1/events/$RECORD_ID"
curl -sS -H "Authorization: Bearer $WRITER" "$SIDECAR/v1/events/$RECORD_ID/verify"
```

**Pass:**

- GET **200**. `content` contains `QA-CANARY-plaintext`.
- Verify **200**, `result` is `match`.
- `tier2.user_id` is a **pseudonym**, not the raw `$USER`.

## 2. Preview — destroys nothing

```bash
curl -sS -X POST "$SIDECAR/v1/erasures/preview" \
  -H "Authorization: Bearer $ADMIN" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"$USER\"}"
```

**Pass:** **200**, `record_count` ≥ 1, `already_erased` is `false`. Repeat the GET from step 1 — content still readable.

## 3. Erase

```bash
curl -sS -D - -X POST "$SIDECAR/v1/erasures" \
  -H "Authorization: Bearer $ADMIN" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"$USER\"}"
```

**Pass:** **200**, `key_destroyed` true, `already_erased` false, `subject_pseudonym` present. Body must **not** contain the raw `$USER`.

Re-POST the same body.

**Pass:** **200**, `already_erased` true. `destroyed_at` and `completion_by` are **unchanged**.

```bash
curl -sS -H "Authorization: Bearer $ADMIN" "$SIDECAR/v1/erasures"
```

**Pass:** **200**, `count` ≥ 1, identifiers are pseudonyms only.

## 4. Read and verify after erase

```bash
curl -sS -D - -H "Authorization: Bearer $WRITER" "$SIDECAR/v1/events/$RECORD_ID"
curl -sS -H "Authorization: Bearer $WRITER" "$SIDECAR/v1/events/$RECORD_ID/verify"
```

**Pass:**

- GET **410**, `"error": "erased"`. No plaintext, no canary.
- Verify **200**, `"result": "erased"`. `event_root` still present (the proof survives). Not `content_mismatch`, not `not_held`.

## 5. New feature — ingest the same person again

New idempotency key. New `run_id`. Same `$USER`.

```bash
curl -sS -D - -X POST "$SIDECAR/v1/events" \
  -H "Authorization: Bearer $WRITER" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: qa-$(date +%s)-2" \
  -d "$(event_json run-qa-2)"
```

**Pass:** **410 Gone**, `"error": "subject_erased"`. No new `record_id`. Message: ingest refused until un-forget; anchored proofs unaffected.

**Fail if:** **202** — that is remint (hole 2 still open).

## 6. Isolation — another person still works

Set `USER` to a **different** email and repeat step 1.

**Pass:** ingest **202**, GET **200** with content.

## 7. Optional — Redis flush (heal)

Only on a disposable local stack. `FLUSHALL` also wipes idempotency keys and the core stream. Run it **inside** the Redis container — do not use a host `redis-cli` (that can hit a different Redis).

```bash
task redis:flush
```

That is `docker exec indicia-redis redis-cli FLUSHALL`.

Then repeat steps 4 and 5 (new idempotency key on ingest).

**Pass:** GET still **410** `erased`. New ingest still **410** `subject_erased` (not 202). The first request after flush may be slightly slower (heal from Postgres `erasure_ledger`).

GET after erase+flush is a **weaker** proof: the Vault key is already destroyed, so the ledger fallback can still say `erased` even if Redis never heals. The remint **410** is the unique heal check.

## 8. Two replicas (sibling DEK cache)

A “replica” is a **second sidecar process**: same Redis, same Postgres, same Vault, **its own RAM**. That is the only way to see hole 1 (sibling still decrypts from a warm DEK cache). Two curl processes against **one** sidecar are not two replicas. `FLUSHALL` (step 7) is heal, not multi-replica.

Do **not** run `task start:sidecar` twice — Air will fight over `:8081`. Leave replica **A** as the Taskfile process. Start replica **B** by hand on another port.

### What must be shared vs not

| Shared (same as A) | Per process |
| --- | --- |
| Redis `localhost:6379` (forget set + idempotency) | Listen port (`:8081` vs `:8082`) |
| Sidecar Postgres `indicia_sidecar` | In-process DEK cache |
| Vault, FusionAuth, core `:8000` | PID / logs |

### Start replica B

Replica A is already up (`task start:sidecar` → `:8081`). In another terminal, from the app repo:

```bash
cd /Users/valeriyilihmetov/work/inveniam/trace-chain/InveniamIndicia

set -a
. .data/vault-dev.env
set +a

INDICIA_KEYVAULT_ADDR="${INDICIA_KEYVAULT_ADDR}" \
INDICIA_KEYVAULT_TOKEN="${INDICIA_KEYVAULT_TOKEN:-root}" \
INDICIA_KEYVAULT_TRANSIT_MOUNT="${INDICIA_KEYVAULT_TRANSIT_MOUNT:-transit}" \
INDICIA_SIDECAR_LISTEN_ADDR=":8082" \
INDICIA_SIDECAR_RECORD_STORE_DSN="postgres://indicia:indicia@localhost:5432/indicia_sidecar?sslmode=disable" \
INDICIA_SIDECAR_CORE_URL="http://localhost:8000" \
INDICIA_SIDECAR_REDIS_ADDR="localhost:6379" \
INDICIA_FUSIONAUTH_URL="http://localhost:9011" \
INDICIA_FUSIONAUTH_APPLICATION_ID="b21c6087-f7d6-4cdd-9ae4-79778ee8ee17" \
INDICIA_FUSIONAUTH_ISSUER="acme.com" \
go run ./cmd/sidecar
```

```bash
curl -s http://localhost:8081/health
curl -s http://localhost:8082/health
```

Same `$WRITER` / `$ADMIN` / `$USER` / `event_json` as above.

```bash
A=http://localhost:8081
B=http://localhost:8082
```

### Script

1. **Ingest on A** — warms A; creates the row both processes will read.

```bash
curl -sS -D - -X POST "$A/v1/events" \
  -H "Authorization: Bearer $WRITER" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: qa-$(date +%s)-a" \
  -d "$(event_json run-qa-replica-1)"
```

**Pass:** **202**. Save `RECORD_ID`.

2. **Read on B** — this **warms B’s DEK cache**. Skip this and B never has the hole to close.

```bash
curl -sS -D - -H "Authorization: Bearer $WRITER" "$B/v1/events/$RECORD_ID"
```

**Pass:** **200**, canary in `content`.

3. **Erase on A**

```bash
curl -sS -D - -X POST "$A/v1/erasures" \
  -H "Authorization: Bearer $ADMIN" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"$USER\"}"
```

**Pass:** **200**.

4. **Read on B again** — same `RECORD_ID`.

```bash
curl -sS -D - -H "Authorization: Bearer $WRITER" "$B/v1/events/$RECORD_ID"
```

**Pass (ADR-0003):** **410**, `"error": "erased"`. No canary. B asked Redis (`SISMEMBER`) **before** `OpenEvent`, so the warm cache is never used.

**Fail (old hole):** **200** and plaintext. B never talked to Vault; it decrypted from RAM.

5. **Re-ingest on B** — new idempotency key, same `$USER`.

```bash
curl -sS -D - -X POST "$B/v1/events" \
  -H "Authorization: Bearer $WRITER" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: qa-$(date +%s)-b" \
  -d "$(event_json run-qa-replica-2)"
```

**Pass:** **410** `"error": "subject_erased"`. B sees the same Redis set A wrote.

A load balancer in front of both ports is not required. Hitting `:8081` vs `:8082` is enough.

## 9. Auth negatives

| Call | Token | Expected |
| --- | --- | --- |
| `POST /v1/erasures` | `$WRITER` | **403** (`company_admin` only) |
| `POST /v1/events` | `$ADMIN` | **403** (no `writer` on this user) |
| Any `/v1/...` | no `Authorization` | **401** |

## Out of scope for this build

- Un-forget / “the person comes back” — not shipped. Ingest 410 is **permanent** until [JIRA Tasks](JIRA%20Tasks.md) Task 1.
- `cache_purged` on the attestation — do not treat it as “sibling RAM is empty.” The guarantee is the door fence (Task 2).
- Core `GET /events/{id}` on `:8000` — hashes stay; that is not a fail.
- Company / tenant graveyard — not this feature.

## Sign-off

- [ ] Fresh user: ingest 202, read 200, verify `match`
- [ ] Preview does not destroy
- [ ] Erase 200; re-POST keeps original timestamps
- [ ] Old record: GET 410 `erased`; verify `result: erased` + `event_root`
- [ ] Same `user_id`, new idempotency key: ingest **410 `subject_erased`**
- [ ] Different `user_id`: ingest still 202
- [ ] Raw `user_id` never in erase/ledger responses
- [ ] Writer cannot erase (403); admin cannot ingest (403)
- [ ] Two replicas: warm B, erase on A, GET on B is 410 `erased` (not 200 plaintext); re-ingest on B is 410 `subject_erased`

## Related pages

- [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md) — implementer how-to
- [Write the Un-forget](Write%20the%20Un-forget.md) — Task 1 how-to (after the landing)
- [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- [ADR-0003 Landing Review Findings](ADR-0003%20Landing%20Review%20Findings.md)
- [JIRA Tasks](JIRA%20Tasks.md)
- [New Developer Onboarding](New%20Developer%20Onboarding.md) — local start
- [Core and Sidecar](Core%20and%20Sidecar.md)
- [Wiki Index](Inveniam%20Indicia%20(INV-42236)/wiki/index.md)
- [Decision register](../decisions/INDEX.md)
