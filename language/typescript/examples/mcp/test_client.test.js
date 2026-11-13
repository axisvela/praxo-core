const test = require("node:test");
const assert = require("node:assert/strict");

const { demo } = require("./client");

test("lists and calls a local MCP tool", async () => {
  assert.equal(await demo(), "tools=add,echo; sum=5");
});
