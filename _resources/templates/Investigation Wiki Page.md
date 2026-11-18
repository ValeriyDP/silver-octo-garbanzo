<%*
const now = new Date()
let fileName = tp.file.title
if (!fileName || fileName.includes("Untitled")) {
  fileName = await tp.system.prompt("Wiki page title")
  if (fileName) await tp.file.rename(fileName)
}
tp.hooks.on_all_templates_executed(async () => {
  const file = tp.file.find_tfile(tp.file.path(true))
  await app.fileManager.processFrontMatter(file, (fm) => {
    fm["name"] = fileName
    fm["date"] = now
    fm["tags"] = ["wiki"]
  })
})
-%>

# <% fileName %>

**Summary**: 

**Sources**: 

**Last updated**: <% tp.date.now("YYYY-MM-DD") %>

---



## Related pages

- [Wiki Index](_resources/templates/investigation-project/wiki/index.md)
- [Decision register](../decisions/INDEX.md)
