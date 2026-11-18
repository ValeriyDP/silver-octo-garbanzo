---
name: New Developer Onboarding
date: 2026-09-02T06:43:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - guide
---

# New Developer Onboarding

**Summary**: Cold start for a developer joining the erasure / Slice 2c thread. What the product is, how one event and one erasure work, which slice you are standing in, and what every abbreviation in this conversation means.

**Sources**: `HANDOFF_2026-08-17_initial-import-team-onboarding.md`; `SEPARATION_OF_CONCERNS_SPEC.md` §2–§3; `CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md`; `SEPARATION_OF_CONCERNS_SLICE_2B_RECORD_STORE.md` §3; `DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md` D3, D5; `api/ARCHITECTURE.md`.

**Last updated**: 2026-09-02 (vocabulary: quiesce–shred–invalidate-ack)

---

You do not need the whole 55-doc tree on day one. You need the split (proof vs content), the people units (tenant / subject / event), and why “forget this customer” is not an API yet. Deep dive after this page: [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md) and [TOCTOU](TOCTOU.md). How the two processes talk, and what a customer hasher actually gets: [Core and Sidecar](Core%20and%20Sidecar.md), [BYO Producer](BYO%20Producer.md).

## 1. What this product is

**Inveniam Indicia** proves that an AI agent did a specific thing, at a specific time, unaltered — and can still **forget a person** when the law requires it (source: `CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md`).

Those two jobs fight each other. A blockchain (immutable ledger) cannot delete. GDPR Article 17 says a person can demand deletion. If personal data ever lands on the chain, we are non-compliant by construction.

The product’s answer is a hard split (source: `SEPARATION_OF_CONCERNS_SPEC.md` §2):

| Stream | What it is | Where it lives | Can we erase it? |
| ------ | ---------- | -------------- | ---------------- |
| **Proof** | Fingerprints (hashes) + a few non-personal labels | **Core** (`cmd/api`) → immudb → Hub → chain | No, and we must not need to |
| **Content** | Readable prompts, outputs, anything about a person | **Sidecar** (`cmd/sidecar`), stored **encrypted** | Yes — destroy the person’s key |

One sentence: the immutable part holds only unlinkable fingerprints; the readable part is encrypted noise once the key is gone (source: explainer §2).

This investigation folder is **INV-42236**. The application repo is `trace-chain/InveniamIndicia`. Repo docs stay in the repo; query them with `-c inveniam-indicia-docs` (see [Repository Docs](Repository%20Docs.md)).

## 2. The cast of characters

| Word         | Meaning                                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------- |
| **Tenant**   | A customer company. ID is `company_id`. Offboarding means “this customer is gone.”                                          |
| **Subject**  | One person (data subject) inside a tenant. In payloads this is `user_id`. GDPR erasure is usually “forget this one person.” |
| **Event**    | One logged agent action (a run, a step). Encrypted under a per-event key that hangs off the subject’s key.                  |
| **Producer** | Whoever POSTs events — our sidecar, or a customer’s own client (BYO).                                                       |
| **Replica**  | A second running copy of the sidecar behind a load balancer. Two processes, two in-memory caches.                           |

Erasure granularities the system must support (source: SoC spec §3.2):

- **Per-subject** — forget one person, leave everyone else and all proofs intact. **Shipped.**
- **Per-tenant** — offboard the whole customer. **Library exists, no HTTP door.** That is Slice 2c.

There is no “erase one event” door. One subject key is reused across that person’s events (source: D3d).

## 3. How one event gets in (so erasure has something to destroy)

A producer sends a **full** JSON event to the sidecar (`POST /v1/events`). The sidecar (source: Slice 2b spec §2):

1. Authenticates the JWT (FusionAuth roles).
2. Classifies every field into **tier 1 / 2 / 3** (table below).
3. Replaces tier-2 IDs with an HMAC **pseudonym** (same input → same token, so joins still work; only we hold the key).
4. Mixes a random **salt** into every tier-3 field and hashes it — so a low-entropy value like `country=US` cannot be brute-forced off the chain.
5. Builds `event_root` — one Merkle-style fingerprint of the whole envelope.
6. **Seals** the readable content: encrypt under a per-event **DEK**, wrap that DEK with the subject’s Vault Transit key, store ciphertext + wrapped DEK in the sidecar’s Postgres (**record store**).
7. Forwards a **hash-only envelope** (no content) to the core’s `POST /events`.
8. Core writes the proof to immudb, batches events into a Merkle tree, anchors the batch root on chain via the Hub.

