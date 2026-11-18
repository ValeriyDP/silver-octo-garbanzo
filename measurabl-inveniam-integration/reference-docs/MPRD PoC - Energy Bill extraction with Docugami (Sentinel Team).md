# \[Internal document\] PoC \- Energy Bill extraction with Docugami \(Sentinel Team\)

# Energy Bill Extraction with Docugami POC

**Document type:** Master Product Requirements Document  
**Feature status:** Development / Phased Delivery  
**Product approver:** Daria Shynkarenko  
**Technical owner:** Andrii Isiuk  
**Last updated:** 1 September 2026

> **In short:**  
> This PRD describes the end-to-end Energy Bill Extraction vision and its phased delivery.
> 
> The target solution keeps Inveniam on the document-processing path: an Energy Bill PDF is registered in an **IO Data Room**, Docugami/DGML extraction runs **inside IO**, and extracted bill fields are returned to Measurabl through the **Extraction API** in a later production milestone. There is no skip-IO production path and no Inveniam Data Artifact Browser review flow for Measurabl. This is the locked November direction.
> 
> **Milestone 1 is the PoC.** It validates the Docugami extraction path inside Inveniam using representative **PDF Energy Bills**. The PoC may use manual Data Room extraction for testing and demonstration. Docugami produces the extraction result as **XML**.
> 
> **MSR MongoDB is out of PoC / M1 scope.** The PoC does not write extraction results into Measurabl MongoDB. DGML workspace/catalog Mongo (Docugami runtime), if used, is not an M1 product deliverable to Measurabl. Downstream persistence and the Extraction API belong to later milestones.
> 
> **M1 intentionally uses a reduced integration path.** It does not require Weaviate processing or permanent storage of the DGMLX workspace object in S3, Azure Blob, or another external storage provider. These are full-integration capabilities for later milestones, not missing PoC requirements.
> 
> After the PoC, Docugami-processed documents are expected to follow the standard IO document lifecycle. This includes keeping the DGMLX workspace object in the agreed external storage provider and creating the required chunked and embedded document representation in Weaviate. The detailed design remains subject to architecture approval.
> 
> The PoC is Milestone 1 of the same Bill Extraction initiative, not a separate product flow.

---

# Overview

We are building an Energy Bill Extraction capability:  
**Measurabl → Inveniam IO → Docugami/DGML → Measurabl**  
Two related flows must not be confused.

### PoC validation flow

**V2 Data Room → PDF Energy Bill → Docugami/DGML inside IO → XML result → inspection / validation (mechanism TBD)**  
Manual Extract may be used for testing and demonstration only.

### Target production flow

**BillAI / MSR file storage → source PDF registered in IO Data Room → Docugami/DGML inside IO → DGMLX stored in the agreed external storage provider + standard Weaviate document representation → Extraction API → Measurabl / BillAI**  
Source bytes may remain in customer storage. The document remains registered in IO (metadata/checksum) and does not bypass the Data Room.

---

# Problem Statement

Measurabl processes a large volume of Energy Bills. Those bills are nested (meters, readings, normalization, calculated values, sometimes multiple bills in one file). The current Data Artifact Browser is built for a flatter extraction model and is not the review surface for this initiative.  
Production volume also means per-bill manual upload and Extract cannot be the operating model.  
The solution must keep each bill registered in IO, extract through DGML inside IO, preserve Measurabl correlation, return fields through the Extraction API in a later production milestone, and leave human review in BillAI. Target production capacity is **300+ bills per working day** once the solution is production-ready (not an M1 SLA).

---

# Target End-to-End Flow

Locked November path:

1. User stays in **BillAI**.
2. Source PDF is **registered in the IO Data Room** (intentional; no skip-IO).
3. Energy Bill is processed through **DGML inside IO**.
4. Docugami produces two outputs: the **DGMLX workspace object** and the structured extraction result as **DGML XML**.
5. The DGMLX workspace object is stored in the agreed external storage provider, such as S3 or Azure Blob.
6. The document follows the standard IO lifecycle, including the required chunked and embedded representation in **Weaviate**.
7. Measurabl receives the field projection through the **Extraction API** in a later production milestone.
8. **BillAI** presents the result for human review.

---

# Data Representations and Persistence

These layers are not the same artifact.

