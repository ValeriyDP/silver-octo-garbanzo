<%*
// Generate timestamp
const now = new Date()
const timestamp = now.getFullYear().toString().slice(-2) +
    (now.getMonth() + 1).toString().padStart(2, '0') +
    now.getDate().toString().padStart(2, '0') +
    now.getHours().toString().padStart(2, '0') +
    now.getMinutes().toString().padStart(2, '0')

// Get folder name from user
let folderName = await tp.system.prompt("Enter folder name")

// Create folder path
let folderPath = tp.file.folder(true) + "/" + timestamp + "_" + folderName

// Create the folder
await app.vault.createFolder(folderPath)
-%>