After that, the chain has a fingerprint. The sidecar has ciphertext. Nobody has plaintext except by asking Vault to unwrap the DEK.

### Tiers (the classification you will keep seeing)

| Tier | Everyday meaning | What the core stores | Erasable? |
| ---- | ---------------- | -------------------- | --------- |
| **1** | Opaque locators: tenant id, event id, timestamps | **Plaintext** | n/a — must not be personal |
| **2** | Quasi-IDs we must operate on: `user_id`, coarse region | **HMAC pseudonym** | Yes — shred the HMAC key |
| **3** | Content: prompt, output, free text, fine location | **Salted hash only** (content never in core) | Yes — shred the subject key + salt lives with the ciphertext |

Classification answers *must this vanish when the person is erased?* not *is this useful for BI?* (source: SoC spec §3.1).

## 4. How we “delete” without deleting

We do not chase rows through backups. We **crypto-shred**: content is always encrypted; erasure **destroys the key**. Ciphertext in the live DB and in every backup becomes permanent noise. The on-chain hash stays (proof still works) but cannot be linked back once salt + key are gone (source: explainer §4).

Shipped door (per-subject, D3):

- `POST /v1/erasures/preview` — dry run: how many records, first/last seen.
- `POST /v1/erasures` — destroy that subject’s Transit key, purge **this process’s** caches, write a row to the **erasure ledger**.
- `GET /v1/erasures` — the tenant-readable attestation they can show a regulator.

Gate: `company_admin` of **that** tenant only. Inveniam staff (`global_admin` / `operator`) have **no read** on sidecar plaintext (source: D3a, D5c).

The ledger row is the **tombstone** / attestation: tenant, `subject_pseudonym`, timestamps, `cache_purged`. Ciphertext rows are **kept** (deleting them would also delete the ability to prove “this fingerprint was real”). They just cannot be opened.

**Not shipped:** “forget this whole tenant.” `OffboardTenant` (disable keys — reversible inertness) and `PurgeTenant` (destroy keys — irreversible) exist in the keyvault library and in tests. No production caller. That HTTP surface is Slice 2c, and it is unsafe until writes for that tenant can be frozen for the length of the call ([TOCTOU](TOCTOU.md)).

## 5. Where you are in the slice story

Think of “Separation of Concerns” as a programme, not one PR.

| Slice | Job | Status |
| ----- | --- | ------ |
| **1** | Hash-only core. Core never sees content. | Landed |
| **2a** | Keyvault **library**: seal/open, `EraseSubject`, `OffboardTenant`, `PurgeTenant`. Nothing called it yet. | Landed |
| **2b** | Sidecar service + record store + full-data door. Made 2a load-bearing. Per-subject erasure **pulled forward** out of 2c (D3). | Landed |
| **2c** | Tenant offboard/purge door + write quiesce + Redis pub/sub so **every replica** drops caches + erasure runbook. | **Unbuilt. Launch-gating.** |
| **2d / 2e** | BI projection; mode-aware resolver. | Later |

2c is two problems that must ship together (source: handoff §4):

1. **A safe whole-tenant door** — freeze writes, then disable/destroy every subject key. Without the freeze, a new ingest mid-loop creates a subject the loop never saw ([TOCTOU](TOCTOU.md)).
2. **Cross-replica cache invalidation** — Vault key destruction is global; in-memory **DEK** and **pseudonym** caches are per process. Today `BroadcastPurge` is a `NoopInvalidator`. After erase on replica A, replica B can still decrypt. The attestation already said `cache_purged: true`. That is why 2c is launch-gating **even if nobody offboards a tenant**: subject erase is already live.

Three assessment findings stay dormant only because `OffboardTenant` / `PurgeTenant` have no caller. The first PR that wires the door must close them. Details: [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md).

## 6. Vocabulary

Grouped by the conversation, not alphabetically. Repo paths and type names stay in English.

### Product and ticket

