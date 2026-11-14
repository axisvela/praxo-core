const assert = require("node:assert/strict");
const test = require("node:test");

const { run } = require("./starter");

test("restores multi-turn history", async () => {
  const lines = [];
  await run((line) => lines.push(line));
  assert.deepEqual(lines, ["restored messages: 4", "output: turn 5"]);
});
