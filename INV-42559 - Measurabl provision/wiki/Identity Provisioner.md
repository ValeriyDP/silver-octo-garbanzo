---
name: Identity Provisioner
date: 2026-11-10T12:40:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
  - architecture
---

# Identity Provisioner

**Summary**: New THE HUB organization role for the `ClientDLTTransaction` user JWT. Five permissions. The migration is on this page. It is not applied in `hub`.

**Sources**: [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md). `hub` `apps/backend/src/migrations/1767810322000-create-organisation-user-role.ts`; `1767810600000-add-permission-to-organisation-user-role.ts`; `1775841000000-add-organization-user-organization-list-and-webhook-view-permissions.ts`; `1610715092465-add-permissions-organization-role.ts`; `permissions/permissions.controller.ts`; `permissions/permissions.service.ts` `assignOrganizationRoleToUser`.

**Last updated**: 2026-11-10

---

Name: `Identity Provisioner`. Scope: `Organization`.

Hub stores a role in `organizations_roles` and its permissions in `organizations_roles_permissions`. There is no API that creates a role. `Organization Admin` and `Organization User` were inserted by migrations.

Permissions, and only these:

- `organization:User:List`
- `organization:User:Create`
- `organization:User:Wallet:List`
- `organization:User:Wallet:Create`
- `organization:Wallet:List`

`POST /permissions/organization-role-assign` adds this role for one user and one organisation. It does not remove `Organization Admin`. The `POST /auth/login` user has to hold `Identity Provisioner` alone for the effective set to be these five.

## Migration

`hub/apps/backend/src/migrations/1792600000000-create-identity-provisioner-role.ts`

```ts
import { MigrationInterface, QueryRunner } from 'typeorm';

const ROLE_NAME = 'Identity Provisioner';

const PERMISSION_NAMES = [
  'organization:User:List',
  'organization:User:Create',
  'organization:User:Wallet:List',
  'organization:User:Wallet:Create',
  'organization:Wallet:List'
];

export class CreateIdentityProvisionerRole1792600000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.startTransaction();

    try {
      const permissions: Array<{ id: string; name: string }> = await queryRunner.query(
        `SELECT id, name FROM permissions WHERE name IN ($1, $2, $3, $4, $5);`,
        PERMISSION_NAMES
      );

      if (permissions.length !== PERMISSION_NAMES.length) {
        const found = new Set(permissions.map((permission) => permission.name));
        const missing = PERMISSION_NAMES.filter((name) => !found.has(name));

        throw new Error(`Identity Provisioner permissions are missing: ${missing.join(', ')}`);
      }

      const [existing]: Array<{ id: string }> = await queryRunner.query(
        `SELECT id FROM organizations_roles WHERE name = $1;`,
        [ROLE_NAME]
      );

      let roleId = existing?.id;

      if (!roleId) {
        const [created]: Array<{ id: string }> = await queryRunner.query(
          `INSERT INTO organizations_roles ("name", "description", "scope")
           VALUES ($1, $2, 'Organization')
           RETURNING id;`,
          [ROLE_NAME, ROLE_NAME]
        );

        roleId = created.id;
      }

      const values = permissions
        .map((permission) => `('${permission.id}', '${roleId}')`)
        .join(',');

      await queryRunner.query(`
        INSERT INTO organizations_roles_permissions ("permission_id", "role_id")
        VALUES ${values}
        ON CONFLICT DO NOTHING;
      `);

      await queryRunner.commitTransaction();
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DELETE FROM organizations_roles WHERE name = $1;`,
      [ROLE_NAME]
    );
  }
}
```

## Related pages

- [Wiki Index](index.md)
- [Hub User JWT Endpoints](Hub%20User%20JWT%20Endpoints.md)
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md)
