# Resolution tracker: `measurabl-anchoring-embedded-in-existing-services.md` evaluation (2026-09-06)

**Last updated:** 2026-09-06

Tracks how each finding of the [2026-09-06 evaluation](measurabl-ingest-architecture-evaluation-2026-09-06.md) is being addressed in [`measurabl-anchoring-embedded-in-existing-services.md`](../measurabl-anchoring-embedded-in-existing-services.md). The evaluation itself is frozen — it is the audit record. This file is the only place where resolution status is updated.

Status values: **Resolved** (doc changed, finding no longer applies) · **Open** (not yet addressed) · **Blocked** (needs a decision or Measurabl input before the doc can change) · **Won't fix** (finding accepted as-is, with a reason).

## Fidelity findings

| # | Finding | Status | Resolution |
| --- | --- | --- | --- |
| F1 | Critical — file bytes into the IO data room contradicts the Aug 17 "no bytes leave Measurabl" rule | **Resolved** | Residency decided as D3 (files stay at Measurabl; IO copies are transient). See below |
| F2 | Critical — Aug 17 scope (DGML extraction, results back to BillAI) dropped without saying so; D2 not cited | **Resolved** | See below |
| F3 | Major — files-and-folders → deal (+ room 1:1) stated as settled; notes mark the trigger as open | **Resolved** | The 1:1 stays settled (it always was supported); only the deal-forming unit is marked open. See below |
| F4 | Major — wallet per portfolio stated as settled; master vs per-client wallet is open | **Resolved** | The corrected sequence dropped the "ensure ledger + wallet, portfolio first" step, the Hub paragraph surfaces the master-wallet tension (F-B7 pass), and the mapping row now marks portfolio-else-org as a PRD position with the Hub-side model and wallet funding open (OQ5) |
| F5 | Major — "likely dataio" contradicts the notes' only placement hint (document-upload service) | **Resolved** | Fixed as a side effect of F-B8: the prose no longer calls dataio the intended shape, names data-room (the document-upload service) as the notes' example, and OQ1 says neither is decided |
| F6 | Minor — source attribution omits D1/D2 and misdates the dedicated-endpoint decision | **Resolved** | `Last updated` is 2026-09-06 and the line now cites D1, D2 and D3 (all accepted 2026-09-06) plus the notes, and states that the single dedicated endpoint comes from D1 rather than the notes |
| F7 | Minor — "one client-specific endpoint" / "behaviour is fixed" stronger than D1's permissive wording | **Resolved** | Intro says "will expose one dedicated endpoint (D1)"; the endpoint section says path and payload are open and the behaviour is *intended*, not fixed |
| F8 | Minor — "BillAI must not call" adds a Public API v1 restriction D1 does not contain | **Resolved** | Row kept but marked as not a D1 restriction, and "Read-only" replaced with "query-only surface — a few `POST` routes exist but they are reads" |
| F9 | Minor — "Measurabl client portfolio" is an entity name no source defines | **Resolved** | Mapping row, endpoint behaviour 1, OQ2 and OQ3 now say "sub-structure under a client (term TBC)", matching the flowchart; OQ2 asks Measurabl for the real name. Line 25 keeps "client portfolio" because it paraphrases Valeriy's Hub model |
| F10 | Minor — chain named `NVM`; sources and code say `NVNM` | **Resolved** | Both mentions lived in the diagrams and are now `NVNM mainnet` |

## Feasibility findings

