const assert = require("node:assert/strict");
const test = require("node:test");

const { Registry } = require("../dist");

test("registry specs include tool parameters and risk", () => {
  const registry = new Registry();
  registry.register({
    name: "record",
    description: "Record a target.",
    parameters: {
      type: "object",
      required: ["target"],
      properties: { target: { type: "string" } },
    },
    risk: "write",
    invoke() {
      return "recorded";
    },
  });

  const spec = registry.specs()[0];

  assert.equal(spec.name, "record");
  assert.deepEqual(spec.parameters, {
    type: "object",
    required: ["target"],
    properties: { target: { type: "string" } },
  });
  assert.equal(spec.risk, "write");
});

test("registry uses an explicit spec provider", () => {
  const registry = new Registry();
  registry.register({
    name: "named",
    description: "Named tool.",
    invoke() {
      return "ok";
    },
    spec() {
      return {
        name: "named",
        description: "Named tool.",
        parameters: { type: "object", properties: {} },
        risk: "read",
      };
    },
  });

  const spec = registry.specs()[0];

  assert.deepEqual(spec.parameters, { type: "object", properties: {} });
  assert.equal(spec.risk, "read");
});