| Term | Means |
| ---- | ----- |
| **Inveniam Indicia** | This product: hash-only anchoring core + encrypted content sidecar. |
| **INV-42236** | The investigation ticket for this wiki. |
| **SoC** | Separation of Concerns — the programme that split proof from content. |
| **Slice 1 / 2a / 2b / 2c** | Numbered delivery slices of SoC. Not git branches. |
| **Core** | `cmd/api`. Holds proofs only. `POST /events` is hash-only. |
| **Sidecar** | `cmd/sidecar`. Accepts full events, encrypts content, forwards hashes to the core. |
| **Producer** | Client that emits events (sidecar, or BYO). |
| **BYO** | Bring Your Own — customer hosts the content store / keys / verifier themselves. Different guarantee profile than managed. |
| **PA agent** | Policy Alignment agent in the `inveniam.io` repo. Still emits retired `pa_agent.*` types; not this repo. |
| **Hub** | Inveniam Hub. Core posts batch roots here; Hub submits the chain transaction. |
| **NVNM** | Inveniam’s chain / testnet the Hub anchors to. |
| **BI** | Business intelligence. Planned projection of decryptable content for the tenant; slice 2d. Not built. |

### People, auth, API

| Term | Means |
| ---- | ----- |
| **Tenant / `company_id`** | Customer organisation. |
| **Subject / `user_id` / data subject** | One person the GDPR cares about. |
| **JWT** | JSON Web Token. FusionAuth issues it; middleware reads roles + `company_id`. |
| **FusionAuth** | Identity provider. Roles live here. |
| **RBAC** | Role-based access control. Five roles (D5): `reader`, `writer`, `company_admin`, `global_admin`, `operator`. Legacy `admin` was deleted. |
| **`company_admin`** | Customer admin. Only role that may erase, and only in their tenant. |
| **`global_admin` / `operator`** | Inveniam staff. Lifecycle / ops. **No read of sidecar plaintext.** |
| **Door** | An HTTP API surface (ingest door, erasure door, offboard door). |
| **Attestation** | The signed-in-practice statement we return after shred: “this subject is gone, cache purged, completion by date.” Stored as an erasure-ledger row. |
| **Erasure ledger** | Postgres table of per-subject shreds. Tombstone + regulator artifact. Pseudonyms only. |
| **Tombstone** | Durable “this subject was erased” marker. Reads consult it; ingest today does **not** (that gap is `internal-keyvault-3`). |

### Crypto and erasure

| Term | Means |
| ---- | ----- |
| **PII** | Personally identifiable information. Must not live on the immutable core. |
| **GDPR Art. 17** | Right to erasure (“delete my data”). Primary design driver. |
| **Hash / fingerprint** | One-way digest. Cannot be reversed if the input has enough entropy (or is salted). |
| **Salt** | Random bytes mixed into a tier-3 field before hashing. Stored with the ciphertext, never on chain. |
| **HMAC** | Keyed hash. Tier-2 pseudonyms: `HMAC(tenant_key, raw_id)`. Deterministic so we can still join. |
| **Pseudonym** | The HMAC token the core sees instead of `user_id`. |
| **Crypto-shred** | Erase by destroying the encryption key, not by deleting ciphertext rows. |
| **Envelope encryption** | Content key wrapped by a higher key. Here: per-event DEK wrapped by per-subject Transit key. |
| **DEK** | Data-encryption key. One per event (AES-256-GCM). Wrapped blob sits next to the ciphertext. |
| **KEK** | Key-encryption key. Older docs talk about a tenant master KEK; Fork A uses **one Vault Transit key per subject** instead of a billed cloud-KMS key per person. |
| **Seal / Open** | Encrypt content (`SealEvent`) / decrypt it (`OpenEvent`). |
| **`event_root`** | Fingerprint of the whole hash-only envelope. Join key between core verify and sidecar verify. |
| **Merkle / batch / anchor** | Core groups event roots into a tree; the tree root is written on chain. Proof = “this event is in that tree, that tree is on chain.” |
| **Vault / Transit** | HashiCorp Vault’s Transit secrets engine. Subject keys live here and never leave. Destroy = shred. |
| **HSM** | Hardware security module. Real key destruction can take days; offboard is “disable now,” purge is “destroy on a schedule.” |
| **Fork A** | The locked keyvault design: dedicated Vault Transit, one key per subject, Raft snapshots ≤7 days = the erasure window. Replaced an earlier “cloud KMS + no Vault” sketch. |
| **Offboard** | Disable every subject key for a tenant. Instant, reversible inertness. |
| **Purge** | Destroy those keys. Irreversible. |
| **Erase / shred** | Per-subject crypto-shred (the shipped door). |
| **`cache_purged`** | Field on the attestation. Today it means “this process dropped its cache,” not “every replica did.” |
| **NoopInvalidator** | Current `BroadcastPurge` implementation: does nothing. Planned replacement: Redis pub/sub (2c). |
| **Write quiesce** | Stop all writes for a tenant for the duration of offboard/purge so no new subject appears mid-loop. |
| **Quiesce–shred–invalidate-ack** | Early name for 2c ( [ADR-0001](../decisions/ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md), superseded). Current contract: [ADR-0003](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md) — Postgres graveyard, then Redis `SADD`; list before cache. |
| **TOCTOU** | Time-Of-Check to Time-Of-Use. See [TOCTOU](TOCTOU.md). |
| **Replica / HA** | High availability: more than one sidecar process. Makes local-only cache purge a lie. |