| # | Finding | Status | Resolution |
| --- | --- | --- | --- |
| F-B1 | Wrong — IAM creates return `201` with no id, so the synchronous create-under-create chain cannot be built | **Resolved in the doc** | Diagrams label the creates `201, no id` and show ids arriving by event; *Ids and idempotency* states the constraint and the three ways out. The IAM-side work itself is still to do |
| F-B2 | Wrong — flowchart edges `iam → orgs`, `deals → dr`, `dr → meta → nvm` have no mechanism | **Resolved** | All three edges and the Organisations/Metachain boxes removed, with a note saying why |
| F-B3 | Wrong — IAM → Deals is an asynchronous event and deal creation is two-phase | **Resolved** | Now `iam -.-> deals` (`DealResourceCreatedEvent`) and `deals -.-> iam` (`DealCreatedOnHierarchyEvent`) |
| F-B4 | Optimistic — lazy creation has no idempotency key, no unique constraints, no compensation | **Resolved in the doc** | *Ids and idempotency* + *Concurrency and partial failure* cover the missing source-id column, the three missing constraints, the cross-tenant deal-title check, the absent compensation, and the patterns to follow |
| F-B5 | Optimistic — room creation is two calls plus context resolution, not one | **Resolved** | Sequence shows `create/:dealId`, `connect/:roomId` and the default-folder event separately; *Data room and storage* adds the permission/context prerequisites, and OQ4 is now "default S3 vs Measurabl-owned storage" instead of "who supplies keys" |
| F-B6 | Incomplete — anchoring is caller-initiated after a background checksum, not an automatic synchronous tail | **Resolved** | Sequence shows checksum stored, then `POST taxonomy/create-request/:fileId`, then the Hub event and a `Succeeded / Failed` reply; *Anchoring* states that nothing anchors on upload and that the chain payload carries no per-client attribution |
| F-B7 | Optimistic — portfolio-first Hub keys are a redesign of Hub credential handling | **Resolved in the doc** | The Hub paragraph now describes a new provisioning subsystem (admin client, credential path, `portfolioId` threading, or the identity variant) and notes that a master wallet is today's behaviour at the cost of attribution |
| F-B8 | Optimistic — dataio is a weaker host than implied; the cited precedent dispatches by event | **Resolved** | Precedent prose rewritten as event + `automated-workflow-service` flow; host paragraph lists dataio's missing write clients and direct DB reads, and notes v2 writes are IAM routes |
| F-B9 | Optimistic — API-key JWT identity is a token id; permissions are resource-scoped | **Resolved in the doc** | *Auth for a non-human caller* covers the token-id identity, per-resource permission checks, unverified role inheritance, and read-only M2M keys |
| F-B10 | Incomplete — creation side effects that assume a human user | **Resolved in the doc** | *Per-entity prerequisites* covers `dealTypeId`, org Mongo credentials, favourites keyed to a token id, and what does **not** fire; *No DGML in the repo* records the missing extraction pipeline |
| F-B11 | Wrong — one synchronous request cannot span creates, upload, checksum and a mainnet write | **Resolved** | Sequence is `202 + correlation id` up front, flow-driven behind it, with an optional status read; OQ6 reworded to match |

F-B12 ("where it breaks first") is the evaluation's risk ranking, not a separate defect; it is resolved when F-B1, F-B4 and F-B11 are.

"Resolved in the doc" means the document no longer misrepresents what the code does — the engineering work the finding exposes is still ahead. F-B1, F-B4, F-B7, F-B9 and F-B10 are of that kind, and F-B12's risk ranking still stands as the order to tackle them in.

## F1 — Resolved 2026-09-06

