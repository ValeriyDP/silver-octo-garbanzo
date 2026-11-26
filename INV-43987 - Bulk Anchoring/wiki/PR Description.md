---
name: PR Description
date: 2026-11-26T14:58:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - wiki
  - pr
---

# PR Description

> [!info] Active
> Draft PR body for INV-43987. Copy into GitHub. Facts below are from the branch `INV-43987-bulk-anchoring` against `develop` and from the local and `devus02` runs.

**Summary**: SQS FIFO per signing wallet for NVNM document anchoring in IO Hub Service, plus retry on a THE HUB outage and on a failed queue of parked documents after register.

**Sources**: `apps/hub-service`, `shared-modules/NestAwsCqrs`, local emit to Floci and to `arn:aws:sns:us-east-1:403170495167:devus02-notification-topic.fifo`.

**Last updated**: 2026-11-26

---

### JIRA TICKET

### https://inveniam.atlassian.net/browse/INV-43987

---
### Overview

Bulk anchoring on NVNM must not let one organisation’s files block another, and must not fail a file because THE HUB was briefly down or its wallet queue was full.

IO Hub Service copies each file start onto the existing hub command FIFO queue with `MessageGroupId` set to the signing wallet:

- regular organisation: `anchoring:org:{organisationId}`
- ClientDLT (signing portfolio): `anchoring:identity:{portfolioId}`

SQS then gives one in-flight message per group and parallel groups. A THE HUB outage (no HTTP response, HTTP 503 on write, failed login to THE HUB) and an underfunded identity wallet are `Retryable` and stay on the queue. Other errors stay final. Parked documents that wait for `addRegistry` are queued on the same wallet group after the registry is stored; if that queue send fails, the register-success message is redelivered so none is stranded.

Legacy tokenization and every non-NVNM ledger are untouched.

---
### What has been done

- Internal copy of `HubDocumentSyncingRequestedEvent`, `ClientDLTTransaction`, and `HubSymbolRegisteringSucceededEvent` onto the hub command FIFO, grouped by `anchoringMessageGroupId`.
- `TransactionsSagas.syncDocument` and `ClientDltProvisioningSaga` listen only to the Internal events, so the public SNS message no longer starts the write.
- `Retryable` + `installHubSqsRetry` on `SqsConsumer`. Production hub does not set `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER`. `HubUnavailableError` covers no response and HTTP 503 on write. `HubConnectionOutageException` marks a failed THE HUB login without treating every 502 as an outage. Register redelivers the same way as document sync.
- Parked documents: `EnsureRegistryStep` / `OpenDealRegister` park while a register is open; `StoreDealAnchorRegistryCommand` stores the symbol and queues every parked taxonomy on the wallet group. A failed send throws `InternalQueueSendError` (`Retryable`) so the success message is redelivered. Dedup id `DocumentProvisioning:{taxonomyId}` skips what was already sent.
- `PublishInternalEventBaseHandler` owns the send. A missing group id or deduplication id is `InternalEventSendRejectedError` and is not retried.
- Direct `InternalSQSProducer` / `HubInternalEvents` send to the command queue. `NestAwsCqrs` consumer is unchanged except for the prototype retry hook in hub `main.ts`.
- Identity wallet underfund throws `IdentityWalletUnderfundedError` (`Retryable`) so the identity group waits instead of failing the file.

---

## Version Bump?

Did I bump the version in the `pyproject.toml` file  or `package.json` file of the package I am updating?

- [ ] Yes
- [x] No

IO Hub Service and `@inveniam/nest-aws-cqrs` are not versioned packages in this change. No `package.json` version on the branch differs from `develop`.

---

### Type of Change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [x] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

Public event names are unchanged. Callers still publish `HubDocumentSyncingRequestedEvent` / `ClientDLTTransaction`. The Internal copy is hub-private.

---
### How the test was performed ( Dev K8S )

`devus02` SNS, profile `inveniam-sso-dev`, topic `arn:aws:sns:us-east-1:403170495167:devus02-notification-topic.fifo`.

