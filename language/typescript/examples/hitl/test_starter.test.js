const assert = require("node:assert/strict");
const test = require("node:test");

const { run } = require("./starter");

test("approve and edit scenarios", async () => {
  const lines = [];
  await run((line) => lines.push(line));
  assert.deepEqual(lines, [
    "approve: written; effects=1",
    "edit: policy rejected; effects=0",
  ]);
});
