
<%*
const now = new Date()
const timestamp = now.getFullYear().toString().slice(-2) 
+ (now.getMonth() + 1).toString().padStart(2, '0') 
+ now.getDate().toString().padStart(2, '0') 
+ now.getHours().toString().padStart(2, '0') 
+ now.getMinutes().toString().padStart(2, '0')
let fileName = tp.file.title;

if (fileName === ""|| fileName.includes("Untitled") || fileName === undefined || fileName === null) {
  fileName = await tp.system.prompt("Enter note name");
  await tp.file.rename(fileName || tp.file.title)
}

tp.hooks.on_all_templates_executed(async () => {
  const file = tp.file.find_tfile(tp.file.path(true));
  await app.fileManager.processFrontMatter(file, (frontmatter) => {
    frontmatter["name"] = fileName;
    frontmatter["date"] = now;
    frontmatter["tags"] = null;
  });
});
-%>