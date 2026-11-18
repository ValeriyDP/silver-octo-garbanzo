---
name: Passkey Registration UV Failure
date: 2026-08-11T00:00:00.000Z
status: solved
resolution: enroll-touch-id-fingerprint
service: iam-service
tags:
  - smart-accounts
  - zerodev
  - passkey
  - webauthn
  - debugging
  - iam-service
  - frontend
---

# Passkey Registration UV Failure (Smart Account signer)

> Status: SOLVED (2026-08-11) by enrolling a Touch ID fingerprint (System Settings -> Touch ID & Password -> Add Fingerprint), then re-registering -> Touch ID prompt appears -> UV=1 -> verify passes. Confirmed working by the reporter.
>
> Original diagnosis: LOCAL CAUSE CONFIRMED & UNBLOCKED (2026-08-11). Dev Mac had a Touch ID reader but NO fingerprint enrolled. Chrome's macOS passkey / iCloud-Keychain flow uses Touch ID for user verification and does NOT fall back to the login password, so registration produced UV=0 -> verify (which defaults to requiring UV) threw 500. Fix: System Settings -> Touch ID & Password -> Add Fingerprint, then re-register -> Touch ID prompt appears -> UV=1 -> passes. NOT a virtual authenticator (DevTools WebAuthn was disabled). Remote 'worked' only because those devices produced UV=1.
>
> Underlying server bug still stands (below): options say `userVerification: 'preferred'` but `verifyRegistrationResponse` defaults to requiring UV -> mismatch in ALL envs. Proposed code fix was reverted (no permission to edit). Return to this later.
> Date: 2026-08-11 | Service: iam-service | Flow: Smart Account passkey registration (front-v2 / inveniam-v2)

## Symptom
`POST /iam/passkeys/register/verify` returns **500**. Backend log:
```
BadRequestException: User verification was required, but user could not be verified
  at PasskeysService.verifyRegistration (apps/iam-service/src/core/passkeys/application/services/passkeys.service.ts:147)
```
Happened on Firefox AND Chrome (without account). Not a browser bug.

## Root cause
Policy mismatch inside iam-service `passkeys.service.ts`:
- Registration options request `authenticatorSelection.userVerification: 'preferred'` (line ~77) -> authenticator is allowed to skip user verification.
- `verifyRegistrationResponse(...)` is called WITHOUT `requireUserVerification`, so `@simplewebauthn/server` v13 defaults it to **`true` (required)**.

The authenticator returned the credential with the **UV flag = 0** (decoded `authenticatorData` flags byte = `0x59` => UP=1, BE=1, BS=1, AT=1, UV=0). Because options only 'preferred', UV=0 is spec-legal, but verify requires UV=1 -> throws -> wrapped as 500.

Why UV=0 locally (CONFIRMED): dev Mac had a **Touch ID reader but no fingerprint enrolled**. Chrome's macOS passkey/iCloud-Keychain create flow uses Touch ID for UV and does NOT fall back to the login password, so it created the credential unverified (just a "save to Passwords" popup + Continue, no Touch ID / no password prompt) => UV=0. (Other possible causes: DevTools virtual authenticator with "User Verified" unchecked, or a Mac with no screen-lock password.) Shape in the request supports this: `authenticatorAttachment: platform`, `transports: [hybrid, internal]`, `credProps.rk: true`.

## Client side (inveniam-v2) - not the problem
The frontend uses ZeroDev `@zerodev/webauthn-key`:
`packages/browser/features/smart-accounts/src/lib/services/smart-account-modal/smart-account-modal.service.ts` (~line 115):
```ts
webAuthnKey = await toWebAuthnKey({
  passkeyName: 'Inveniam Smart Account',
  passkeyServerUrl: API_BASE_URL + '/iam/passkeys',
  mode: WebAuthnMode.Register,
  ...
});
```
`toWebAuthnKey` just relays the server's `/register/options` to `navigator.credentials.create()` and posts to `/register/verify`. There is NO client-side UV knob. The UV policy is entirely server-controlled.

## Quick unblock (no code change)
- **CONFIRMED FIX for real device:** enroll a fingerprint (System Settings -> Touch ID & Password -> Add Fingerprint), then re-register. Touch ID prompt now appears -> UV=1 -> verify passes.
- If using the DevTools virtual authenticator: DevTools -> WebAuthn -> enable **"User Verified"**. Then registration produces UV=1 and verify passes.

## Proposed durable fix (server-side, env-gated) - REVERTED, to redo
Make a single flag drive all four call sites so options and verify are consistent. Secure-by-default (require UV), relax only locally.

Files:
1. `apps/iam-service/src/config/environment.ts` - add under `webauthn`:
```ts
requireUserVerification: process.env.WEBAUTHN_REQUIRE_USER_VERIFICATION !== 'false' // default true
```
2. `apps/iam-service/src/core/passkeys/application/services/passkeys.service.ts`:
- add helper `private requireUserVerification(): boolean { return this.config.get<boolean>('webauthn.requireUserVerification') !== false; }`
- registration options: `userVerification: this.requireUserVerification() ? 'required' : 'preferred'`
- authentication options (`generateAuthenticationOptions`): add `userVerification: this.requireUserVerification() ? 'required' : 'preferred'`
- `verifyRegistrationResponse`: add `requireUserVerification: this.requireUserVerification()`
- `verifyAuthenticationResponse`: add `requireUserVerification: this.requireUserVerification()`
3. Local override (docker-compose.override.yml), for `inv-iam-ms`:
```yaml
environment:
  WEBAUTHN_REQUIRE_USER_VERIFICATION: "false"
```
Then `docker compose up -d inv-iam-ms` (env change needs container recreate; TS hot-reloads under start:dev).

Note: this also fixes a latent prod bug - options/verify were mismatched in ALL environments, not just local. With options set to 'required', browsers actively enforce Touch ID/PIN (UV=1) in real environments.

## Decision still open
- Option A (recommended): env-gated flag as above (secure default, relaxed local).
- Option B: just relax verify to `requireUserVerification: false` to match 'preferred'. Simpler, less secure.
- Option C: enable UV in the virtual authenticator, no code change.

## OPEN QUESTION - what if a passkey cannot be user-verified via fingerprint?
Not sure we need to handle this, but flagging it. The fingerprint fix works for devices with an
enrolled biometric, but what is the intended behaviour when the authenticator **cannot** perform
user verification (UV=0)? e.g.:
- Device with no biometric AND no screen-lock/PIN (nothing for the OS to verify against).
- Security key / roaming authenticator that doesn't support UV.
- Corporate/locked-down machines where biometric enrolment is disabled.

Questions to resolve:
- Do we **require** UV for Smart Account signer passkeys (secure default, blocks such devices), or
  **allow** UV=0 (accept less assurance so any device can register)?
- If required: what is the user-facing message / fallback when their device can't do UV, instead
  of a raw 500?
- Should the policy differ by environment (strict in prod, relaxed in local/dev) - i.e. the
  env-gated Option A above?
- Is fingerprint/biometric a hard product requirement for Smart Account signers, or just the
  happy path?