| Layer | Purpose | M1 / PoC | Full integration |
| --- | --- | --- | --- |
| Source PDF | Original Energy Bill | Available in the agreed V2 Data Room | Registered in the IO Data Room; source bytes may remain in MSR-owned storage |
| DGML XML | Structured extraction result | Produced and made available for agreed inspection / validation | Preserved as the rich extraction result and transformed into the production field projection |
| DGMLX workspace object | Docugami workspace representation | May exist during processing, but permanent storage is **not an M1 acceptance criterion** | Stored in the agreed external storage provider, such as S3 or Azure Blob |
| Workspace catalog metadata | Supports workspace reuse and post-PoC processing | Not an M1 product deliverable | May use MongoDB or another agreed store, depending on the approved design |
| Weaviate document representation | Standard chunked and embedded IO representation | **Not required for M1** | Required as part of the standard IO document lifecycle |
| Extraction API projection | Production fields returned to Measurabl | Not M1 | Inveniam → Measurabl |
| BillAI representation | Human review and downstream use | Not M1 | Measurabl |

“Storage” in this programme:

| Meaning | Milestone | What it is |
| --- | --- | --- |
| PoC Data Room storage provider | M1 | How representative PDF files are made available in the V2 Data Room |
| Production MSR file storage | Post-M1 / later intake milestone | Source bills for automatic intake |
| External storage provider for DGMLX | Full integration | Agreed S3, Azure Blob, or equivalent location for permanent DGMLX workspace storage |
| MongoDB for workspace structure | Post-M1 | Possible internal workspace catalog or reuse metadata, depending on implementation |
| MSR MongoDB for extraction results | **Not M1** | Out of PoC scope. Any later persistence of transformed extraction results is a post-PoC decision |

XML is the M1 Docugami output. **EML is not an M1 extraction-result format.** BillAI is not assumed to consume XML directly. The production field projection is a later contract.

---

# Roles and System Responsibilities

**Measurabl** owns source bills and BillAI; provides PoC files, `statementId` if needed for PoC, quality and volume expectations, validators and expected values; consumes production results through the agreed Inveniam contract after M1.

**Inveniam** registers documents in the IO Data Room; routes Energy Bills to DGML; tracks job state; and later exposes production results through the Extraction API. As part of the full integration, Inveniam also manages the agreed DGMLX storage and standard Weaviate document representation. M1 does not include these capabilities or a write of extraction results into MSR MongoDB.

**Docugami** extracts Energy Bills, including nested and repeated data, normalization and multi-bill cases. It produces the DGMLX workspace object and the structured DGML XML result.

**BillAI** is the Measurabl review surface. BillAI implementation is outside Inveniam product scope.

---

# Locked Integration Constraints

Do not treat these as future ideas.  
**IO stays on the production path:** IO Data Room → DGML inside IO → Extraction API → Measurabl. No skip-IO.  
`statementId` is created and owned by Measurabl. It must stay associated through submission, processing and result retrieval in the production flow. An IO identifier or an external provider UUID must not replace it.

**v1 human review signal:** one document-level `humanReviewRecommended` yes/no flag. Raw confidence scores and mandatory per-field flags are not required. Field-level reasoning may be added later. This does not require the Data Artifact Browser.  
**Weaviate milestone boundary:** the Energy Bill DGML path does not use Weaviate in M1. The full integration is expected to create the standard chunked and embedded Weaviate representation later.  
**DGMLX milestone boundary:** permanent DGMLX storage in an external storage provider is not required for M1. It is part of the target full integration, subject to final architecture approval.  
**Energy Bill availability (confirmed 26 Aug 2026).** Supersedes earlier wording that treated the S1 JSON Energy Bill path as a fallback when Docugami is off:

- Docugami LLM selected → Energy Bill appears.
- No Docugami LLM → Energy Bill hidden.
- Inveniam must **not** silently route the document through the legacy JSON Energy Bill extractor.

**M1 is Inveniam V2 only.** V1 is out of scope.

---

# Goals

- One end-to-end Energy Bill Extraction solution, with Docugami/DGML as the engine and IO on the document path.
- M1 validates representative PDF Energy Bill extraction inside IO and produces XML.
- Production user experience stays in BillAI; Inveniam does not rebuild a nested extracted-data UI.
- Rich XML extraction record; later production field projection via Extraction API; correlation via statementId; document-level humanReviewRecommended in the v1 contract.
- Full integration brings Docugami-processed documents into the standard IO lifecycle, including agreed DGMLX storage and a Weaviate representation.
- Phased path from PoC to automated production operation, including 300+ bills/day when production-ready.

