---
name: Smart Accounts Open Questions
date: 2026-08-11T15:51:00.000Z
tags:
  - smart-accounts
  - zerodev
  - open-questions
  - index
---
# Smart Accounts — Open Questions (Index)

Aggregates every unresolved question across the Smart Accounts notes. Each item links back to
its **parent document** (and the relevant section) where the full context lives. Resolve items in
their parent doc, then update this index.

Parent docs: [Smart Accounts Implementation State](Smart%20Accounts%20Implementation%20State.md) · [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md) ·
[Smart Accounts Obtaining Config Values](Smart%20Accounts%20Obtaining%20Config%20Values.md) · [Smart Accounts UI Wiring and Selection](Smart%20Accounts%20UI%20Wiring%20and%20Selection.md) ·
[Smart Accounts ZeroDev Access](Smart%20Accounts%20ZeroDev%20Access.md) · [Passkey Registration UV Failure](Debugging/Passkey%20Registration%20UV%20Failure.md)

---

## ZeroDev account & dashboard access
Parent: [Smart Accounts ZeroDev Access > Open questions — "where is ZeroDev?"](Smart%20Accounts%20ZeroDev%20Access.md#Open%20questions%20%E2%80%94%20%22where%20is%20ZeroDev%3F%22)

- [ ] Who owns the ZeroDev account that created project `00d5dd30-2df5-4d84-a7dd-d00f18be64ad`
  (which person / email / SSO; individual vs. Inveniam org account)?
- [ ] Where do the dashboard login credentials live (1Password/Bitwarden, HashiCorp Vault, or one
  engineer's head)? Is there a shared "ZeroDev" vault entry?
- [ ] Can we be **invited to the project team** in the ZeroDev dashboard instead of sharing a login?
- [ ] Is the paymaster **sponsorship policy enabled and funded** for this project on the testnets
  (Sepolia / Base Sepolia / Amoy)? (Only visible/manageable from the dashboard; not yet probed.)
- [ ] Is there a separate **mainnet** project, or is `00d5dd30-...` testnet-only?
  (`SMART_ACCOUNT_NETWORK=testnet` everywhere so far.)

## hub-service (backend) on-chain execution wiring
Parent: [Smart Accounts ZeroDev Access > Server-side note](Smart%20Accounts%20ZeroDev%20Access.md#Server-side%20note) · [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md)

- [ ] `SMART_ACCOUNT_BUNDLER_URL` / `SMART_ACCOUNT_PAYMASTER_URL` are **unset in every committed
  config** (only the v2 frontend has the ZeroDev project). Does any real backend on-chain
  execution happen today, or is it all client-driven via the frontend?
- [ ] `SMART_ACCOUNT_*` env + `INV_IAM_SERVICE_KEY` are not in dev compose — needed for the hub
  path to run (see [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md) §3).

## Passkey user verification (UV) policy
Parent: [Passkey Registration UV Failure > OPEN QUESTION - what if a passkey cannot be user-verified via fingerprint?](Debugging/Passkey%20Registration%20UV%20Failure.md#OPEN%20QUESTION%20-%20what%20if%20a%20passkey%20cannot%20be%20user-verified%20via%20fingerprint%3F)

- [ ] What is the intended behaviour when an authenticator **cannot** perform UV (UV=0)? e.g. no
  biometric + no PIN, non-UV security keys, corporate machines with biometric enrolment disabled.
- [ ] Do we **require** UV for Smart Account signer passkeys (secure default, blocks such devices)
  or **allow** UV=0 (any device can register)?
- [ ] If required: user-facing message / fallback when the device can't do UV, instead of a raw 500?
- [ ] Should the policy differ by environment (strict prod, relaxed local — the env-gated flag)?
- [ ] Is fingerprint/biometric a **hard product requirement** for Smart Account signers, or just
  the happy path?

## Server UV options/verify mismatch — which fix
Parent: [Passkey Registration UV Failure > Decision still open](Debugging/Passkey%20Registration%20UV%20Failure.md#Decision%20still%20open)

- [ ] Options request `userVerification: 'preferred'` but `verifyRegistrationResponse` defaults to
  requiring UV — mismatched in ALL envs. Pick a fix:
  - Option A (recommended): env-gated `WEBAUTHN_REQUIRE_USER_VERIFICATION` flag (secure default,
    relaxed local).
  - Option B: relax verify to `requireUserVerification: false` to match 'preferred' (simpler, less
    secure).
  - Option C: enable UV in the virtual authenticator (no code change).
- [ ] Note: proposed durable fix was **reverted (no permission to edit)** — needs an owner to re-apply.

## Productionisation gaps (from implementation review)
Parent: [Smart Accounts Implementation State > Maturity assessment](Smart%20Accounts%20Implementation%20State.md#Maturity%20assessment) · [Smart Accounts Happy Flow > Blocking gaps summary](Smart%20Accounts%20Happy%20Flow.md#Blocking%20gaps%20summary)

- [ ] **Multi-signer onboarding**: `create-smart-account.command.ts` hard-codes a single signer
  (`threshold = 50`, signer `weight = 50`, `// default to one signer for now`).
- [ ] **Per-user multi-key selection**: `propose`/`sign` just use `smartAccountUserSigningKeys[0]`.
- [ ] **Mainnet config**: chain IDs / bundler / paymaster are testnet-only defaults.
- [ ] **Custody hardening**: production hardening around the delegate `SMART_ACCOUNT_SIGNING_KEY`.
- [ ] **Frontend partner filter**: old-frontend `hub-connector.ts` hard-filters to `ICP` and ignores
  `SmartAccount` (see [Smart Accounts UI Wiring and Selection](Smart%20Accounts%20UI%20Wiring%20and%20Selection.md) §1).
