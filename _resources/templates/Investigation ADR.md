<%*
const now = new Date()
let fileName = tp.file.title
if (!fileName || fileName.includes("Untitled")) {
  fileName = await tp.system.prompt("ADR filename (e.g. ADR-0001 Short Title)")
  if (fileName) await tp.file.rename(fileName)
}
tp.hooks.on_all_templates_executed(async () => {
  const file = tp.file.find_tfile(tp.file.path(true))
  await app.fileManager.processFrontMatter(file, (fm) => {
    fm["name"] = fileName
    fm["date"] = now
    fm["tags"] = ["adr", "architecture"]
  })
})
-%>

# <% fileName %>

- **Status**: Proposed
- **Date**: <% tp.date.now("YYYY-MM-DD") %>
- **Area**: 
- **Deciders**: 
- **Related**: [Decision register](_resources/templates/investigation-project/wiki/index.md), [wiki](../wiki/index.md)

## Context



## Decision



## Alternatives considered

- **Option A** — 
- **Option B** — 

## Consequences

- **Positive**: 
- **Negative / trade-offs**: 
- **Follow-ups / open threads**: 

## Affected code

| Path | What changed |
| ---- | ------------ |
| | |

## Related

- [Decision register](_resources/templates/investigation-project/wiki/index.md)
- [Wiki](../wiki/index.md)