---

# Non-Goals (out of the scope)

Initiative:

- BillAI inside Inveniam;
- Data Artifact Browser as Measurabl HITL;
- skip-IO production path;
- generic extracted-data UI redesign;
- unrelated document types;
- The Energy Bill Docugami flow will **not be implemented or supported in the legacy Inveniam V1 application**. The PoC uses **Inveniam V2 only**.

M1 / PoC:

- **writing extraction results to MSR MongoDB**;
- automatic intake from MSR storage;
- permanent DGMLX storage in an external storage provider;
- creation of a Weaviate chunked and embedded representation;
- workspace reuse as a product capability;
- XML transformation into production field projection;
- 300+/day SLA;
- production-grade onboarding;
- stable Extraction API;
- final completion-notification contract;
- dedicated extracted-data UI;
- **committed** result download;
- production BillAI integration;
- production monitoring;
- final provenance / anchoring design.

A lightweight header download may be added later as optional convenience (see Inspection (M1)). It is not an M1 acceptance criterion.

---

# Delivery Milestones

M1 is the defined PoC scope. M2–M5 describe the expected direction after PoC and require further discovery, architecture confirmation, and story-level planning before they become committed delivery scope.  
The purpose of this section is to keep the phased product direction visible without treating post-PoC items as already finalized requirements.

## M1 — PoC: Validate the Docugami Energy Bill Path

**Objective.** Prove the V2 Docugami path for representative PDF Energy Bills: XML produced; inspection without Data Artifact Browser / Data Explorer. **No MSR MongoDB write.**  
**Flow:** V2 Data Room → PDF Energy Bill → DGML inside IO → XML → inspection / validation (mechanism TBD).  
**In scope**

- Representative **PDF Energy Bills** as the input format for PoC processing.
- Docugami configuration: Settings → Data Lab → AI Services → Docugami → Set up LLM.
- Energy Bill only when that configuration exists; no legacy JSON fallback.
- Manual upload / Extract for PoC testing and showcase.
- Existing Pending / Completed / Failed and retry where applicable.
- XML output.
- No Weaviate on this Energy Bill DGML path.
- No requirement to store DGMLX permanently in S3, Azure Blob, or another external storage provider.
- Representative bills for Product, QA and Measurabl.

**Out of M1:** MSR MongoDB write of extraction results; permanent DGMLX storage in an external storage provider; Weaviate processing; Extraction API; BillAI payload; auto-onboarding; workspace reuse; XML transformation into production representation; production notifications; 300+/day SLA; dedicated extracted-data UI; committed download.

### Inspection (M1)

How Product/QA inspect the XML remains to be agreed. A lightweight file download from the document header may be added if inexpensive; it is not required for M1 acceptance. No nested Data Artifact Browser or Data Explorer. Mongo is not the inspection path and is not in PoC scope.

### Success criteria

M1 is successful when:

- a representative Measurabl Energy Bill **PDF** is available in the agreed **V2 Data Room**;
- extraction runs through Docugami/DGML inside IO and produces the expected **XML**;
- jobs use normal Inveniam statuses; failures can be identified and retried per agreed PoC behaviour;
- Product, QA and Measurabl can inspect/validate the result through an **agreed validation mechanism** without Data Artifact Browser or Data Explorer;
- Energy Bill is hidden without Docugami LLM configuration, with **no legacy JSON fallback**;
- the path does not depend on Weaviate;
- permanent DGMLX storage in an external storage provider is not required for acceptance;
- other organisations and document types are unaffected.

M1 does **not** require a write to MSR MongoDB.  
M1 proves extraction quality and the PoC processing path. It does not prove the final BillAI production data contract.

### Completed semantics (M1)

For M1, Completed **means the Inveniam/DGML extraction path finished successfully** (XML produced). It does not mean a downstream Mongo or API write, a Weaviate representation, or permanent DGMLX storage.

### M1 end-to-end blockers

Independent engineering can proceed, but M1 cannot be accepted end-to-end while these remain open.

