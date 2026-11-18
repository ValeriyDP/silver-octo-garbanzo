<%*
// Scaffolds a Hub-Keys-style ADR folder + Smart-Accounts-style wiki, cross-linked.
// Templater → Insert template → New Investigation Folder
// Run from the vault root (or any folder). Creates a sibling project folder.

const srcRoot = "_resources/templates/investigation-project"
const files = [
  "README.md",
  "AGENTS.md",
  "CLAUDE.md",
  ".mcp.json",
  "qmd-collection",
  "raw/Do Not Edit.md",
  "wiki/index.md",
  "wiki/log.md",
  "wiki/Open Questions.md",
  "decisions/INDEX.md",
  "decisions/log.md",
  "decisions/ADR Template.md",
]

const projectName = await tp.system.prompt("Project name")
if (!projectName || !projectName.trim()) {
  tR += "Cancelled — no project name."
  return
}

const ticketRaw = (await tp.system.prompt("Ticket (optional, e.g. INV-42086)")) || ""
const ticket = ticketRaw.trim()
const defaultTag = projectName
  .trim()
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/^-+|-+$/g, "")
const tag = ((await tp.system.prompt("Primary tag", defaultTag)) || defaultTag)
  .trim()
  .toLowerCase()
  .replace(/[^a-z0-9-]+/g, "-")
  .replace(/^-+|-+$/g, "")

const pathsRaw = ((await tp.system.prompt("Application repo path(s), absolute, comma-separated")) || "").trim()
const appPaths = pathsRaw
  ? pathsRaw
      .split(",")
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => `- \`${p}\``)
      .join("\n")
  : "(not set — ask before investigating)"

const folderName = ticket ? `${ticket} - ${projectName.trim()}` : projectName.trim()
const parent = tp.file.folder(true)
const root = !parent || parent === "/" ? folderName : `${parent}/${folderName}`

const now = new Date()
const iso = now.toISOString()
const dateShort = iso.slice(0, 10)
const ticketTag = ticket ? `\n  - ${ticket.toLowerCase()}` : ""
const ticketSuffix = ticket ? ` (${ticket})` : ""

function fill(text) {
  return text
    .replaceAll("{{PROJECT_NAME}}", projectName.trim())
    .replaceAll("{{TICKET}}", ticket)
    .replaceAll("{{TICKET_TAG}}", ticketTag)
    .replaceAll("{{TICKET_SUFFIX}}", ticketSuffix)
    .replaceAll("{{TAG}}", tag)
    .replaceAll("{{DATE}}", iso)
    .replaceAll("{{DATE_SHORT}}", dateShort)
    .replaceAll("{{QMD_COLLECTION}}", tag)
    .replaceAll("{{APP_PATHS}}", appPaths)
}

const dirs = [`${root}`, `${root}/raw`, `${root}/wiki`, `${root}/decisions`]
for (const dir of dirs) {
  try {
    await app.vault.createFolder(dir)
  } catch (e) {
    // exists
  }
}

for (const rel of files) {
  const src = app.vault.getAbstractFileByPath(`${srcRoot}/${rel}`)
  if (!src) {
    tR += `Missing skeleton: ${srcRoot}/${rel}\n`
    continue
  }
  const body = fill(await app.vault.read(src))
  const dest = `${root}/${rel}`
  if (app.vault.getAbstractFileByPath(dest)) continue
  await app.vault.create(dest, body)
}

const readme = app.vault.getAbstractFileByPath(`${root}/README.md`)
if (readme) {
  await app.workspace.getLeaf(false).openFile(readme)
}

// Clean up the empty note Templater inserted into (e.g. the stray "Untitled"
// in the vault root). Only delete it when it is empty and lives outside the
// project folder we just created, so a real note is never destroyed.
try {
  const target = tp.config.target_file
  if (target) {
    const inProject = target.path === `${root}/README.md` || target.path.startsWith(`${root}/`)
    const body = (await app.vault.read(target)).trim()
    if (!inProject && body === "") {
      await app.vault.trash(target, true)
    }
  }
} catch (e) {
  // leave the note in place if anything about the cleanup is uncertain
}
-%>
