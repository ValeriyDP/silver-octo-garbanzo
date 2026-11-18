---
name: Open Questions Agenda
date: 2026-09-17T13:09:00.000Z
tags:
  - measurabl-provision
  - inv-42559
  - wiki
---

# Open Questions Agenda

**Summary**: What is still open after INV-42559 vs `develop`. #1–#10 are decided on [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md).

**Sources**: [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #11–#14.

**Last updated**: 2026-09-22

---

- **#11 Real IO `userId` vs sentinel.** Empty `user_id` broke the insert and the webhook. Interim: `MEASURABL_TRANSACTIONS_USER_ID` = `11111111-1111-4111-8111-111111111111`. Keep sentinel now; create a real Measurabl IO user later; do not null the column.

- **#12 Org estimate vs identity-signed registry.** Hub estimate is always org wallet / `unauthorized` for identity-created registries. **C working:** ethers `eth_estimateGas(addRegistry` / `addRecord)` from the identity address (Vault ABI); leftover-aware Hub sign buffer. Destination is still Hub `/ledgers/estimate` from the identity wallet (do not change Hub without an ask). See [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #12.

- **#13 Hub job Failed then Succeed (same `hubJobId`).** Status poll marks job `failed` terminal; later `Succeed` is skipped. Retry write replays the Failed row. **Suggested:** Failed row stays Failed; retry is a new IO transaction + new Hub job. Patching `Failed → Pending` on the same row was tried and reverted. See [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #13.

- **#14 Taxonomy id is not available at ClientDLT emit.** Upload does not create `data_room_file_taxonomies`. View-file URL is `fileId` + `dealId` only. `ClientDLTTransaction` still requires `taxonomyId`. **Unsolved.** Prefer key on `fileId` (B) or hybrid (C). See [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md) #14 and [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md).

## Related pages

- [Measurabl Provisioning Handoff](Measurabl%20Provisioning%20Handoff.md)

- [Wiki Index](Measurabl%20provision%20(INV-42559)/wiki/index.md)
- [Open Questions](Measurabl%20provision%20(INV-42559)/wiki/Open%20Questions.md)
- [Taxonomy Id Before Client DLT](Taxonomy%20Id%20Before%20Client%20DLT.md)
- [Identity Wallet Signing](Identity%20Wallet%20Signing.md)
- [Decision register](../decisions/INDEX.md)