| Blocker | Decision needed |
| --- | --- |
| Environment | QA, UAT, or agreed shared/demo environment. Organisation creation can start once this is chosen. |
| PoC Data Room storage provider | Which connected storage provider holds representative M1 PDF files. This is separate from later production MSR file storage and target DGMLX storage. |
| Inspection / validation process | Who inspects the XML, against which dataset, and through which mechanism (not Mongo and not the Data Artifact Browser). |
| General design / API dependency check | Confirm what must be agreed for M1 and what belongs to later full-integration and production API work. |

### M1 extraction steps (PoC only)

1. Representative Energy Bill **PDF** is available in a **V2 Data Room**.
2. User selects Energy Bill and starts extraction manually through the existing Extract action.
3. The extraction job routes automatically through Docugami/DGML inside IO.
4. DGML XML is produced.
5. Job reaches Completed; source PDF remains a normal document.

---

## M2 — Full Docugami Integration and Automated Intake Discovery

**Objective.** Move from the reduced PoC path to the standard IO document lifecycle and reduce manual setup.

This is the first post-PoC phase. It covers the full Docugami document integration at a high level. Detailed sequencing and implementation remain subject to architecture approval.

It may introduce MongoDB usage for internal workspace catalog metadata if required by the Docugami runtime or Inveniam implementation. This does **not** mean writing transformed extraction results into MSR MongoDB.

**Expected direction**

- Store the DGMLX workspace object in the agreed external storage provider, such as S3 or Azure Blob.
- Keep the DGML XML structured extraction result.
- Create the required chunked and embedded Weaviate representation for Docugami-processed documents.
- Bring the document into the standard IO lifecycle without changing the M1 extraction result.
- Reuse workspace structure after PoC instead of treating each run as isolated.
- Define how representative/source PDF bills are registered in IO Data Room.
- Preserve the relationship between source bill, IO document identifier, extraction job and Measurabl statementId where applicable.
- Clarify how automatic intake will work after manual PoC validation.
- Define retention, versioning, duplicate, retry and re-processing behaviour.

**MongoDB clarification**  
MongoDB may appear in M2 for internal workspace structure or workspace reuse metadata. This is separate from MSR MongoDB extraction-result persistence.  
Transformation of DGML XML into a production payload or field projection belongs to a later milestone.

---

## M3 — XML Transformation and Production Results-Out Contract

**Objective.** Define how DGML XML is transformed into the production representation consumed by Measurabl.  
This milestone is not part of M1. It requires confirmed API contracts, field mapping, versioning, error handling and correlation rules.  
**Expected direction**

- Transform DGML XML into agreed production field projection.
- Preserve statementId and required IO identifiers.
- Define completion mechanism: polling, webhook, or both.
- Define document-level humanReviewRecommended in the v1 contract.
- Define schema/versioning, idempotency, re-fetch and error behaviour.
- Decide whether and where transformed results are persisted.

No raw confidence scores are required for the v1 production contract.

---

## M4 — BillAI Consumption and Validation

**Objective.** Measurabl consumes the production representation in BillAI and validates that the extracted data supports their review workflow.  
This milestone depends on Measurabl-side implementation and is not delivered by Inveniam alone.  
**Expected direction**

- BillAI receives the agreed production field projection.
- BillAI correlates results using statementId.
- BillAI presents the result for human review.
- Measurabl validates field correctness, normalization, repeated structures and multi-bill cases.

M1 XML quality does not automatically prove M4 BillAI usability.

---

## M5 — Production Scale and Operational Readiness

**Objective.** Prepare the solution for sustained production operation after the production contract and consumption flow are defined.  
**Expected direction**

- Production throughput target: 300+ bills per working day.
- Concurrency, retries, recovery and failure handling.
- Monitoring and operational ownership.
- Performance baselines and production SLA definition.
- Security, access control and deployment strategy.

M1 may capture early baselines, but it does not define or commit to a production SLA.

---

# Future Evolution — not committed in the current delivery plan

Not a sixth delivery stage. Possible later work, refined from M1 and post-PoC discovery:

- richer provenance / extraction-result anchoring if approved;
- historical-result handling;
- correction/feedback;
- additional providers;
- further Docugami document types if approved.

---

# Production Correlation

Preserve in the production flow:  
**Measurabl** statementId **↔ source Energy Bill PDF ↔ IO document identifier ↔ extraction job/result**  
How that association is stored is an implementation decision. The business identifier is not.

