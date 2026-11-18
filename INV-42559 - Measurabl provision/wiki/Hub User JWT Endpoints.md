---
name: Hub User JWT Endpoints
date: 2026-11-10T12:12:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# Hub User JWT Endpoints

**Summary**: THE HUB URLs on `ClientDLTTransaction` that use the user JWT, with the route-specific permission for each. `POST /auth/login` returns the JWT. The rest send `Authorization: Bearer`. Where two permissions are listed, either one is enough.

**Sources**: `inveniam.io` `apps/hub-service/src/organisation-provisioning/infrastructure/hub-admin.session.ts`; `hub-admin.client.ts`; `domain/chain/portfolio/ensure-hub-identity.step.ts`; `ensure-hub-identity-wallet.step.ts`; `domain/chain/shared/identity-wallet-top-up.ts`; `infrastructure/hub-ledger-quotes.ts`. `hub` `apps/backend/src/auth/auth.controller.ts`; `organizations/organization-administration.controller.ts`; `wallets/wallets.controller.ts`; `transactions-process/ledgers.controller.ts`; `permissions/domain/entities/permissions.constants.ts`; `permissions/application/permission.guard.ts`; `permissions/permissions.service.ts`.

**Last updated**: 2026-11-10

---

- `POST /auth/login` — none
- `GET /organizations/{hubOrganisationId}/users?search=` — `organization:User:List` or `organization:User:Wallet:List`
- `POST /organizations/{hubOrganisationId}/users` — `organization:User:Create` or `organization:User:Wallet:Create`
- `GET /organizations/{hubOrganisationId}/users/{identityId}/wallets` — `organization:User:Wallet:List`
- `POST /wallets/keys/derive` — `organization:User:Wallet:List`
- `POST /organizations/{hubOrganisationId}/users/{identityId}/wallets` — `organization:User:Wallet:Create`
- `POST /wallets/keys/decode` — `organization:User:Wallet:List`
- `GET /ledgers/balance/{walletId}` — none
- `GET /organizations/{hubOrganisationId}/wallets` — `organization:Wallet:List`

## Permissions

- `organization:User:List`
- `organization:User:Create`
- `organization:User:Wallet:List`
- `organization:User:Wallet:Create`
- `organization:Wallet:List`

## Related pages

- [Wiki Index](index.md)
- [Organisation Provisioning Sequence](Organisation%20Provisioning%20Sequence.md)
- [Identity Provisioner](Identity%20Provisioner.md)
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md)
