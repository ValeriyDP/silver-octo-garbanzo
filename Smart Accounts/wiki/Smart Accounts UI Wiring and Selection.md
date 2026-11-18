---
name: Smart Accounts UI Wiring and Selection
date: 2026-08-11T15:33:00.000Z
tags:
  - smart-accounts
  - zerodev
  - tokenization
  - frontend
  - deals-service
  - integration-settings
---
# Smart Accounts — UI Wiring & How the Hub-vs-SmartAccount Choice Is Actually Made

Companion to [Smart Accounts Implementation State](Smart%20Accounts%20Implementation%20State.md) and [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md).
Investigation trigger: "old UI seems hardcoded to The Hub; new UI (inveniam-v2) has no option
to use a smart account instead of The Hub." Both observations are correct — and the reason is
that **the Hub-vs-SmartAccount decision was never a per-deal choice in either frontend. It is an
organisation-level default that deals inherit.**

---

## TL;DR

- **Selection is org-level, not per-deal.** `organisation_integration_settings.blockchain_gateway = SmartAccount`
  (+ a smart account provisioned in iam-service with session keys). Every deal under that org
  **auto-inherits** `tokenizationPartner = SmartAccount` for those ledgers. There is no per-deal
  toggle in either UI.
- **Old frontend (`inveniam.io/apps/frontend`)**: per-deal tokenization connect flow is
  **ICP/Hub-only by construction** (hard-coded `ICP` filter, no `tokenizationPartner` sent). It
  predates SmartAccount and was never extended.
- **New frontend (`inveniam-v2`)**: no per-deal partner concept at all — the shared DTO enum
  doesn't even contain `SmartAccount`. Ledger config moved to **org-level** web3/hub settings +
  the ZeroDev passkey smart-accounts feature.
- **Execution**: unchanged from the other notes — `hub-service.shouldUseSmartAccount()` routes
  on-chain via the smart account iff iam-service has an active session key for that
  `organisationId + chainId`.

---

## 1. Old UI (`inveniam.io/apps/frontend`) — hard-forced to Hub/ICP

Per-deal tokenization connect only ever speaks ICP/Hub.

`src/app/+store/features/+tokenization/services/hub-connector.ts`:

- `connect()` posts a config with **no** `tokenizationPartner`:
```ts
const settings = {
  appType: this.appType,
  config: JSON.stringify({ providerType: this.providerType, usageType: this.appType })
};
```
  Backend `connect-hub.command.ts` reads `isSmartAccount = config.tokenizationPartner === SmartAccount`
  → false → takes the legacy `connectHub()` (Hub/ICP) branch.
- Reads are **hard-filtered to ICP** (undefined defaults to ICP):
```ts
(parsedConf.tokenizationPartner ?? TokenizationPartnersEnum.ICP) === TokenizationPartnersEnum.ICP
```
- `+shared/constants/tokenization-partners.constants.ts` lists Tokeny / FI / GrowthTech / etc. —
  **no SmartAccount entry**. So the old UI can neither send nor display a SmartAccount setting.

## 2. New UI (`inveniam-v2`) — no per-deal SmartAccount toggle

- The v2 shared DTO partner enum omits SmartAccount entirely
  (`packages/shared/dto/src/lib/v1/deal/integration-settings.ts`):
```ts
export type TokenizationPartnersEnum =
  | 'ICP' | 'TokenySolutions' | 'AKRU' | 'FundamentalInteractions'
  | 'GrowthTech' | 'Securitize' | 'Securrency' | 'Tokensoft' | 'Vertalo' | 'Other';
```
- The v2 hub/ledger settings connect ledgers via **"Add Ledger via Hub key"**
  (`packages/browser/features/hub-integration-settings/.../ledger-settings-page.component.ts` →
  `AddLedgerViaHubkeyModalComponent`) — a Hub-key flow, not a partner picker.
- Org-level web3/ledger config lives in `packages/browser/features/web3-integration-settings`
  and `.../hub-integration-settings`; the ZeroDev passkey account creation lives in
  `packages/browser/features/smart-accounts` (see the passkey note in `Debugging/`).

## 3. How SmartAccount is actually selected today — organisation level

The tokenization partner is **derived** from the org's default gateway, not chosen per deal.
`apps/deals-service/src/core/integration-settings/domain/services/deal-integration-settings-factory.service.ts`
synthesizes deal settings from the org's preferred/default settings:
```ts
const tokenizationPartner = orgSetting.blockchainGateway === BlockchainGatewayEnum.SmartAccount
  ? TokenizationPartnersEnum.SmartAccount
  : TokenizationPartnersEnum.ICP;
const entity = new DealIntegrationSettingsEntity(
  uuid(), orgSetting.appType, { ...orgSetting.config, tokenizationPartner }, dealId
);
```
The switch lives in `organisation_integration_settings.blockchain_gateway`, written by
`apps/deals-service/.../commands/upsert-organisation-integration-settings.command.ts`
(`blockchainGateway === SmartAccount → tokenizationPartner = SmartAccount`).

Backend enum source of truth: `shared-modules/Events/Multichain/interfaces.ts` —
`TokenizationPartnersEnum.SmartAccount = 'SmartAccount'` (present in backend, absent in v2 DTO).

---

## 4. Evidence from local `inv-db` (2026-08-11)

Deal `0a6645c7-4f27-44fc-97a2-0300a80defc3`, org `e8bbe6ff-877e-4103-bcb5-8514b5db7f5a`,
data room `a399fa09-5bc1-46b6-94ce-94d38c91b502`.

