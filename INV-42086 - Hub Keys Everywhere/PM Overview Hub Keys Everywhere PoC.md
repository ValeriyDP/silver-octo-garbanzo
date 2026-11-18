---
name: PM Overview Hub Keys Everywhere PoC
date: 2026-08-24T16:30:00.000Z
tags:
  - hub-keys
  - inv-42086
  - presentation
  - nvnm
---

# Hub Keys Everywhere — PM overview (PoC)

Talking points for a non-technical audience. Ticket: **INV-42086**. Product: Inveniam UI v2.

Use as slide copy or a short briefing. Skip the engineering notes.

---

## One sentence

Customers can now attach an NVNM **document-validation key** to an organisation, a portfolio, or a deal — and then **register that deal** and **validate documents** from UI v2, without asking engineering to edit the database.

---

## Why this existed

Before this work, Hub keys for document validation lived at the **organisation** only.

That does not match how clients work:

- Different **portfolios** may use different validation setups.
- A single **deal** may need its own key.
- Connecting a key should not force every deal in the organisation to share it.

UI v2 also had a gap: you could connect a key, but you could not **register the deal** for validation in the product. Operators had to record that step by hand. That is not a customer flow.

---

## What we mean by the entities

| Entity | In this story |
| ------ | ------------- |
| **Organisation** | The company / tenant. |
| **Portfolio** | A grouping of deals. Nested portfolios exist in the UI; the validation key is stored against the **top (root) portfolio**, not every nested folder. |
| **Deal** | The asset / transaction being validated. **One validation registry per deal.** Every document in that deal is recorded into the same registry. |
| **Data room** | Where documents live for the deal. Connecting a key here is how users attach validation to the working files. |
| **Hub key** | Credentials that let Inveniam talk to the NVNM validation network on the customer’s behalf. |
| **NVNM** | The validation network this PoC supports. Other networks (Ethereum, etc.) are unchanged and still organisation-level. |
| **Register the deal** | One-time step: create the deal’s on-chain registry so documents have somewhere to be recorded. |
| **Sync / validate a document** | Per-file step: write that file’s fingerprint into the deal’s registry. |

Rule of thumb: **the most specific key wins.** A deal key overrides a portfolio key; a portfolio key overrides the organisation key.

---

## What the customer can do now

1. **Attach a Hub key** on the organisation, a portfolio, a deal, or the data room (NVNM only) — enough to prove the flow. There is no full key management (view / change / remove) at those levels.
2. Open the data room and see NVNM as a **connected validation service** — including when the key was added higher up and inherited.
3. Open a file → **DLT Management**.
   - If the deal is not registered yet: **Register symbol**.
   - After registration succeeds: **Sync**.
4. Wait for confirmation. The file’s validation status updates when the network accepts the record.

No database work. No legacy app for this path.

---

## What we proved in the PoC

- Keys can be attached **below the organisation** and still show as connected in the data room.
- The product picks the **closest** key (deal → portfolio → organisation).
- **Register** runs from UI v2. The first time, the deal is set up automatically; the customer does not fill a form (the deal identity is used).
- **Register and Sync both use that closest key**, not only an organisation-wide key. A portfolio- or deal-level key is enough.
- When the NVNM **network** itself rejects the write, the product reports failure and the customer can try Register again. We saw that in demo: our flow completed; the chain returned a network error. That is outside Inveniam’s control.

---

## What this PoC deliberately does not include

These are known boundaries, not surprises:

- **Managing Hub keys below the organisation** (create, view, change, remove on a portfolio, deal, or data room) is not in this PoC. Organisation-level key management is unchanged. A key can be **attached** at those levels for the demo; there is no full Hub-key admin experience there.
- **No dashboard of connected scoped keys** in Organisation Blockchain. That screen still shows organisation-level keys only. Keys attached to a portfolio, deal, or data room do not appear there.
- **NVNM only.** Other validation / blockchain networks stay organisation-level.
- **Moving a deal** to another portfolio is not updated. The demo assumes the deal stays where it was created.
- **Deals created before this PoC** may not pick up a portfolio-level key until they are touched or backfilled.
- Nested **sub-portfolios** are not a separate key level. The key sits on the root portfolio (plus organisation and deal).
- We did not change how Hub wallets are funded or how the NVNM network itself behaves. If the network is down, Register/Sync will fail after our steps succeed.

---

## Suggested talking points (2 minutes)

> “Clients asked to put validation keys where the work actually sits — on a portfolio or a deal — not only on the whole organisation.  
> We shipped that for NVNM in UI v2: connect a key, see it as connected, register the deal once, then sync documents.  
> Most specific key wins. One registry per deal.  
> The remaining failure we hit in demo was the NVNM network, not the Inveniam flow.  
> Follow-ups for a full product: Hub key management at portfolio/deal/data-room, a dashboard of those keys in Organisation Blockchain, other networks, moving deals between portfolios, and older deals.”

---

## Suggested next product questions

- Do we need full **Hub key management** (create, view, change, remove) at portfolio, deal, and data-room — or is attach-for-use enough?
- Should Organisation Blockchain show a **dashboard of connected scoped keys**, or stay organisation-level only?
- Do we roll this pattern to **other** validation networks, or keep NVNM as the only scoped network for now?
- Should **moving a deal** keep using the old portfolio’s key, or re-bind to the new one?
- Is **Register symbol** the right customer wording, or should it be “Enable validation for this deal”?

---

## Related (engineering)

- [HOW-TO Enable DLT Validation (NVNM)](HOW-TO%20Enable%20DLT%20Validation%20(NVNM).md) — click-path for customers and setup for developers
- [NVNM Register And Sign Final Flow](NVNM%20Register%20And%20Sign%20Final%20Flow.md) — technical sequence
- [INDEX](INV-42086%20-%20Hub%20Keys%20Everywhere/INDEX.md)
