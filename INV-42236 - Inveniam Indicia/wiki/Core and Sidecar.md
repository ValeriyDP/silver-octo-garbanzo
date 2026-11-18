---
name: Core and Sidecar
date: 2026-09-02T08:01:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - architecture
---

# Core and Sidecar

**Summary**: Two processes, two ports, two databases. They look independent and mostly are. The only runtime coupling on the write path is one HTTP POST of a hash-only envelope, using the caller’s FusionAuth JWT.

**Sources**: `cmd/api`; `cmd/sidecar`; `internal/sidecar/coreclient/client.go`; `internal/api/router.go`; `docs/api/ARCHITECTURE.md`; `docs/guides/ENVIRONMENT_VARIABLES.md`; local `Taskfile.yml`.

**Last updated**: 2026-09-02 (PlantUML: activations + responses)

---

Render the diagrams with the Obsidian PlantUML plugin or https://www.plantuml.com/plantuml.

## Topology

```plantuml
@startuml CoreSidecar-Topology
skinparam monochrome true
title Core and sidecar -- local topology

actor Producer
rectangle "FusionAuth\n:9011" as FA
rectangle "Sidecar\n:8081" as SC
rectangle "Core\n:8000" as Core
database "indicia_sidecar\n(ciphertext + wrapped DEK)" as SDB
database "indicia\n(core index)" as CDB
database "immudb\n(proofs)" as Imm
database "Vault -dev\n:8200 Transit" as Vault
database "Redis\n:6379" as Redis

Producer --> SC : POST /v1/events\nfull JSON + JWT
SC --> Producer : 202 record_id, event_id, event_root
Producer --> Core : POST /events\n(hash-only BYO / push:event:core)
Core --> Producer : 202 event_id, event_hash
SC --> FA : JWKS validate
FA --> SC : 200 keys / valid
Core --> FA : JWKS validate
FA --> Core : 200 keys / valid
SC --> Vault : wrap / unwrap DEK
Vault --> SC : wrapped DEK / plaintext DEK
SC --> SDB : INSERT ciphertext
SDB --> SC : OK
SC --> Core : POST /events\nhash-only + caller JWT
Core --> SC : 202 event_id
SC --> Redis : idempotency SET
Redis --> SC : OK / replay
Core --> Redis : XADD events:stream
Redis --> Core : message id
Core --> CDB : index (async worker)
CDB --> Core : OK
Core --> Imm : append proof (async worker)
Imm --> Core : OK
@enduml
```

Core never calls the sidecar. Core never talks to Vault. The dashed-looking independence is real for storage; the write path is one HTTP hop.

## Local URLs

| | Core (`cmd/api`) | Sidecar (`cmd/sidecar`) |
| --- | --- | --- |
| Listen | `:8000` | `:8081` (`INDICIA_SIDECAR_LISTEN_ADDR`) |
| Health | `GET /health` | `GET /health` |
| Ingest | `POST /events` — hash-only envelope | `POST /v1/events` — full JSON |
| Verify / read | `GET /events/:id/verify` (hashes, never content) | `GET /v1/events/:id`, `…/verify` (content) |

`task push:event` hits `:8081`. `task push:event:core` hits `:8000`. How to start both: [New Developer Onboarding](New%20Developer%20Onboarding.md) §7.

## The one hop

After classify / pseudonym / seal / store, the sidecar’s `coreclient` does:

`POST {INDICIA_SIDECAR_CORE_URL}/events` → locally `http://localhost:8000/events`

It forwards the **caller’s** `Authorization` header. It does **not** mint a sidecar service token, and it does **not** forward `Idempotency-Key` (the core keys idempotency on tenant+key without hashing the body; a forwarded key would stamp the wrong event id) (source: `internal/sidecar/coreclient/client.go`).

That is the only sidecar → core call. The core never calls the sidecar. The core never talks to Vault.

This sequence stops at `202`. It does not show a second replica, a tenant destroy loop, or cache broadcast. That missing slice is [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md) diagram 2.

```plantuml
@startuml CoreSidecar-Ingest
skinparam monochrome true
skinparam responseMessageBelowArrow true
autonumber
title Ingest -- managed path (sidecar). Bars = work started / ended.

actor Producer
participant "FusionAuth :9011" as FA
participant "Sidecar :8081" as SC
participant "Vault Transit" as V
database "sidecar Postgres" as SDB
database "Redis" as R
participant "Core :8000" as Core

== start request ==
Producer -> SC : POST /v1/events\nAuthorization: Bearer <JWT>\nIdempotency-Key: ...\nfull JSON
activate SC

SC -> FA : validate JWT (JWKS)
activate FA
FA --> SC : 200 valid\nroles, company_id
deactivate FA

SC -> R : GET idempotency key
activate R
R --> SC : miss (or cached 202 replay)
deactivate R

SC -> SC : schema + classify\npseudonym tier-2
activate SC #LightGrey
deactivate SC

SC -> V : EnsureSubjectKey\nwrap DEK
activate V
V --> SC : 200 wrapped DEK
deactivate V

SC -> SDB : INSERT ciphertext\n+ wrapped DEK
activate SDB
SDB --> SC : OK
deactivate SDB

SC -> Core : POST /events\nAuthorization: same Bearer\nhash-only envelope\n(no Idempotency-Key)
activate Core

Core -> FA : validate JWT (JWKS)
activate FA
FA --> Core : 200 valid\nwriter + company_id
deactivate FA

Core -> Core : registry membership\nrecompute event_root
activate Core #LightGrey
deactivate Core

Core -> R : XADD events:stream
activate R
R --> Core : message id
deactivate R

Core --> SC : 202 Accepted\n{event_id, event_hash,\nanchor_status: pending}
deactivate Core

SC -> R : SET idempotency 202
activate R
R --> SC : OK
deactivate R

SC --> Producer : 202 Accepted\n{record_id, event_id, event_root}
deactivate SC
== end request ==

note over Core
  immudb + core Postgres writes
  start later in workers.
  They are not in this HTTP response.
end note
@enduml
```