`invdeals.organisation_integration_settings` (the source of the inheritance):
```
provider_type | blockchain_gateway | is_default | smartAccountAddress
polygon       | SmartAccount       | t          | 0x224dbbbC96cAfD5F5AA6e91514C42b6bC6C2A6F7
base          | SmartAccount       | t          | 0x224dbbbC96cAfD5F5AA6e91514C42b6bC6C2A6F7
ethereum      | SmartAccount       | t          | 0x224dbbbC96cAfD5F5AA6e91514C42b6bC6C2A6F7
```

`invdeals.deal_integration_settings` for that deal (inherited): 3 x `tokenization` /
`tokenizationPartner: SmartAccount` (polygon/base/ethereum, Active) + 1 x `data-validation` /
`metachainv2` (Pending). — Note: data-room DLT verification is the `data-validation`/metachain
path, which is **separate** from the `tokenization`/SmartAccount path.

`inviam.smart_accounts` for org `e8bbe6ff`: address `0x224dbbb...`, `kernel_3_1`, threshold 50
(single signer), chains 80002 / 84532 / 11155111, `verified = false`.
`inviam.smart_account_session_keys`: one active (not revoked) session key per account, expiry
2026-09-10, Vault paths present. Signing key linked (weight 50).

---

## 5. Reconciling the confusion

Nothing is "missing a button" in the sense of a per-deal Hub/SmartAccount switch — by design:

- SmartAccount is an **org-wide gateway**, not a per-deal option.
- The old frontend's Hub-forcing is **legacy hard-coding** (the `ICP` filter), never extended to
  SmartAccount.
- The v2 frontend expresses the choice at **org settings** level and doesn't model per-deal
  partners at all (DTO has no SmartAccount).

## 6. How `blockchain_gateway = SmartAccount` actually gets written (RESOLVED)

It is **event-driven off smart-account creation** \u2014 NOT a manual seed, and NOT selectable in the
per-deal or org-ledger UI.

### The automatic path (the only way SmartAccount gets set today)

1. Client (v2 `smart-accounts` feature \u2014 ZeroDev + passkey, the modal from the passkey debug note)
   creates the account + session key and calls `POST /iam/smart-accounts` with `chainIds[]`.
2. iam-service `CreateSmartAccountCommand` persists per chain and emits a **`SmartAccountCreatedEvent`
   per chain** (payload: `organisationId`, `chainId`, `address`).
3. deals-service saga consumes it \u2014
   `application/sagas/deal-integration-events.sagas.ts`:
```ts
@Saga()
subscribeForSmartAccountCreatedEvent = (events$) =>
  events$.pipe(
    ofType(SmartAccountCreatedEvent),
    map(({ payload }) => new UpsertOrgSettingsOnSmartAccountCreatedCommand(payload))
  );
```
4. `UpsertOrgSettingsOnSmartAccountCreatedCommand` (`domain/commands/upsert-org-settings-on-smart-account-created.command.ts`)
   upserts an `organisation_integration_settings` row: `appType = tokenization`,
   `blockchainGateway = SmartAccount`, `providerType = getProviderTypeFromChainId(chainId)`,
   `config.smartAccountAddress = address`, `status = Active`, and `isDefault = true` **iff** the org
   has no existing default for that provider.
5. From there, deals inherit it via `deal-integration-settings-factory` (see \u00a73).

> This exactly explains the local `inv-db` **~14:14 burst of 3 rows** (chains 80002 / 84532 /
> 11155111 \u2192 polygon / base / ethereum) \u2014 one per `SmartAccountCreatedEvent` from creating the
> account across 3 chains. It was the event cascade, not a hand-written seed.

### The manual admin path (Hub-only in practice)

- Backend endpoint: `PATCH /integration-settings/organisations`
  (`OrganisationIntegrationSettingsController.upsert`) accepts a `blockchainGateway` field, and
  `upsert-organisation-integration-settings.command.ts` maps
  `resolvedGateway = blockchainGateway ?? Hub` \u2192 `SmartAccount ? SmartAccount : ICP`.
- **But the v2 client cannot send SmartAccount here.** The v2 write DTO has no gateway/config field:
```ts
// inveniam-v2/packages/shared/dto/.../organisation/integration-settings/index.ts
export type OrganisationIntegrationSettingsRequest = {
  appType: 'tokenization' | 'data-validation';
  providerType: LedgerTypeEnum;
  config?: never;            // no blockchainGateway, no config
};
```
  The sole caller \u2014 `hub-integration-settings/.../add-ledger-via-hubkey-modal.component.ts` \u2014 uploads
  a Hub key then `patch({ appType: 'tokenization', providerType })`. With no `blockchainGateway`, the
  backend defaults to **Hub** (tokenizationPartner = ICP). So the v2 org-ledger UI can only ever
  create **Hub** ledgers.

### Conclusion

- **SmartAccount is never chosen via a settings toggle.** It is a **side effect of creating a smart
  account** (passkey/ZeroDev flow) \u2192 `SmartAccountCreatedEvent` \u2192 deals saga \u2192 org gateway flips to
  SmartAccount \u2192 deals inherit. Fully wired end-to-end, event-driven.
- The manual `PATCH` gateway path exists in the backend but the v2 UI only exercises the **Hub**
  branch (no way to pass `blockchainGateway=SmartAccount` from v2 today).
- This refines \u00a75's earlier hunch: the local rows were **not** a hand seed \u2014 they were produced by
  the smart-account-created event cascade.
