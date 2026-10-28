const assert = require("node:assert/strict");
const path = require("node:path");

const praxo = require("@axisvela/praxo-core");
const pkg = require("@axisvela/praxo-core/package.json");

class StaticModel {
  async generate() {
    return { message: { role: "assistant", content: "installed" } };
  }
}

async function main() {
  assert.equal(praxo.SDK_VERSION, pkg.version);
  assert.equal(praxo.SPEC_VERSION, "0.2.0");
  const resolved = require.resolve("@axisvela/praxo-core");
  const expected = process.env.PRAXO_CONSUMER_ROOT;
  if (expected) {
    assert.ok(
      resolved.startsWith(path.resolve(expected) + path.sep),
      `resolved outside consumer: ${resolved}`
    );
  }
  const tools = new praxo.Registry();
  tools.register(new praxo.FuncTool("echo", "Echo", (args) => args));
  const events = [];
  const agent = new praxo.Agent({
    model: new StaticModel(),
    tools,
    events: { async emit(event) { events.push(event.type); } },
  });
  const result = await agent.run({ id: "installed" }, "hello");
  assert.equal(result.output, "installed");
  assert.equal(result.steps, 1);
  assert.deepEqual(events, ["run.started", "run.completed"]);
  console.log(`installed package smoke passed: ${resolved}`);
}

main().catch((error) => {
  console.error(`installed package smoke failed: ${error.message}`);
  process.exitCode = 1;
});