## What they do not share

- **Postgres.** Core index vs sidecar **record store** (`INDICIA_SIDECAR_RECORD_STORE_DSN` must not be the core DB; Taskfile uses `indicia_sidecar`).
- **Vault.** Sidecar-only (`INDICIA_KEYVAULT_*`). Core has no `INDICIA_KEYVAULT_*` and starts without it.
- **Content.** Core never receives plaintext.

## What they share, independently

- **FusionAuth** — each process validates the same JWT (JWKS). Sharing the IdP is intended; see [BYO Producer](BYO%20Producer.md) for what that does *not* mean for a customer hasher.
- **Redis** — same local instance in the Taskfile, different jobs: core worker streams vs sidecar ingest idempotency. The sidecar **refuses to start** without `INDICIA_SIDECAR_REDIS_ADDR`.

## Verify is not a sidecar→core call

No endpoint returns `verified`. The caller hits core `/verify` and sidecar `GET /v1/events/:id/verify` and joins on `event_root` (source: D2 / `VERIFICATION_RECIPE.md`).

```plantuml
@startuml CoreSidecar-Verify
skinparam monochrome true
skinparam responseMessageBelowArrow true
autonumber
title Verify -- two HTTP calls the caller starts and ends. No sidecar-to-core hop.

actor Caller
participant "FusionAuth :9011" as FA
participant "Core :8000" as Core
database "immudb / core index" as Proof
participant "Sidecar :8081" as SC
database "sidecar Postgres" as SDB
participant "Vault Transit" as V

== start core verify ==
Caller -> Core : GET /events/:id/verify\nAuthorization: Bearer <JWT>
activate Core

Core -> FA : validate JWT (JWKS)
activate FA
FA --> Core : 200 valid
deactivate FA

Core -> Proof : read event + anchor
activate Proof
Proof --> Core : hashes, event_root, status
deactivate Proof

Core --> Caller : 200 OK\n{status, hashes, event_root}
deactivate Core
== end core verify ==

== start sidecar verify ==
Caller -> SC : GET /v1/events/:id/verify\nAuthorization: Bearer <JWT>
activate SC

SC -> FA : validate JWT (JWKS)
activate FA
FA --> SC : 200 valid\nreader + company_id
deactivate FA

SC -> SDB : SELECT ciphertext\n+ wrapped DEK
activate SDB
SDB --> SC : row (or empty)
deactivate SDB

alt record held
  SC -> V : unwrap DEK
  activate V
  V --> SC : plaintext DEK\n(or key destroyed)
  deactivate V
  SC -> SC : open blob, re-hash,\nrefold event_root
  activate SC #LightGrey
  deactivate SC
end

SC --> Caller : 200 OK\n{result, event_root,\nrecomputed_root, reason}
deactivate SC
== end sidecar verify ==

== start join (caller) ==
Caller -> Caller : assert\ncore.event_root\n== sidecar.recomputed_root
activate Caller
Caller --> Caller : verified /\nintegrity-only /\nmismatch
deactivate Caller
== end join ==

note over Caller
  Both verifies return 200 even when
  result is erased / not_held / mismatch.
  That is an answer, not an HTTP failure.
end note
@enduml
```

## Local Vault `-dev`

`task vault:up` is `vault server -dev` on `127.0.0.1:8200`, Transit enabled, token pinned to `root`, env in `.data/vault-dev.env`. It comes up **already unsealed** (not the same thing as production KMS auto-unseal). Storage is in-memory: restart wipes every Transit key. Ciphertext rows stay; they cannot be opened. Core hash-only proofs are unaffected.

Production keys Vault auto-unseals via a cloud KMS DevOps owns. Restart there keeps Transit keys (source: `KEYVAULT_KEY_STORE_STORAGE_REQUIREMENTS.md`).

## Related pages

- [New Developer Onboarding](New%20Developer%20Onboarding.md)
- [BYO Producer](BYO%20Producer.md)
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md)
- [ADR-0001 Acknowledged Sidecar Cache Purge](../decisions/ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md)
- [TOCTOU](TOCTOU.md)
- [Open Questions](INV-42236%20-%20Inveniam%20Indicia/wiki/Open%20Questions.md)
- [Wiki Index](INV-42236%20-%20Inveniam%20Indicia/wiki/index.md)
