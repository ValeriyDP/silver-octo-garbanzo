---
name: new flow proposal
date: 2026-11-12T18:26:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
---

**Subject:** Portfolio identity provisioning — no Hub auth change, one role migration

Hi Darell,

We looked at two ways for inv-hub-ms (IO) to get Hub identities for portfolios on the MSR flow, and we need a decision from you and Security.

The first is machine-to-machine authentication. inv-hub-ms would authenticate to an additional FusionAuth tenant and exchange that token for a Hub personal JWT. That approach takes a lot of effort, and the changes sit on the Hub side.

The second is a dedicated Hub user with a new, limited role, Identity Provisioner. On that path the Hub authentication flow and code stay as they are. It needs one Hub migration and some one-time manual setup per organisation.

The FusionAuth approach would require:

1. A FusionAuth tenant on the Hub side, which Hub would validate.
2. A Hub user who is present in the Hub and assigned to the organisation with the `Identity Provisioner` role. That role does not exist until the migration is applied, so the migration has to run first, and only after that can the user be invited into the Hub. The FusionAuth client and this Hub user are two separate records.
3. A new Hub endpoint that accepts the FusionAuth token and returns a personal Hub JWT (`userId`, `tokenType: personal`, `organizationId`).
4. A validator on that endpoint that checks the FusionAuth token against that tenant's keys and then mints that personal Hub JWT. Hub's existing JWT check trusts only Hub's own key, so it will not accept the FusionAuth token.
5. The personal Hub JWT minted in step 4 will be used by IO.

We would rather leave Hub's auth as it is. Changes to Hub's auth, and the exchange, exist only so IO can get a Hub JWT, and that step is not Hub's to carry.

The second approach uses Hub as it is. These are the nine Hub URLs that provision a portfolio identity. Five permissions cover the ones that check a permission. Where a route lists two names, either one is enough. The role carries the one named here.

1. `POST /auth/login` — no permission. This is how we obtain the personal JWT.
2. `GET /organizations/{hubOrganisationId}/users?search=` — `organization:User:List` (the route also accepts `organization:User:Wallet:List`).
3. `POST /organizations/{hubOrganisationId}/users` — `organization:User:Create` (the route also accepts `organization:User:Wallet:Create`).
4. `GET /organizations/{hubOrganisationId}/users/{identityId}/wallets` — `organization:User:Wallet:List`.
5. `POST /wallets/keys/derive` — `organization:User:Wallet:List`. This is not permissionless. Hub returns the derived private key and the address. That response is what we store as the new identity wallet. Hub does not keep the mnemonic.
6. `POST /organizations/{hubOrganisationId}/users/{identityId}/wallets` — `organization:User:Wallet:Create`.
7. `POST /wallets/keys/decode` — `organization:User:Wallet:List`. This is not permissionless either. It does not mint a key. Hub deletes `privateKey` before the response and returns the public address. We call it because `GET /ledgers/balance/{walletId}` returns only the balance number. The address is what the local gas estimate and the parent-wallet funding transfer need. The ciphertext is `keys.encoded` from a wallet this user already listed.
8. `GET /ledgers/balance/{walletId}` — no permission name. A personal JWT is enough, and Hub still checks that the wallet belongs to the caller or to an organisation the caller is a member of.
9. `GET /organizations/{hubOrganisationId}/wallets` — `organization:Wallet:List`.

The five permissions on the role are:

1. `organization:User:List`
2. `organization:User:Create`
3. `organization:User:Wallet:List`
4. `organization:User:Wallet:Create`
5. `organization:Wallet:List`

`organization:User:Create` cannot assign a role. `POST /organizations/{hubOrganisationId}/users` writes an identity on that organisation (first name, last name, email) and does not write a role. Inviting a Hub user with a role is `POST /organizations/{hubOrganisationId}/invitation/send`, which requires `organization:Organization:Setup`. Assigning a role to an existing Hub user is `POST /permissions/organization-role-assign`, which requires `system:Permission:Manage`. `Identity Provisioner` has neither permission.

The provisioner account belongs to one Hub organisation only. We create one such user for each organisation. `io_hub_organisation_map` has one row per organisation. That row stores the mnemonic ciphertext. The provisioner login and password are not on that row.

Next steps, if you confirm:

We remove organisation creation from inv-hub-ms. That path is legacy. The organisation is created in Hub as usual, and the rest of the setup is manual.

The wallet mnemonic is encrypted with Vault transit. The mnemonic must not be typed into the command, because that puts it in shell history and in the process list. Read the base64 value from stdin (`plaintext=-`) or from a file (`plaintext=@file`). Please have DevOps confirm which of those this Vault CLI accepts before we put it in the runbook, and delete the file after the write.

The mount below is dev (`inveniam-devus01-hub-tse`). On a cluster the mount is `inveniam-<env>-hub-tse`. Production is not this path.

