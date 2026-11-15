const fs = require("node:fs");
const path = require("node:path");

class FileCheckpointStore {
  constructor(directory) {
    this.directory = path.resolve(directory);
    fs.mkdirSync(this.directory, { recursive: true });
  }

  save(checkpoint) {
    const name =
      String(checkpoint.runId).replace(/[^A-Za-z0-9_.-]/g, "_") ||
      "checkpoint";
    const target = path.join(this.directory, `${name}.json`);
    const temporary = `${target}.tmp`;
    fs.writeFileSync(temporary, JSON.stringify(checkpoint), "utf8");
    fs.renameSync(temporary, target);
  }
}

module.exports = { FileCheckpointStore };
