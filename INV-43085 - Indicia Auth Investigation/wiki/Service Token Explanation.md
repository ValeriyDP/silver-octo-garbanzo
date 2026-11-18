---
name: Service Token Explanation
date: 2026-10-13T09:50:00.000Z
tags:
  - indicia
  - inv-43085-auth-investigation
  - wiki
  - architecture
---

# Service Token Explanation

**Summary**: Why a producer key pair and a FusionAuth service account were both examined, and why the change is postponed. The shipped path stays the forwarded user JWT in [Current Auth Flow](Current%20Auth%20Flow.md).

**Sources**: `internal/auth/fusionauth_jwt.go`, `internal/api/handlers/users.go`, `internal/sidecar/coreclient/client.go`, `docker/fusionauth-kickstart/kickstart.json`, `docker-compose.yml`, `docs/plans/SEPARATION_OF_CONCERNS_SLICE_2B_RECORD_STORE.md` §4.5, FusionAuth access-token and machine-to-machine documentation. Design detail: [ADR-0001 Service Tokens for Ingest](ADR-0001%20Service%20Tokens%20for%20Ingest.md).

**Last updated**: 2026-10-13

---

## What we thought to do

A producer should call the sidecar without a FusionAuth user password on every request. Two ways were on the table.

The first was a key pair held outside FusionAuth. The producer would mint the JWT. The sidecar and the core would verify it with the public key. That would remove FusionAuth from the producer path.

The second was a FusionAuth service account. The producer would hold an Entity id and secret, cache the access token until `exp`, and send that bearer. Humans would lose `writer` and keep read, verify, and erasure. The machine token would be writer-only. `company_id` would still be on the token. A switcher in `ValidateToken` would accept both a user token and a service token. A `company_admin` would provision those credentials for their own company.

## What we found

The shipped path is one FusionAuth user JWT. The sidecar checks the signature, issuer, application id, roles, and `company_id`, then forwards the same `Authorization` header. The core checks it again. The sidecar does not mint a token (source: `internal/sidecar/coreclient/client.go`).

`company_id` and `roles` are copied from the user's FusionAuth registration by the JWT populate lambda. Indicia stores no role table. A `company_admin` assigns `reader`, `writer`, and `company_admin` for users in their own company through `/admin/users` (source: `companyAdminGrantableRoles` in `internal/api/handlers/users.go`). That door does not create an Entity or an `ingest` grant.

A client-credentials token is a different object. `sub` is the Producer Entity. `aud` is the company Entity UUID, not the Indicia application id and not the `company_id` string. `permissions` on that company Entity carries `ingest`. `applicationId` is absent. `gty` contains `client_credentials`, and that is how the two tokens are told apart. `company_id` can still be written by a client-credentials lambda, as the same string the sidecar already reads. FusionAuth sets `sub`, `aud`, and `permissions`. A caller cannot stamp them.

`iss` and the JWKS are the tenant's. Every Entity in that tenant verifies. A check of `company_id` alone would admit a second Entity whose data says the same company. The check that stops it is `aud` equal to that company's Entity id and `ingest` present for that id. On a user token, the application id in `aud` answers whether the token was minted for this application. On a service token, `aud` plus `permissions` answer that question.

Entities and the client-credentials grant require a FusionAuth Starter plan or higher. The local container `fusionauth/fusionauth-app:1.69.3` has no license id (`docker-compose.yml`, `docker/fusionauth-kickstart/kickstart.json`). `FUSIONAUTH_APP_RUNTIME_MODE: development` does not enable the plan.

## What we tried to understand

Whether the producer is hard-bound to the FusionAuth the core trusts. Whether the sidecar verifies the JWT or only proxies it. What issuer and audience are, and which real values the sidecar and the core use. Whether one sidecar can accept tokens from many producers. Whether a service token can be told apart from a user token. What `sub`, `aud`, and `permissions` are on a client-credentials token, and whether `aud` is the company. Whether a missing `applicationId` lets another application in. Whether a switcher can keep `company_id` and still enforce the `ingest` grant. Who assigns roles inside a tenant, and whether a `company_admin` can set a service credential for that company only. Whether producer ingest can run on a service token alone. Whether localhost can exercise Entities without a paid license.

## Conclusions

We postponed the change. Issuing keys outside FusionAuth was considered so a producer could mint its own tokens. Service accounts do not replace that. FusionAuth remains the authority for identity, tenant, and permission, and it still signs every token.

## Related pages

- [Current Auth Flow](Current%20Auth%20Flow.md)
- [Open Questions](Indicia%20Auth%20Investigation%20(INV-43085)/wiki/Open%20Questions.md)
- [ADR-0001 Service Tokens for Ingest](ADR-0001%20Service%20Tokens%20for%20Ingest.md)
- [Wiki Index](Indicia%20Auth%20Investigation%20(INV-43085)/wiki/index.md)
