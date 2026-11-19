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
| 3 | Where should local `yarn test:contract` get its Pact broker and consumer pacts? | `inveniam.io` `yarn test:contract` verifies provider pacts against `http://localhost:9292` and publishes the result. The repo has no broker and no pact files. The broker is `pact-broker` plus `pact-postgres` in `inveniam-v2/docker-compose.yml`. The consumer publish is `inveniam-v2` `packages/browser/inveniam-api` target `contract-publish` (`local`), which uploads `dist/pacts/**/*` tagged `latest`. Providers the verifier asks for: `/iam/bff`, `/iam/favourites`, `/new-deals/real-estate`, `/new-deals/private-equity`. On 2026-11-19 the broker was started empty. iam-service failed because those two IAM pacts were missing, and Lerna did not run deals-service. Unit and integration tests do not use the broker. Left for this upgrade: the contract suite is not part of the green bar until the v2 consumer pacts are published. | open |

When a row becomes a decision, add the ADR and link it here. Leave the question in place with status `decided` and a link, so the wiki still explains *what we asked*.

## Related pages

- [Wiki Index](_resources/templates/investigation-project/wiki/index.md)
- [Decision register](../decisions/INDEX.md)