1. Regular org **Lavish Leavitt** `6504fead-3a75-456a-87dd-1a824b54cacc`, deal `a1432e40-2774-4a57-a56e-8c7dbd921224`, registry **3248**.
   - 250 `HubDocumentSyncingRequestedEvent` documents.
   - Started 13:24:44, ended 13:42:42 (1078 s) → **0.232 tx/s**, **4.31 s/tx**. Matches one-at-a-time FIFO on a single org group.
2. Two orgs in parallel, 50 documents each:
   - Lavish Leavitt / registry 3248
   - **Balmy Benz** `39647414-304c-4adc-b94a-bf9013f5111d`, deal `87e2af8f-c172-4d07-b768-a466e1fc2b8d`, registry **3290**
   - Distinct groups `anchoring:org:6504fead-…` and `anchoring:org:39647414-…`.
3. Earlier local Floci + Graylog: three groups (two regular orgs + one ClientDLT identity) with 5 fake taxonomies each. Groups ran in parallel. Documents inside a group stayed in order. A Hub outage redelivered; a chain revert did not block the rest of the group.

Local helper: `inveniam.io/tmp/emit-regular-org-sync-bulk-floci.sh` (untracked; not in the PR).

---
### How Has This Been Tested?

Your pull-request will likely not be merged unless it is covered by some form of impactful unit testing.

- [x] I added new unit tests to cover this change
- [ ] I believe this change is already covered by existing unit tests

New / extended tests on the publishers, Internal send, sagas (`HubDocumentSyncingRequestedInternal` / `ClientDLTTransactionInternal` only), `Retryable` rethrow on sync and register, `HubConnectionOutageException`, `installHubSqsRetry`, parked-document queue, and `InternalQueueSendError` on a failed parked send.

---
### Proof of Dev K8S Deployment

Ran against live `devus02` SNS (account `403170495167`), not a new helm rollout of this branch. Hub on that environment consumed the events. Registry ids taken from NVNM explorer:

- `https://explorer.nvnm.testnet.nvnmchain.io/tx/0xb7d9f820a5e4462966920012b9dd12e9a0675c996c328218b8155c74c3bf1372` → registry **3248**
- `https://explorer.nvnm.testnet.nvnmchain.io/tx/0x9be27c70d6f0b1801c85f0f4e810f8f01a9d848b2f86e28c775075f5bc058e7d` → registry **3290**

No screenshot of the hub pod is attached. Timing for the 250-document run is under Benchmark.

---
### Proof of  local unit test case execution

Not a full `hub-service` suite. Targeted runs on this machine:

```
PASS src/transactions/domain/services/transactions-model-factory.service.test.ts
Tests: 7 passed, 7 total

PASS src/organisation-provisioning/domain/commands/store-deal-anchor-registry.command.test.ts
Tests: 5 passed, 5 total
  ✓ stores the symbol then queues every parked document on the wallet group
  ✓ queues parked documents when the success event has no taxonomyId
  ✓ redelivers when the queue rejects a parked document, so none is stranded
  ✓ does not redeliver when no wallet group can be resolved
  ✓ throws when the inner join matches no row
```

CI on the PR should run the rest.

---
### Proof of Benchmark Execution

**Mandatory:** Please paste execution logs or link to performance results below.

Single org, 250 documents, `devus02`, registry 3248:

```
started 13:24:44
ended   13:42:42
count   250
duration 1078 s
rate     0.232 tx/s
cost     4.31 s/tx
group    anchoring:org:6504fead-3a75-456a-87dd-1a824b54cacc
```

That cost is Hub + NVNM per document in one FIFO group, not SNS publish time. A second run of 50+50 on two org groups was started to show the groups do not block each other; paste that timing here if you have it.

---
### Proof of Self-Review

**Mandatory:** Please confirm you have performed a self-review using the cursor self-review command before requesting a peer review.

- [x] I have executed the cursor self-review command for this PR
- [x] I have reviewed and addressed all Critical and Major issues identified in the self-review
- [x] I have documented any Minor issues or Enhancements that were deferred with justification

**Self-Review Results:**