---

# Provenance and Anchoring

Final provenance and anchoring behaviour for DGML XML and transformed extraction results is not defined in M1.  
For M1, the only commitment is that the source Energy Bill PDF remains registered in the IO Data Room according to the approved PoC architecture.  
Any Keystone / ledger / anchoring dependency for DGML records or transformed results must be confirmed separately before it becomes a delivery requirement.

---

# Historical Data Behaviour

Turning off the Docugami configuration should control future availability of the Energy Bill extraction path. It should not be interpreted as an automatic retention or deletion rule for previously produced results.  
Detailed behaviour for previously generated DGML XML, workspace metadata, provenance records and re-extraction after disablement will be defined after PoC.

---

# Dependencies

**M1 Measurabl**

- Representative Energy Bill PDFs.
- Expected values for validation.
- Named validators and validation criteria.
- Confirmation of the general design direction.
- Confirmation which API contract details are required for M1, if any, and which belong to M3.

**M1 Inveniam**

- V2 environment and organisation.
- Deal / Data Room.
- Data Room storage provider for PoC files.
- Docugami/model configuration.
- Product and QA access.
- Agreed inspection / validation mechanism for XML.

**M1 Docugami**

- Energy Bill document set.
- Extraction schema.
- XML output behaviour.
- Guidance for representative Energy Bill cases, including nested structures and multi-bill examples where applicable.

**Post-M1**

- External storage design for the DGMLX workspace object.
- Standard Weaviate representation for Docugami-processed documents.
- Standard IO lifecycle, retention, versioning and re-processing behaviour.
- Workspace reuse design.
- Automated intake design.
- XML transformation and production field projection.
- Extraction API contract.
- BillAI consumption.
- Production auth, monitoring and operational ownership.

---

# Testing and Validation

Do not restate M1 scope here. Check:

| Owner | Validation points |
| --- | --- |
| Inveniam Product / QA | Configuration on/off; no legacy fallback; statuses and retry; PDF input; XML produced; no Data Artifact Browser or Data Explorer; no Weaviate dependency; no permanent DGMLX storage requirement; organisation isolation; no regression on other types; V2 only. If an optional header download exists, it is for inspection only. There is no Mongo write to validate. |
| Measurabl | Field correctness, normalization, repeated structures and applicable multi-bill cases; whether the result can support later integration. This is not final BillAI integration. |

---

# Post-M1 Discovery Topics

The following items are intentionally not treated as M1 requirements:

- workspace reuse;
- permanent DGMLX storage in the agreed external storage provider;
- standard Weaviate representation for Docugami-processed documents;
- standard IO lifecycle, retention, versioning and re-processing;
- automated intake;
- MongoDB use for workspace structure;
- XML transformation into production representation;
- production Extraction API;
- BillAI consumption;
- result persistence strategy;
- production throughput SLA;
- final provenance / anchoring model.

---

# Jira and Delivery Tracking

Vision, milestone boundaries, requirements, dependencies and open decisions live here. Story-level acceptance criteria live in Jira.

| Area | Jira |
| --- | --- |
| M1 Energy Bill Docugami PoC | [INV-42142](https://inveniam.atlassian.net/browse/INV-42142) |
| Docugami LLM configuration | [INV-42258](https://inveniam.atlassian.net/browse/INV-42258) |
| Docugami feature on/off | [INV-42259](https://inveniam.atlassian.net/browse/INV-42259) |
| No Weaviate path for M1 | [INV-42241](https://inveniam.atlassian.net/browse/INV-42241), [INV-42242](https://inveniam.atlassian.net/browse/INV-42242) |
| M2 full integration / intake investigation | [INV-42300](https://inveniam.atlassian.net/browse/INV-42300) |
| M3 results-out / Extraction API | [INV-42321](https://inveniam.atlassian.net/browse/INV-42321) |
| Broader historical DGML / Extraction API | [INV-41858](https://inveniam.atlassian.net/browse/INV-41858) — **On Hold / reference only** |

---

# Resources

- November alignment map
- IO × DGML Integration architecture
- Energy Bill / Docugami PoC
- Sentinel Weekly Meeting Summary — 26 August 2026
- Measurabl test dataset
- Auto file onboarding documentation
- Tickets listed above
