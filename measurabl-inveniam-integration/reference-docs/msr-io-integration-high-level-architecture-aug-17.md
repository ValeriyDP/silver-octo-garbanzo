# MSR–IO integration — high-level architecture

**Date:** 17 August 2026  
**Status:** Discussion artifact — not final, not a commitment.

> **Superseded in part by [D2](architectural-decisions.md#d2-anchoring-enters-io-only-through-the-data-room) (2026-09-06).** Step 17 (Measurabl Anchoring service → Inveniam Anchoring API, "Only the root leaves") will not exist. Anchoring enters IO only through the Data Room (step 7). The rest of the diagram remains a discussion artifact.

The diagram below is a high-level architecture describing the current vision for the MSR ↔ IO integration. It is an update to the earlier diagram, extending it with structured data anchoring.

It answers two questions: how data gets anchored (structured and unstructured — both), and how data gets extracted with DGML.

The diagram is large — start with the “How to read this” blocks to find your way around it.  
The diagram contains a lot of deliberate simplification: it mentions only the parts of the systems directly related to the goal, the MSR ↔ IO integration.

The diagram is not final and is not a commitment. Its purpose is to give us one common place to discuss this together.

![MSR-IO integration — high-level architecture (Aug 17)](./MSR-IO%20integration%20%E2%80%94%20high-level%20architecture%20(Aug%2017).png)
