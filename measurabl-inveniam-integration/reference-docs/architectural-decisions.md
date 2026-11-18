# MSR–IO architectural decisions and restrictions

Working list for the Measurabl (MSR) ↔ Inveniam IO integration. Add items as they are agreed. This is not a full ADR log.

Related: [Measurabl document anchoring — embedded in existing services](../measurabl-anchoring-embedded-in-existing-services.md), [high-level architecture (Aug 17)](msr-io-integration-high-level-architecture-aug-17.md).

## D1. Dedicated ingest endpoint for BillAI

**Status:** Accepted; out of scope for the anchoring work since 2026-09-08 (see [D5](#d5-ingestion-is-out-of-scope-for-anchoring--anchoring-is-triggered-from-regular-data-room-ingestion))  
**Date:** 2026-09-06

> Whether and how this endpoint is implemented is now owned by Sentinel, the document-processing team (see D5). The anchoring architecture does not depend on it.

IO can implement a **dedicated endpoint** to ingest data from BillAI into IO.

BillAI is external (Measurabl side). It sends a Measurabl-domain payload. The endpoint parses that payload, maps it to IO entities (portfolios, deals, data-room files), and calls existing internal services. The route lives on an existing service — not a new microservice.

**Restrictions**

- BillAI does not call generic Public API v2 writes (`/v2/portfolios`, `/v2/deals`, upload-file, and similar).
- Do not reuse `POST /input/create-client` (Musoni/JSA). Measurabl needs its own contract.
- BillAI does not call internal IAM, Data Room, or Hub routes; those are dispatched by the ingest endpoint.

## D2. Anchoring enters IO only through the Data Room

**Status:** Accepted  
**Date:** 2026-09-06

In the [Aug 17 high-level architecture](msr-io-integration-high-level-architecture-aug-17.md), two flows reach the Inveniam Anchoring API:

- **Step 7** — Data Room → Anchoring API (document provenance). **This flow stands.**
- **Step 17** — Measurabl Anchoring service → Anchoring API ("Only the root leaves"). **There will be no such flow.**

The only path into Inveniam anchoring is the Data Room. Measurabl-side components do not call the Anchoring API directly.

**Consequences**

- Structured-data (Merkle-root) anchoring of Measurabl records into the Inveniam chain is not part of the integration. The Measurabl-side Anchoring service, manifest store and proof library (Aug 17 steps 14–17, 20) are outside IO's scope.
- The Aug 17 diagram is superseded on this point only. Its remaining content stays a discussion artifact.

## D3. Data residency — files stay on the Measurabl side

**Status:** Accepted  
**Date:** 2026-09-06

Measurabl remains the home of BillAI documents. IO does not become a storage location for them.

IO may hold a copy of a file for as long as it needs to process it, and drops that copy afterwards. What IO keeps is the file record — checksum and metadata — not the bytes.

This confirms the [Aug 17](msr-io-integration-high-level-architecture-aug-17.md) position (*"No bytes leave Measurabl's infrastructure"*; *"IO keeps the checksum and the metadata, not the bytes"*) as a decision, with the clarification that a transient processing copy inside IO is allowed.

**Consequences**

- The document-processing flow registers files against a deal's data room; IO is not a durable upload target. A file record with a checksum and a pointer to the Measurabl-side file is the durable artifact.
- Anchoring works off the checksum, so the D2 path (Data Room → Hub) is unaffected.
- Retention and purge mechanics are implementation work: how long a processing copy lives and what deletes it. Data Room has no retention policy today.

## D4. A Measurabl client is a top-level portfolio

**Status:** Accepted  
**Date:** 2026-09-06

Measurabl is structured as one organisation where clients are represented as **top-level portfolios**, created lazily on first ingest. Any complex structures within a client are handled via sub-portfolios.

Confirmed by Patrick Sprouse (Inveniam), recorded in the [2026-09-04 notes](measurabl-integration-next-steps-2026-09-04.md) (00:01:27).

**Consequences**

- The document-processing flow resolves the organisation resource before creating a client portfolio, because IAM's folder create requires a parent.
- The Measurabl client id → top-level portfolio id pair anchors the mapping store: a duplicate top-level portfolio for one client means two IO hierarchies, and per the [signer research](../interim-research-docs/io-per-client-signer-multi-org-vs-multi-identity.md) two on-chain identities.
- "Hub keys at portfolio level" refers to this top-level portfolio. Wallet funding stays open.
- Under [D6](#d6-per-client-on-chain-signer--one-hub-identity-per-measurabl-client), the top-level portfolio id is also the key of the client's Hub identity. A duplicate top-level portfolio for one client therefore means two on-chain identities, so Sentinel's (document-processing team) client-id → portfolio mapping must be unique per Measurabl client.

## D5. Ingestion is out of scope for anchoring — anchoring is triggered from regular Data Room ingestion

**Status:** Accepted  
**Date:** 2026-09-08  
**Relation to D1:** D1 stays as recorded; its implementation (whether a dedicated endpoint, an existing ingestion point, or something else) belongs to Sentinel (document-processing team).

Two teams work on the Measurabl integration inside IO:

- **Sentinel — document-processing team** — receives Measurabl documents, processes them with a dedicated **Docugami processing provider**, and creates the IO entities (portfolios, deals, data rooms, file records) through the internal Deal and Data Room APIs. How documents enter IO — a dedicated endpoint per D1, an existing ingestion point, or otherwise — is their decision and **out of scope** for Keystone.
- **Keystone — anchoring team (this doc set)** — makes sure that every document a Measurabl organisation holds in a data room is anchored on NVNM through the Hub.

The contract between the two is the **data room**: once Sentinel has put a file record into a deal's data room, it is an ordinary data-room file, and anchoring is driven from there ([D2](#d2-anchoring-enters-io-only-through-the-data-room) path). The anchoring architecture depends on nothing about how the file got there.

**What follows from this**

- Anchoring is not requested by any caller. IO decides on its own: when a data-room file receives its checksum and that file's deal belongs to a Measurabl organisation, IO anchors it. No API call, header or payload field asks for anchoring, so Sentinel does not have to call anything for it.
- Everything anchoring needs — deal id, organisation id, top-level portfolio id, checksum, document URI, NVNM registry id — is collected from inside IO (data-room, deals, IAM), not from an external payload. See [Measurabl document anchoring — What anchoring needs](../measurabl-anchoring-embedded-in-existing-services.md#what-anchoring-needs-and-where-io-already-has-it).
- Processing is lazy: an event-driven fast path plus a scheduled reconciliation pass, so a document whose deal is not yet registered on NVNM is anchored later rather than failed. See [D7](#d7-anchoring-processor-is-embedded-in-existing-services-no-new-microservice).
- The D1 restrictions on what BillAI may call are unchanged and remain Sentinel's to enforce, together with [D3](#d3-data-residency--files-stay-on-the-measurabl-side) and [D4](#d4-a-measurabl-client-is-a-top-level-portfolio).

**Interface with Sentinel (document-processing team)** (prerequisites the anchoring path relies on, recorded here so they are not lost)

1. One Measurabl client → exactly one top-level portfolio, and that mapping is stable (D4).
2. Every Measurabl deal is **activated** (or its tokenization bootstrap is otherwise triggered), because the deal's NVNM registry is created by the existing `DealActivatedEvent` → tokenization-bootstrap path in deals-service. A deal that never activates never gets a registry and its files are never anchored.
3. Files land in the deal's data room as normal file records so that checksum calculation runs.

## D6. Per-client on-chain signer — one Hub identity per Measurabl client

**Status:** Accepted  
**Date:** 2026-09-08

Option 2 of [IO side: per-client on-chain signer](../interim-research-docs/io-per-client-signer-multi-org-vs-multi-identity.md#option-2-one-hub-identity-per-measurabl-client) is chosen: Measurabl is **one Hub organisation** with **one credential set**, and each Measurabl client (top-level portfolio, D4) is a **Hub identity with its own NVNM wallet** inside that organisation. Every Hub write for a client carries that identity's `userEmail`, so the chain `from` address is client-specific.

**Details fixed by this decision**

- Identity address is synthetic and derived from the top-level portfolio id: `measurabl-client-<top-level-portfolio-uuid>@<inveniam-controlled-domain>`. Never a Measurabl or client mailbox.
- Provisioning is lazy and idempotent, done by IO on first write for a client, using a Hub admin credential (personal HubJWT) that IO holds for the Measurabl Hub organisation. Two Hub admin calls per client: create user, create identity wallet (NVNM).
- Verify at provisioning: `GET /ledgers/get-wallet-info?userEmail=` must resolve to an address different from the Measurabl org wallet.
- **Fail closed.** If the signer cannot be resolved for a write that is subject to this policy, the write does not happen and the anchor is marked failed for retry. A Measurabl document is never signed by the shared org wallet.
- Applies to **all** Hub writes for a Measurabl client, not only `SyncDocument`: the deal's NVNM `Register` transaction should be signed by the same client identity so the registry is attributed to the client too (see OQ in the architecture doc on whether NVNM requires registry creator = record writer).

**Rejected:** one Hub organisation per client (Option 1) — mints and stores a fresh ServiceJWT per client at request time, needs Hub system-admin privilege on an unattended path, and requires Vault-path and ledger-resolution changes in hub-service.

## D7. Anchoring processor is embedded in existing services; no new microservice

**Status:** Proposed  
**Date:** 2026-09-08

The Measurabl anchoring logic is split along existing service boundaries rather than placed in a new service:

| Concern | Service | Why there |
| --- | --- | --- |
| Detect "file is anchorable", build the anchor request, own the anchor record and its status, reconcile/retry | **data-room-service** | Already has the hook (`FDRAutoSyncInitEvent` fires when a checksum lands on a linked file), the anchor entity (`Taxonomy`), the outbound event (`HubDocumentSyncingRequestedEvent`), the status feedback loop, and a scheduler-driven maintenance pattern (`FDRRelinkFileRequestedEvent`) |
| Which organisations are Measurabl / auto-anchored, and each deal's NVNM registry id (`symbol`) | **deals-service** | Owns `organisation_integration_settings` and `deal_integration_settings`; already provisions the per-deal NVNM registry lazily via the tokenization-bootstrap batch queue |
| Signer resolution, lazy Hub identity provisioning, Hub admin credential, identity ↔ portfolio record | **hub-service** | Only service with the Hub HTTP client, Hub credentials and Vault access; keeps the Hub admin credential out of data-room |

**Why not a new microservice.** A separate "Measurabl anchoring" service would still have to subscribe to data-room file events, read data-room and deals state, and call hub-service — it would own no data of its own and add a deployment, a database and a set of cross-service reads for logic that is a few hundred lines spread over three existing modules. The deployment overhead is not justified.

**Lazy processing.** Fast path: event-driven, immediately after the checksum lands. Backstop: a scheduled reconciliation pass (scheduler-service cron → event → data-room command) that re-requests anchoring for Measurabl-org files whose latest NVNM anchor is missing or failed and whose deal now has a registry id. There is no per-request Hub call on the ingest path and no synchronous dependency on Hub availability.

Details and the concrete change list: [Measurabl document anchoring — embedded in existing services](../measurabl-anchoring-embedded-in-existing-services.md).
