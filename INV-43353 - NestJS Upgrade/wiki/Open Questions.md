---
name: Open Questions
date: 2026-11-18T08:06:44.542Z
tags:
  - nestjs-upgrade
  - inv-43353
  - wiki
---

# Open Questions

**Summary**: Parking lot for things we do not know yet. Promote a question to an ADR in `decisions/` when a design choice is required.

**Sources**: —

**Last updated**: 2026-11-19

---

| # | Question | Notes | Status |
| - | -------- | ----- | ------ |
| 1 | | | open |
| 2 | Should the `@inveniam/events` ↔ `@inveniam/domain-interfaces` package cycle be broken? | Nx warns on `test:unit`: `automated-workflow-service` → `@inveniam/aws-libs` → `@inveniam/events` → `@inveniam/domain-interfaces` → `@inveniam/events`. The loop is `@inveniam/domain-interfaces` importing event payloads from four files (`Domain/Worflows/task.interfaces.ts`, `mention.interface.ts`, `group.interfaces.ts`, `Domain/AutomatedWorkflow/action.interfaces.ts`). `@inveniam/events` imports domain types in a couple hundred files. Moving the payload types into domain-interfaces and re-exporting them from events removes the cycle, and it touches too many public types for this upgrade. The warning does not fail the run. `@inveniam/domain-interfaces` `test:unit` only prints that the package has no tests. | open |

When a row becomes a decision, add the ADR and link it here. Leave the question in place with status `decided` and a link, so the wiki still explains *what we asked*.

## Related pages

- [Wiki Index](_resources/templates/investigation-project/wiki/index.md)
- [Decision register](../decisions/INDEX.md)