### Storage and infra

| Term | Means |
| ---- | ----- |
| **immudb** | Append-only ledger DB. Core’s source of truth for proofs. You cannot delete from it — so no content, no keys. |
| **Postgres** | Mutable SQL. Core uses it as an index; sidecar’s **record store** holds ciphertext + wrapped DEKs + the erasure ledger. |
| **Redis** | Streams for the core’s workers today. 2c will also use **pub/sub** to tell every replica “drop this cache.” |
| **Record store** | Sidecar’s own Postgres (own DSN, own migrations). Not the core’s DB. |
| **Raft snapshot** | Vault’s backup mechanism. Short retention (≤7 days) is the remaining window where a shredded key could theoretically be restored. |

### Process, decisions, findings

| Term | Means |
| ---- | ----- |
| **D3 / D3d / D13…** | Numbered rulings in `DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md`. **Canonical over design docs.** D3 = erasure door; D3d = subject-only for now. |
| **U1, U7…** | Implementation units (work packages) that execute those D-numbers. Historical; many landed pre-import. |
| **ADR** | Architecture Decision Record. In *this* wiki: `decisions/`. The repo’s living decisions are the D-set, not our ADR folder (still empty). |
| **Launch-gating** | Must land before a real multi-replica / customer launch. D13 and Slice 2c. |
| **Latent finding** | A confirmed bug that is inert only because the dangerous function has no caller. Wiring the caller without the fix makes it live. |
| **`internal-keyvault-1`** | Tenant-offboard TOCTOU. |
| **`internal-sidecar-1`** | Pseudonym-secret cache never invalidated until restart. |
| **`internal-keyvault-2` / DATA-PROTECTION-001** | Sibling replica still decrypts after erase; `cache_purged: true` is then false. |
| **`internal-keyvault-3` / DATA-PROTECTION-002** | Ingest after erase can mint a **new** subject key. Old data stays shredded; erasure *state* is inconsistent. Already reachable. |
| **qmd** | Local search over this wiki (`inveniam-indicia`), repo docs (`inveniam-indicia-docs`), and Go (`inveniam-indicia-code`). |

### Verify (you will hit this next to erasure)

| Term | Means |
| ---- | ----- |
| **`integrity-only`** | Core’s ceiling: “this hash is what I stored and the chain agrees.” Core cannot speak about content. |
| **`verified`** | **Caller-derived.** You call core `/verify` and sidecar verify, join on `event_root`. No endpoint returns `verified`. |
| **`erased` vs `not_held`** | Sidecar: lawful shred vs “this store never had it.” Both are benign absence, not tampering. |

## 7. How to start locally (`Taskfile.yml`)

Work from the application repo: `trace-chain/InveniamIndicia`. Install the runner once: `brew install go-task`. Then `task` lists every target. Makefile steps in `docs/guides/GETTING_STARTED.md` still work; the Taskfile is the wrapper you should use (same idea as TraceChainAPI).

`start:api`, `start:api:static`, and `start:sidecar` run under **Air** (`air-verse/air`). Saving a `.go` / `.yml` / `.yaml` file rebuilds and restarts that process. Postgres, Redis, immudb, FusionAuth, and vault `-dev` stay up. `task run` is still a one-shot `go run` with no watcher.

**Core only** (hash-only door, no Vault, no sidecar):

```bash
task start:api:static
curl http://localhost:8000/health
task push:event:core          # stub hash-only POST (make send-event)
```