Residency is **not** an open question. Files stay on the Measurabl side; IO may hold a copy while it processes a file and drops it afterwards, keeping only the file record (checksum and metadata). This was recorded as **[D3](../reference-docs/architectural-decisions.md#d3-data-residency--files-stay-on-the-measurabl-side)** (Accepted 2026-09-06), which confirms the Aug 17 position with the clarification that a transient processing copy inside IO is allowed. The evaluation's F1 premise — *"no later source resolves it"* — is therefore superseded; the evaluation text stays frozen as written on 2026-09-06.

Changes in [`measurabl-anchoring-embedded-in-existing-services.md`](../measurabl-anchoring-embedded-in-existing-services.md):

- **Domain mapping** — row `Files / JSON in the payload | Data-room documents` → `Files referenced by BillAI | Data-room file records (checksum + metadata)`, citing D3.
- **Data residency paragraph** added under the mapping table, stating the model in one place instead of leaving it implicit in a diagram label.
- **Sequence diagram** — step `Ingest->>DR: Store files / JSON from payload` → `Register file (checksum + metadata); file stays at Measurabl; any IO copy is transient and dropped (D3)`.
- **Open questions** — OQ7 is **Retention mechanics**, not residency: how a file is handed over for processing, how long IO may hold it, and what drops it.
- `Last updated` bumped to 2026-09-06 (partially addresses F6; the `Source:` line still needs to cite D1–D3).

Not changed: the flowchart `ingest --> dr` edge carries no label and makes no residency claim. Anchoring steps were left alone — they belong to F-B6 and F-B11. Anchoring is unaffected by D3 because it works off the checksum.

**Follow-up (implementation, tracked under OQ7):** `POST :roomId/folder/:folderId/link-file` (`fileName` + `espPointer`, `apps/data-room-service/src/data-room/data-room.controller.ts:714`) is the existing route shape that registers a file IO does not own, so the ingest path has a precedent to build on. Purging a processing copy has no mechanism today: the delete route is permission-gated and user-scoped (`data-room.controller.ts:1021`, `PermissionsV2Enum.FDRDeleteBasic`, takes `req.user.userId`), and Data Room has no retention or TTL policy — which also intersects F-B10 (side effects that assume a human user).

## F2 — Resolved 2026-09-06

The doc now says out loud that it is a narrower slice of the Aug 17 vision, and separates the flow that was dropped **by decision** from the one that is simply **not decided**.

Change in [`measurabl-anchoring-embedded-in-existing-services.md`](../measurabl-anchoring-embedded-in-existing-services.md): a **Scope** block after the intro, stating that this is the ingest slice (create IO entities, register files, anchor via the Data Room), followed by the two deliberate absences:

- **Structured (Merkle-root) anchoring** — dropped by decision, citing [D2](../reference-docs/architectural-decisions.md#d2-anchoring-enters-io-only-through-the-data-room): Aug 17 step 17 will not exist, step 7 stands. This also gives D2 its first citation in the doc, which the evaluation's D1 coverage table flagged as missing.
- **DGML extraction and results flowing back to BillAI** (Aug 17 steps 4–10) — not covered and not decided, with an explicit note that Measurabl should not read the doc as a commitment that extraction results come back. The evaluation's point that the Aug 17 door is bidirectional while this one is one-way is stated in the doc.

Deviation from the suggested rewording: data residency is no longer in the "not decided" list, because D3 settled it (see F1).

**Still open after this fix:** whether ingest-only is an accepted scope for the integration, or just what this doc happens to cover. No source narrows the Aug 17 extraction goal, so the doc marks it undecided rather than out of scope. If the team has in fact decided the slice, record it as a decision in [`architectural-decisions.md`](../reference-docs/architectural-decisions.md) and the Scope block can then cite it instead.

## Corrected architecture applied 2026-09-06

Both Mermaid diagrams in [`measurabl-anchoring-embedded-in-existing-services.md`](../measurabl-anchoring-embedded-in-existing-services.md) were replaced with the evaluation's *Corrected architecture (affected portions only)* section. This clears F-B2, F-B3, F-B5, F-B6, F-B11 and F10, and moves F-B1 into "depicted correctly, still to build". See the tables above for what each finding's status now is.

Applied as written, with one adjustment for the F1 outcome:

- `Flow->>DR: upload-file or link-file (bytes vs pointer — OQ7)` → `Flow->>DR: link-file (Measurabl-side pointer) or transient upload / file stays at Measurabl (D3), retention OQ7`. The original label treated residency as the open question; D3 settled residency, and OQ7 is now retention mechanics.

Two prose lines were adjusted so the doc does not contradict its own diagrams:

- Endpoint behaviour 4 — "Fan out to existing internal APIs — IAM, Data Room, Hub" → dispatch through the event/flow mechanism, with Hub reached by the Data Room's anchoring event.
- OQ6 — reworded from "ack only vs created IO ids" to "the reply is a `202` + correlation id; open whether BillAI needs ids and whether it polls or wants a callback".

Two short explanatory lines were added that are not in the evaluation's Mermaid: a legend under the flowchart (dashed = event, solid = HTTP, plus which edges were removed and why) and a sentence under the sequence diagram stating the asynchronous shape. Both restate the evaluation's own justification text for readers who will not open this tracker.

**Side effects to be aware of:** the diagrams now use F9's "sub-structure" wording and dropped F4's wallet-provisioning step, while the mapping table still carries the old wording for both — those rows are fixed under F4 and F9. The host contradiction this introduced (flowchart "TBD" vs prose "likely dataio") was closed in the feasibility pass below.

## Feasibility findings applied 2026-09-06

The remaining feasibility findings were closed by making the document state what the code actually does. Two paragraphs were rewritten and one section was added.

**Rewritten prose:**

- **Precedent and host (F-B8, and F5 with it).** `POST /input/create-client` is now described as it works — one external body, `CreateClientRequestedEvent`, then `automated-workflow-service` driving deal → room → S3 → folders → files — with the note that the flow shape is what to copy, not a synchronous fan-out. The host paragraph names data-room as the notes' example, keeps dataio as the alternative, and lists what dataio lacks: no write clients to IAM, Deals or Hub, a read-only data-room client, direct database reads, and v2 writes that are really IAM routes. OQ1 now says neither host is decided.
- **Hub (F-B7).** "Still implementation work" became a description of the actual gap: credentials keyed per organisation in Vault, ledger resolution by `organisationId`, no `portfolioId` anywhere in hub-service, no organisation/connection-profile/wallet client, admin-entered credentials — therefore a new provisioning subsystem, or the one-credential-set-plus-identity variant. It also records that a master wallet is today's behaviour and costs per-client attribution, which is the tension the notes left open.

**New section — *IO-side implementation notes*** (internal, before the open questions), with one paragraph per finding: *Ids and idempotency* (F-B1, F-B4), *Concurrency and partial failure* (F-B4), *Data room and storage* (F-B5), *Anchoring* (F-B6), *Auth for a non-human caller* (F-B9), *Per-entity prerequisites* (F-B10), *No DGML in the repo* (F-B10, and the code-side reason behind the F2 scope statement).

**Open question reworded:** OQ4 was "who supplies AWS / Google keys for each room", which the evaluation showed is over-general — room creation and default-S3 connect need no credentials. It now asks whether storage is Inveniam-default S3 or Measurabl-owned storage as a customer provider.

**What this pass does not do:** it does not build anything. The mapping store, IAM id path, uniqueness constraints, compensation, Hub provisioning subsystem, non-human permission model and status API are all still ahead, in F-B12's risk order.

## F3 — Resolved 2026-09-06

F3 bundled two claims together and only one of them was overstated. **Deal ↔ data room 1:1 is settled** and was already supported by the evaluation's own source — Valeriy, [notes](../reference-docs/measurabl-integration-next-steps-2026-09-04.md) 00:35:33: *"data rooms must still be provisioned, as they maintain a one-to-one relationship with deals"* — and it is confirmed as correct. So the doc keeps it as settled rather than hedging it.

What stays open is the **deal-forming unit**: no source defines what a Measurabl "files and folders" set is, and the notes list the trigger candidates as per client, per portfolio or per request.

Changes in [`measurabl-anchoring-embedded-in-existing-services.md`](../measurabl-anchoring-embedded-in-existing-services.md):

- Mapping row → `Measurabl client files and folders | Deal (proposed) + one data room per deal | A data room is 1:1 with a deal — settled (notes, 00:35:33). Which Measurabl unit becomes a deal is open (OQ3)`.
- OQ3 → **Deal-forming unit** ("a file/folder set, a client portfolio, or one per request"), noting that because the room is 1:1 with a deal, answering it also fixes when rooms are created. This replaces the old "data-room trigger" phrasing, which implied the room rule was independently open.

Not recorded as a decision: the 1:1 comes from the meeting notes, so the doc cites the notes. If you want it to carry the same weight as D1–D4, it can be added to [`architectural-decisions.md`](../reference-docs/architectural-decisions.md) and the row can cite that instead.

## D4 recorded 2026-09-06 — client placement

Not an evaluation finding. A review of whether the docs reflected "a Measurabl client is a top-level portfolio in the organisation" found the mapping present but thinly sourced: the row said only "Top-level portfolio / Lazy-created on first request", the strongest evidence was unused, nothing recorded it as a decision, and the code prerequisite for that placement was missing.

- **[D4](../reference-docs/architectural-decisions.md#d4-a-measurabl-client-is-a-top-level-portfolio)** added to `architectural-decisions.md` (Accepted 2026-09-06), worded to match the [notes](../reference-docs/measurabl-integration-next-steps-2026-09-04.md) (00:01:27): Measurabl is structured as one organisation where clients are represented as top-level portfolios, created lazily on first ingest, with complex structures within a client handled via sub-portfolios. Its consequences cover the organisation-resource lookup, the client id → top-level portfolio id pair as the mapping-store anchor, and what "Hub keys at portfolio level" refers to.
- **Mapping row** → `Measurabl client | Top-level portfolio | D4, confirmed by P. Sprouse (notes, 00:01:27). Lazy-created on first request`.
- **Sources line** now lists D4 alongside D1–D3.
- **New *Top-level placement* paragraph** in the implementation notes: IAM's folder create requires `parentId` and `parentTargetId` and resolves the parent inside the organisation, so a top-level portfolio is a folder parented to the organisation's `ORGANISATION` resource and the flow has to resolve that id first.

Left alone: the corrected diagrams state the creates generically (`create-folder / create-deal`, `alt portfolio / nested portfolio / deal missing`), so the level a client lands at is stated in the mapping table and D4 rather than in the Mermaid. Worth revisiting only if the diagrams are redrawn.
