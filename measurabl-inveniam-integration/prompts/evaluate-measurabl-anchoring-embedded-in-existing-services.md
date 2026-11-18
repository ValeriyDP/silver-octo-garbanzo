# Task: audit an integration diagram doc for source fidelity AND architectural feasibility

You are reviewing a working architecture document on two axes: (a) does it faithfully
represent what was decided, and (b) would the architecture it depicts actually work against
the real codebase. This is an audit, not a rewrite. Be adversarial on both axes. The author
wrote the doc from memory of a meeting plus partial repo spelunking, so the risks are
invented decisions on one side and a diagram that cannot be built as drawn on the other.

## Artifacts

**Document under review**
`..`
A Mermaid-based ingest architecture doc describing how BillAI (external, Measurabl side)
calls Inveniam IO via a single dedicated ingest endpoint with lazy provisioning.

**Ground truth for decisions — `..`**

Read every file in this folder. Do not treat the PNG as a standalone picture.

1. `architectural-decisions.md` — working list of **accepted** architectural
   decisions and restrictions (not a full ADR log). As of this prompt, **D1** (2026-09-06)
   accepts a dedicated BillAI ingest endpoint on an existing service, with explicit
   restrictions on what BillAI must not call. Treat each `Status: Accepted` item as
   settled unless a later source explicitly supersedes it. Treat missing IDs as *not*
   decided — do not infer extra ADRs from the ingest architecture doc.