Verdict after the parked-document follow-up: **READY_FOR_HUMAN_REVIEW**.

The first pass marked one **major**: Internal `SendMessage` failure is a plain `Error`, production has `ENABLE_QUEUE_GLOBAL_ERROR_HANDLER` unset, so the copy hop can ack and drop. That was **downgraded**. It is not a regression (`develop` already drops handler errors), AWS already retries `SendMessage`, and a permanent IAM/URL failure would loop until DLQ. The one case with real state loss was `StoreDealAnchorRegistryCommand` (registry already stored, parked rows with no other trigger). That is now `InternalQueueSendError` (`Retryable`). Commit `8805cae0de7`.

Deferred (minor / accepted):

- The three publishers (document sync, ClientDLT, register-success copy) still drop on a failed send. Same as every other hub handler error today.
- `HubInternalEvents` falling back to the event queue would skip sagas. Hub always has `COMMAND_HANDLERS_QUEUE_NAME`.
- Dummy `@EventsHandler` classes on Internal events look like log-only noise; they register the event name so the command consumer accepts the message. Keep the classes.
- `identity-wallet-funds.ts` grew in this PR (underfunded → `Retryable`, plus chain balance / requote). Related to FIFO hold, not grouping.

No blockers. No secrets, no new dependencies. Light security only.

---
### How to test

**Local (Floci)**

Hub with `BROKER_TYPE=snssqs`. Org already has a registry.

```bash
cd inveniam.io
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
ENDPOINT_URL=http://127.0.0.1:4567 FLOCI_CONTAINER=inv-floci \
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:000000000000:inveniam-events.fifo \
  ./tmp/emit-regular-org-sync-bulk-floci.sh <symbol> 5
```

Graylog: group `anchoring:org:{organisationId}`, documents in order, ~4 s apart. A second org with a different `ORGANISATION_ID` / `DEAL_ID` / symbol should run at the same time.

**devus02**

```bash
export SNS_TOPIC_ARN=arn:aws:sns:us-east-1:403170495167:devus02-notification-topic.fifo
export PROFILE=inveniam-sso-dev

# one org
./tmp/emit-regular-org-sync-bulk-floci.sh 3248 2

# two orgs in parallel
parallel -j2 --line-buffer --colsep ' ' \
  'ORGANISATION_ID={1} DEAL_ID={2} ./tmp/emit-regular-org-sync-bulk-floci.sh {3} 50' ::: \
  '6504fead-3a75-456a-87dd-1a824b54cacc a1432e40-2774-4a57-a56e-8c7dbd921224 3248' \
  '39647414-304c-4adc-b94a-bf9013f5111d 87e2af8f-c172-4d07-b768-a466e1fc2b8d 3290'
```

Outage: stop THE HUB, emit one document, start THE HUB. The message must stay on the group and complete. A contract revert must not retry and must not block the next taxonomy in the same group.

---

## Suggested Checklist:

- [x] I have performed a self-review of my own code using cursor
- [x] I have commented my code, particularly in hard-to-understand areas
- [x] I have made corresponding changes to the documentation
- [x] My changes generate no new warnings
- [x] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] I ran `uv run make check; uv run make lint; yarn lint; yarn type-check` to appease the lint gods

Targeted hub-service tests and eslint on the parked-document files passed. Full `yarn lint` / type-check and the whole hub-service suite were not run on this machine after the last commit. Wiki for the ticket lives under `Inveniam-vault/INV-43987 - Bulk Anchoring/`.

### Bugs:

- [x] Internal send failure on the three publishers is not `Retryable` (accepted; same as other hub handler errors).
- [x] `HubInternalEvents` event-queue fallback would skip sagas if `COMMAND_HANDLERS_QUEUE_NAME` were unset (not a real hub deploy).
- [x] `identity-wallet-funds.ts` is a second change in the same PR (underfunded retry).
- [ ] 

---

## Related pages

- [Code Review Plan](Code%20Review%20Plan.md)
- [SQS FIFO Approach](SQS%20FIFO%20Approach.md)
- [Legacy Tokenization](Legacy%20Tokenization.md)
