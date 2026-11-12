const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");

const praxo = require("@axisvela/praxo-core");
const pkg = require("@axisvela/praxo-core/package.json");

const { buildAgent, run } = require("./starter");

const expectedVersion = process.env.PRAXO_EXPECTED_VERSION || "0.4.1";

test("allowed tool executes once", async () => {
  const { agent, tool } = buildAgent("public");
  const result = await agent.run(
    { id: "test-public" },
    "Record the requested target."
  );
  assert.equal(result.output, "recorded");
  assert.equal(tool.calls, 1);
});

test("denied tool has no effect", async () => {
  const { agent, tool } = buildAgent("private");
  await assert.rejects(
    agent.run({ id: "test-private" }, "Record the requested target."),
    praxo.PolicyDeniedError
  );
  assert.equal(tool.calls, 0);
});

test("starter output is deterministic", async () => {
  const lines = [];
  await run((line) => lines.push(line));
  assert.deepEqual(lines, [
    "allow: recorded; effects=1",
    "deny: policy rejected; effects=0",
  ]);
});

test("dependency comes from the published package", () => {
  assert.equal(pkg.version, expectedVersion);
  assert.equal(praxo.SDK_VERSION, pkg.version);
  const resolved = require.resolve("@axisvela/praxo-core");
  const root = path.resolve(__dirname);
  assert.ok(
    resolved.startsWith(root + path.sep),
    `dependency resolved outside the application: ${resolved}`
  );
  const dependency = require("./package.json").dependencies["@axisvela/praxo-core"];
  assert.equal(dependency, expectedVersion);
  assert.ok(!/^(file:|link:|git|https?:)/.test(dependency));
});