2. `measurabl-integration-next-steps-2026-09-04.md` — Gemini meeting notes from the
   2026-09-04 architecture call, with Summary / Decisions (split into "Needs Further
   Discussion" and "Aligned") / Next steps / Details. The Details section has per-topic
   attributions and timestamps. Use this for lazy onboarding, mapping, Hub placement,
   no-new-microservice, delete/update out of scope, mainnet, and open items that D1
   does not cover.

3. `msr-io-integration-high-level-architecture-aug-17.md` **together with**
   `MSR-IO integration — high-level architecture (Aug 17).png` — the Aug 17 high-level
   architecture. **You must read both.** The markdown is the architect's framing, not
   caption filler. Use it for: purpose (how data gets **anchored** — structured and
   unstructured — and how data gets **extracted with DGML**); status (**discussion
   artifact — not final, not a commitment**); and the warning that the picture is a
   **deliberate simplification** of only the parts related to MSR ↔ IO. Then **open
   and read the PNG**. Start from the “How to read this” blocks as the architect
   instructed. Extract actors, swimlanes, data flows (ingest vs extract), anchoring
   paths, DGML/extraction, storage, and any BillAI / IO / chain components.

   This pair **predates** the 2026-09-04 meeting and D1. Where it conflicts with later
   accepted decisions or meeting alignment, later sources win — but **call out every
   conflict**, because a silent drop (for example DGML extraction, structured vs
   unstructured anchoring, extra components) may be an unrecorded decision rather than
   an intentional narrowing of the Measurabl ingest slice.

**Secondary — `..`**
Repo research the author did, not decisions:
`v2-portfolios-and-deals-create-flows.md`, `io-per-client-signer-multi-org-vs-multi-identity.md`,
`generated-on-hub-repo-context-application-multi-org-vs-multi-identity.md`.
Treat these as a starting point that may itself be wrong or stale — verify their claims
against code before relying on them.

**Ground truth for feasibility — the codebase**
An Nx/Lerna TypeScript monorepo. Services live under `../../../apps`, shared code under
`shared-modules/` and `shared-packages/`, deployment under `helm/` and `docker-compose.yml`.
The services the document names map to `apps/iam-service`, `apps/organisations-service`,
`apps/deals-service`, `apps/data-room-service`, `apps/hub-service`,
`apps/metachain-service`, and `apps/dataio-service` (whose `src/` contains `auth`,
`data-inputs`, `integrations`, `public-api`, `v2-api-docs`). Other services exist that the
document does not mention — including `automated-workflow-service`, `workflows-service`,
`batch-processing-service`, `notifications-service`, `tasks-service`, `scheduler-service`,
`relay-service`, and `websockets-service` — and part of your job is deciding whether any of
them belong in the picture.

Also use the Aug 17 architecture (markdown + PNG) as a **feasibility and completeness
checklist**: if that vision requires DGML extraction, structured-data anchoring, or
components the ingest architecture diagrams omit, say whether the omission is a
legitimate slice (ingest-only) or a hole that makes the integration incomplete relative
to the stated goal of the Aug 17 artifact.

**Token discipline — Graphify (codebase navigation only)**
A knowledge graph already exists at `../../../graphify-out` (including `graph.json`). For
**Part B** and any other question about how the repo is structured — who owns a
create path, what calls what, where auth/timeouts/side effects live — follow the
**Graphify skill** (`graphify`) and query that graph **before** opening files at
random. The graph is a map; it is not a substitute for reading source.

Do this:
- Treat architecture / call-path / “how does X work” questions as Graphify queries
  first. Use the skill’s fast path: `graphify query "…"`, and `graphify path` /
  `graphify explain` when tracing two named symbols or a single node. Prefer a
  tight `--budget` so answers stay small.
- Use hits to **choose which files to open**. Then cite `file:line` from those
  files. Code still wins over the graph, research docs, and diagrams.
- Do **not** rebuild the graph, ingest `graph.json` / `GRAPH_REPORT.md` wholesale,
  or dump community reports into context.

Do **not** use Graphify for **Part A** decision fidelity. Decisions come only from
`..` (precedence below). The graph cannot
ratify what was agreed in a meeting.

## Precedence

For **decision** questions (what was agreed, what is in scope, what BillAI may call):
1. `architectural-decisions.md` items with **Status: Accepted** (currently D1).
2. 2026-09-04 meeting notes — Aligned vs Needs Further Discussion vs one-person preference.
3. Aug 17 markdown + PNG as **prior vision / discussion**, not a commitment.
4. Nothing else. Research docs and code cannot ratify a decision.

For **mechanism and feasibility** questions (what the system does, what is buildable):
1. the code, 2. the research docs, 3. the diagrams. Code always wins. Where a decision
requires something the code makes hard or impossible, that is a finding, not a
contradiction to resolve in favour of either side — report the gap and its cost.

If D1, the meeting notes, and the ingest architecture doc disagree, quote all three. D1 wins
for the dedicated-endpoint contract; the notes still govern mapping, Hub, lazy create,
and open questions D1 does not mention.

## Part A — source fidelity

Work claim by claim, not section by section.

1. **Traceability.** Take every substantive assertion — each row of the domain-mapping table,
   each node and edge in both Mermaid diagrams, each numbered behaviour of the dedicated
   endpoint, each row of the "BillAI must not call" table, the auth sentence, the Hub-scoping
   sentence, the out-of-scope sentence — and classify it:
   - **Supported** — quote the exact supporting line (prefer D1 or meeting notes), or
     describe the exact element of the Aug 17 PNG **and** any matching architect text
     in `msr-io-integration-high-level-architecture-aug-17.md`.
   - **Unsupported but plausible** — no source says this; it is author inference. Say what
     would confirm it.
   - **Contradicted** — quote both sides.
   - **Overstated** — the source marks it open, pending, discussion-only, or
     preferred-by-one-person, but the document states it as settled. Highest-value
     failure mode: the notes separate "Aligned" from "Needs Further Discussion"; the
     Aug 17 write-up is explicitly **not a commitment**.

2. **D1 coverage.** Confirm the ingest architecture doc matches D1 (dedicated ingest, Measurabl
   domain payload, map to IO entities, existing service not a new microservice, and the
   three restrictions). Flag any D1 restriction missing from the doc, any extra restriction
   the doc invents, and any wording that is stronger or weaker than D1.

3. **Omissions.** What is in the sources but missing from the document?
   - Every "Aligned" decision and "Needs Further Discussion" item in the notes.
   - Every Details bullet that changes the architecture picture.
   - Aug 17 architect intent: structured **and** unstructured anchoring, DGML extraction,
     and any PNG flows (ingest vs extract, extra systems) the ingest architecture doc dropped without
     saying it is a narrower slice.
   - D1 items not reflected in the Mermaid (not only in the prose table).

4. **Open questions.** Are the document's six open questions the right six? Flag any the
   sources already answer (including D1), and any unresolved item that never surfaced.
   Do not treat Aug 17 discussion content as closing an open question.

5. **Domain mapping fidelity.** The mapping (Measurabl tenant → organisation, client →
   top-level portfolio, client portfolio → nested portfolio, files-and-folders → deal + 1:1
   data room, hub keys → portfolio-else-organisation) is the core of the doc. Verify each
   arrow against the Details bullets specifically, including who asserted it and whether it
   was externally confirmed. Check whether Aug 17 uses the same entity names or a different
   model.

6. **Scope discipline.** Confirm the delete/update and no-new-microservice exclusions against
   D1 and the notes. Flag anywhere the document has quietly expanded scope, or anywhere it
   presents Aug 17 vision as if it were accepted.

## Part B — architectural correctness and feasibility

Navigate via the Graphify skill and `../../../graphify-out` first (see **Token discipline**
above), then read the cited source. Do not infer service behaviour from service names
or from the research docs. Cite `file:line` for every claim you make about how the
system works.

Also read the Aug 17 PNG and markdown as an architectural **hypothesis** to test: does
today's code support the anchoring + DGML extraction story, and does the
ingest architecture diagram's ingest slice still connect to that story?

7. **Component and ownership accuracy.** For each box in the ingest flowchart, confirm the
   named component exists and actually owns the responsibility the diagram assigns it. In
   particular: the diagram routes portfolio, nested-portfolio, and deal creation through IAM,
   with IAM then fanning out to Organisations and Deals. Verify against the code who really
   owns portfolio creation, nested-portfolio creation, and deal creation, and whether IAM is
   an orchestrator, an authorisation gate, or neither. If the boxes are drawn at inconsistent
   levels of abstraction (service vs. domain vs. capability), say so. Cross-check named
   components against the Aug 17 PNG (different names for the same thing vs. missing vs.
   extra).

8. **Edge validity.** For every arrow in both Mermaid diagrams, determine whether that call
   path exists or could exist: is the transport HTTP, an internal client, an event, a queue?
   What authentication does the callee require from an internal caller, and can the ingest
   handler satisfy it? Flag edges that assert a dependency direction the codebase forbids,
   that cross a boundary with no existing mechanism, or that would introduce a cycle. Pay
   specific attention to the anchoring path: the flowchart draws both `dr → meta → nvm` and
   `hub → nvm`, while the sequence diagram draws `DR → Hub → NVM`. Determine the real
   anchoring/publish flow in code **and** how Aug 17 draws structured vs unstructured
   anchoring. Say which depiction is right.

9. **Feasibility of lazy creation.** The whole design rests on "lazy-create only missing
   entities," idempotently. Check the code for what makes this hard:
   - What stable external identifier can be persisted to make a repeat request a no-op? Do
     the relevant entities have a field for a foreign/source id, or would this need a schema
     change and migration?
   - What happens on concurrent first requests for the same client? Are there unique
     constraints, or would you get duplicate portfolios?
   - Multi-step creation across several services has no distributed transaction. What is the
     partial-failure story — orphaned portfolio with no deal, deal with no data room — and
     does any existing code in this repo (saga, outbox, compensating delete, retry) provide a
     pattern to follow?

10. **Feasibility of the data room step.** The diagram creates a data room 1:1 with each deal
    inside the request. The meeting notes say rooms need end-user-supplied AWS or Google keys.
    Read `../../../apps/data-room-service` and determine what room creation actually requires, whether
    it can succeed without per-room storage credentials, and whether it is synchronous. If it
    cannot complete unattended, the sequence diagram is not buildable as drawn — say so
    plainly and describe what the real sequence would have to look like.

11. **Feasibility of the Hub step.** The document concedes Hub ledgers are organisation-scoped
    today and that portfolio-first-with-org-fallback is "implementation work." Read
    `../../../apps/hub-service` and quantify that: what changes — data model, API, key management,
    wallet handling — and is it a small addition or a redesign? Also assess the master-wallet
    versus per-client-wallet question against what the code currently supports on mainnet.

12. **Endpoint placement and auth.** Verify the claim that dataio is the right host, using
    `../../../apps/dataio-service/src` (`public-api`, `data-inputs`, `integrations`, `auth`) and the
    cited `POST /input/create-client` precedent. D1 forbids reusing that route; confirm the
    code agrees it is Musoni/JSA-specific. Does dataio have existing outbound clients to
    IAM, Deals, Data Room, and Hub, or would those be new dependencies? Confirm the auth flow
    (`GET /v2/api-keys/auth/token`, `GET /v2/dataio/api-key/token`) exists as described and
    that the resulting token can authorise the internal fan-out. Confirm the "BillAI must not
    call" table matches D1 and is accurate about what each listed surface does today,
    including whether Public API v1 is genuinely read-only.

13. **Missing machinery.** Entity creation in this codebase likely has side effects the
    diagram ignores. Check whether creating a portfolio, deal, or data room normally triggers
    permissions/role assignment, workflow instantiation, notifications, search indexing, or
    audit events — and whether any of that assumes a human user, which Measurabl explicitly
    will not have. Any such requirement is a hole in the diagram.

    Separately: if Aug 17 requires DGML / extraction / structured anchoring after ingest,
    check whether those pipelines exist and whether the BillAI ingest path can feed them
    without extra undocumented steps.

14. **Runtime shape.** The sequence diagram implies one synchronous request doing
    authentication, mapping, up to four creates, file storage, and a mainnet transaction.
    Assess whether that fits within realistic request timeouts and what the failure mode is
    when the chain is slow, using whatever timeout, retry, and async-job patterns exist in
    the repo. If the design should be split into a fast ack plus asynchronous processing,
    say so and point at the existing mechanism that would carry it.

15. **Where it breaks first.** Given everything above, name the single change most likely to
    be underestimated, and rank the remaining work by risk.

## Output

Lead with a one-paragraph verdict covering both axes: is this document safe to send to
Measurabl as a confirmation request, and is the architecture it depicts buildable
substantially as drawn. Name the single most consequential problem.

Then:

- **Fidelity findings** — numbered, ordered by severity (Critical / Major / Minor). For each:
  exact quoted text from the document, the classification from check 1, the quoted source
  text with file name and section (D1, meeting notes, or Aug 17 markdown/PNG), and a
  concrete suggested rewording.
- **Feasibility findings** — same structure, but evidence is `file:line` code citations,
  plus Aug 17 PNG/markdown where the gap is "ingest slice vs full integration vision."
  For each, state whether the diagram is *wrong* (depicts something that does not exist),
  *incomplete* (omits a required step), or *optimistic* (buildable but materially more work
  than implied).
- **Corrected architecture** — where the diagram is wrong about component ownership or call
  paths, give the corrected Mermaid for just the affected portion, with code citations
  justifying each changed edge.
- **Missing from the document** — sourced or code-evident content that should be there,
  including D1, meeting alignment, and Aug 17 goals the author silently dropped.
- **Unsourced claims** — assertions with no basis in any artifact or in code.
- **Suggested edits** — precise before/after text. Do not rewrite the whole document.

Distinguish throughout between "this is wrong," "no source covers this," "this is
discussion-only (Aug 17)," and "this is technically possible but harder than the document
implies." Conflating them is not useful. Do not pad any list; a short list of real findings
beats a long one with filler.
