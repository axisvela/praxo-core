const assert = require("node:assert/strict");
const test = require("node:test");

const praxo = require("../dist");

const model = {
  async generate() {
    return { message: { role: "assistant", content: "ok" } };
  },
};

test("requirePolicy rejects a missing policy", () => {
  assert.throws(
    () => new praxo.Agent({ model, requirePolicy: true }),
    /require policy/
  );
});

test("requireToolScope rejects an empty scope", () => {
  assert.throws(
    () => new praxo.Agent({ model, requireToolScope: true }),
    /require tool scope/
  );
});

test("safe defaults accept explicit configuration", () => {
  const agent = new praxo.Agent({
    model,
    allowedTools: ["echo"],
    policy: { authorize: () => ({ allowed: true }) },
    requirePolicy: true,
    requireToolScope: true,
  });
  assert.equal(agent.options.requirePolicy, true);
  assert.equal(agent.options.requireToolScope, true);
});
