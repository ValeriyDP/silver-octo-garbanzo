---
name: BYO Producer
date: 2026-09-02T08:01:00.000Z
tags:
  - inveniam-indicia
  - inv-42236
  - wiki
  - architecture
---

# BYO Producer

**Summary**: A customer who hashes and classifies themselves posts **hash-only** envelopes at the core. There is no second ingest door, no JS/Python SDK, and no auth mechanism other than a FusionAuth-issued `writer` JWT. “BYO producers later” is a documented credential class, not a shipped provisioner.

**Sources**: `SEPARATION_OF_CONCERNS_SPEC.md` §3.6 / §4; `SEPARATION_OF_CONCERNS_CONTENT_SIDECAR_DESIGN.md`; `API_SPECIFICATION.md`; `DECISION_SET_2026-08-10_VERIFY_ERASURE_RBAC.md` D5d; `docs/devops/SECURITY.md` (credential classes); `FUSIONAUTH_INTEGRATION.md` open questions; `pkg/canonical`; `pkg/eventtypes`.

**Last updated**: 2026-09-02

---

## Three postures (what sits *upstream* of `POST /events`)

| Posture | Who hashes / stores content | Who calls the core |
| ------- | --------------------------- | ------------------ |
| **Managed** | Our sidecar | Sidecar, forwarding the caller JWT |
| **Self-hosted** | Our sidecar, on their metal | Same sidecar → hash-only door |
| **Hash-only / BYO** | Their code, their store | Their hasher → `POST /events` directly |

The door’s guarantee depends on that upstream. Our sidecar + our core is a trust boundary inside one product. A customer Python script on the same door is a weaker claim: no erasure from us, no preimage check, self-classification we cannot verify (source: D-set §3 / `API_SPECIFICATION.md`).

## How ingest works for BYO

Same door as the sidecar’s forward: `POST /events` with a `canonical.HashOnlyEnvelope`. Core recomputes `event_root` from the tier maps, gates registry **membership**, never sees plaintext (source: `ARCHITECTURE.md` §1, `internal/core/hashonly.go`).

Process split does not mean a private sidecar↔core channel. See [Core and Sidecar](Core%20and%20Sidecar.md).

## Auth — FusionAuth is the IdP, not a shared secret

Core and our sidecar both validate JWTs from FusionAuth. That is fine and intended.

A customer hasher does **not** get a different protocol. They must present a **writer** JWT that a FusionAuth the **core already trusts** issued (ours, or an enterprise FusionAuth we point `INDICIA_FUSIONAUTH_URL` / JWKS at).

Designed class (D5d, `SECURITY.md`):

- Humans on the core are admin-tier (`company_admin`, `global_admin` / `operator`). A person does not hold `writer`.
- `writer` is a **machine identity**: “sidecar service account today; BYO producers later.”
- Admin tier provisions the account: `roles: [writer]`, `company_id` = that tenant.
- Hasher obtains a token, then `POST /events`. Core: valid JWT → `RequireWriter` → JWT `company_id` equals envelope `company_id`.

`writer` does not imply `reader` (D5b). A leaked producer token can append, not read back.

They do not run our FusionAuth cluster and do not receive our root token. They receive **one provisioned machine user** (or tokens from an enterprise FusionAuth we already validate).

## What is not built

| Gap | Evidence |
| --- | -------- |
| API keys / FusionAuth Application (M2M) | Open question in `FUSIONAUTH_INTEGRATION.md` (“should we support API keys?”). |
| Customer IdP we have never configured | No code path. Core validates one JWKS. |
| Sidecar **service account** D5d names | Today the sidecar **forwards the caller’s JWT** (`coreclient.PostEnvelope`). No sidecar-minted token. |
| Provisioning UX for “BYO producers later” | Documented class only. Identity/SSO handoff text still says “contact DevOps to add a FusionAuth user.” |

If the client will not take a FusionAuth-issued writer token, **there is no implemented ingest.** The hash-only door is ready; the credential is not a shipped product.

Parked as [Open Questions](Inveniam%20Indicia%20(INV-42236)/wiki/Open%20Questions.md) #3 and #4.

## Hashing — Go only

We do not ship JS, Python, or other language libraries.

| What exists | Role |
| ----------- | ---- |
| Go `pkg/canonical` | Encoding, leaves, `event_root`. Core, sidecar, and a hypothetical BYO client are all supposed to import this package (source: `pkg/canonical/doc.go`). |
| Go `pkg/eventtypes` | YAML registry / classification the sidecar uses. |
| `pkg/canonical/testdata/vectors.json` | Conformance vectors. A third-party hasher must match byte-for-byte. |

“Self-hosted packaging + BYO toolkit” is a later slice in the SoC spec. Not built. A customer may reimplement the published contract and pass the vectors; that is not a supported SDK.

Local fixtures that exercise the **core** writer path (not a BYO SDK): `producer@test.local` / `writer` / `dev-company` in FusionAuth kickstart; `task push:event:core` uses `scripts/send-event` + `pkg/canonical`.

## Related pages

- [Core and Sidecar](Core%20and%20Sidecar.md)
- [New Developer Onboarding](New%20Developer%20Onboarding.md)
- [Open Questions](Inveniam%20Indicia%20(INV-42236)/wiki/Open%20Questions.md)
- [Repository Docs](Repository%20Docs.md)
- [Wiki Index](Inveniam%20Indicia%20(INV-42236)/wiki/index.md)
- [Decision register](../decisions/INDEX.md)