```shell
vault write -f inveniam-devus01-hub-tse/keys/<ioOrganisationId>
base64 < mnemonic.txt | vault write inveniam-devus01-hub-tse/encrypt/<ioOrganisationId> plaintext=-
```

The database stores that mnemonic ciphertext and nothing else from this setup. The provisioner login and password are environment variables on inv-hub-ms. They are not written to `io_hub_organisation_map` or to any other table.

DevOps sets those environment variables during organisation setup. inv-hub-ms reads them at runtime. Decrypt of the mnemonic stays with IO Hub Service, under the existing policy on `inveniam-<env>-hub-tse/decrypt/+`.

Rotation: when the operator who set the passwAord leaves that duty, and once a year while the organisation is active, reset the Hub password and replace the environment variables in the same change.

An optional extra step is to cipher that login and password with the same transit key, and to put the ciphertexts in those environment variables. The account info is then hidden from anyone who can read the environment. inv-hub-ms decrypts them at runtime, under the same policy. The ciphertexts still do not go into the database. If we take this step, rotation replaces the ciphertext in the environment after the password reset.

```shell
base64 < provisioner-email.txt | vault write inveniam-devus01-hub-tse/encrypt/<ioOrganisationId> plaintext=-
base64 < provisioner-password.txt | vault write inveniam-devus01-hub-tse/encrypt/<ioOrganisationId> plaintext=-
```

Then this row is inserted in the INVENIAM.io database. It is the organisation ids and the mnemonic ciphertext.

```sql
INSERT INTO io_hub_organisation_map (
    io_organisation_id,
    hub_organisation_id,
    mnemonic_ciphertext
  ) VALUES (
    '<ioOrganisationId>',
    '<hubOrganisationId>',
    '<vault:v1:...>'
  );
```

After the migration, we invite that one user into that one Hub organisation with `Identity Provisioner`.

Please confirm these three points, or tell me what you want changed:

1. Hub does not change its auth flow or auth code. Hub applies one migration that adds `Identity Provisioner` with the five permissions above.
2. One provisioner login per Hub organisation, and that user is a member of that organisation only.
3. The database stores the mnemonic ciphertext only. The provisioner login and password are environment variables on inv-hub-ms, with the access and rotation above. Ciphering those environment values with the same transit key is optional, to hide the account info.

If you confirm, the split is:

- Hub applies the migration.
- DevOps creates the organisation in Hub, encrypts the mnemonic, inserts the map row, sets the provisioner login and password on the inv-hub-ms environment, and invites that one user into that organisation with `Identity Provisioner`.
- IO removes organisation creation from inv-hub-ms, reads the mnemonic ciphertext from the map, and reads the account credentials from the environment.

For the account-credential ciphertext, the transit-key answers hold. Another organisation id cannot decrypt it.

**The only way to ensure it is only used by the intended org.** The transit key is created for that IO organisation id, and the decrypt uses the organisation id from the event. The ciphertext was produced under `encrypt/<that organisation id>`. Vault opens it only with `decrypt/<that same id>`. A different organisation id selects a different key, and the decrypt fails.

**Just code in IO?** Code and the correct transit key. The code passes the event's organisation id as the key name. The key is what makes any other id fail.

**Where is MFA?** Unchanged by the ciphertext. This login sends only the login id and the password. There is no MFA step in that call. MFA needs a person, and this path is a machine, so the provisioner user has MFA off. If MFA is turned on for that user in the Hub FusionAuth tenant, the login fails.

**One org in IO using this against the protected org.** Same protection as HubKeys. The event's organisation id is the transit key name, as the HubKeys path is scoped by organisation id. Organisation A's event decrypts with organisation A's key. Organisation B's credential ciphertext does not open under that key.

**An entity that is not IO.** Same level of protection as the rest of IO's Vault access. The stored value is ciphertext. Reading it does not yield the password. Decrypting it takes the inv-hub-ms Vault token, which is allowed `decrypt/<organisation id>`, the same token that reads HubKeys and the mnemonic. A party that is not IO does not have that token.

- we should not pass these as env vars at all 
	- Agree
- devops will not set this up. Create a script for us to execute. No manual steps . 
	- Agree
- need a way to protect these transactions. To ensure only IO can login with this user
	- With Hub and IO as they are, POST /auth/login accepts the email and password from any caller. IO cannot add a check that the caller is IO, and Hub has no such check. The password stays in IO. The call uses HTTPS, so the password is not exposed on the network. That is the protection available for this login.
- suggest these are stored in vault referenced with org so there is no need for env vars
	- Store next to the mnemonic in the `io_hub_organisation_map` table
	
- 3a perhaps linked rule
	- NA
- 3b use of certs
	- NA
- 3x perhaps known clientid/secret
	-  This could be a task for Gadget, implement permissioned token-based access (fine-grained token GitHub like)