**Slice 2c / sidecar** (full-data door, FusionAuth JWT, Vault Transit). The shipped sidecar has no static-auth path, so do not use `start:api:static` here.

```bash
task start:api                # postgres + redis + immudb + vault -dev + FusionAuth + core :8000
# other terminal:
task start:sidecar            # sidecar DB + cmd/sidecar on :8081
curl http://localhost:8081/health
task push:event               # faker full-data POST (seals under Vault, forwards hashes to core)
```

`task start:api` already runs `vault:up`. You can also start Vault alone with `task vault:up`. `task up` is deps only (postgres + redis + immudb + vault -dev), no API process.

| Task | What it starts |
| ---- | -------------- |
| `task deps` | Check Go, Docker, immudb, vault CLI, `.env`, modules |
| `task up` | Postgres + Redis + native immudb + `vault server -dev` |
| `task up:full` | `up` + FusionAuth |
| `task start:api:static` | `up` + migrate + core with static auth |
| `task start:api` | `up:full` + migrate + core with FusionAuth |
| `task start:sidecar` | Vault + `indicia_sidecar` DB + sidecar on `:8081` (needs core + FusionAuth already up) |
| `task push:event` | Faker **full-data** event to the sidecar (hits Vault) |
| `task push:event:core` | Hash-only event to the core (no Vault) |
| `task vault:up` / `vault:down` | Dev keys Vault on `127.0.0.1:8200`, Transit enabled, env in `.data/vault-dev.env` |
| `task db:reset` | Recreate empty core Postgres (dirty migrations) |
| `task down` | Docker + immudb + the vault -dev **this Taskfile started** |

`vault server -dev` is in-memory and comes up **already unsealed**. A restart (or `vault:down` then `vault:up`) wipes every Transit key. Sidecar ciphertext rows stay, but they cannot be opened. The token is pinned to `root` so ADDR/TOKEN stay stable; **keys still vanish**. Core hash-only proofs are unaffected.

Stop the API with `lsof -ti:8000 | xargs kill`, the sidecar with `lsof -ti:8081 | xargs kill`. Do not `pkill -f exe/main` — that matches both binaries.

## 8. What to read next (in order)

1. This page, then [Core and Sidecar](Core%20and%20Sidecar.md), [BYO Producer](BYO%20Producer.md), then [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md), then [TOCTOU](TOCTOU.md). Person-erase fence how-to: [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md).
2. Repo: `docs/handoffs/HANDOFF_2026-08-17_initial-import-team-onboarding.md` §1 and §4.
3. `docs/plans/CRYPTO_SHRED_COMPLIANCE_EXPLAINER.md` (why keys ≠ content backups).
4. `docs/api/ARCHITECTURE.md` (pipeline diagram) and `docs/api/API_SPECIFICATION.md` § erasure door.
5. Decision set D3 and D5 only, until you need another D-number.
6. Code, when you implement: `internal/keyvault/keyvault.go` (`OffboardTenant`, `PurgeTenant`, `NoopInvalidator`), `internal/sidecar/http/erasure.go`, `internal/sidecar/pseudonym/pseudonym.go`. Use `-c inveniam-indicia-code` as a path finder, then read 1–2 files.

## Related pages

- [Core and Sidecar](Core%20and%20Sidecar.md)
- [BYO Producer](BYO%20Producer.md)
- [Slice 2c Tenant Offboard](Slice%202c%20Tenant%20Offboard.md)
- [TOCTOU](TOCTOU.md)
- [Write the Person Graveyard](Write%20the%20Person%20Graveyard.md)
- [Repository Docs](Repository%20Docs.md)
- [Open Questions](Inveniam%20Indicia%20(INV-42236)/wiki/Open%20Questions.md)
- [Wiki Index](Inveniam%20Indicia%20(INV-42236)/wiki/index.md)
- [ADR-0003 Shared Redis Forget Set](../decisions/ADR-0003%20Shared%20Redis%20Forget%20Set.md)
- [ADR-0002 Forget Table Before Cache](../decisions/ADR-0002%20Forget%20Table%20Before%20Cache.md)
- [ADR-0001 Acknowledged Sidecar Cache Purge](../decisions/ADR-0001%20Acknowledged%20Sidecar%20Cache%20Purge.md)
- [Decision register](../decisions/INDEX.md)
