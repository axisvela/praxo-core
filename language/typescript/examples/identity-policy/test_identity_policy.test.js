const test = require("node:test");
const assert = require("node:assert/strict");

const { runCase } = require("./identity_policy");

const principal = (role, active = true) => ({
  id: "actor-1",
  tenant: "acme",
  role,
  active,
});

test("missing principal is denied", async () => {
  const result = await runCase(null);
  assert.equal(result.calls, 0);
  assert.equal(result.error?.code, "AGENT_POLICY_DENIED");
});

test("inactive principal is denied", async () => {
  const result = await runCase(principal("operator", false));
  assert.equal(result.calls, 0);
  assert.equal(result.error?.code, "AGENT_POLICY_DENIED");
});

test("model-claimed role is ignored", async () => {
  const result = await runCase(principal("viewer"), "acme", "admin");
  assert.equal(result.calls, 0);
  assert.equal(result.error?.code, "AGENT_POLICY_DENIED");
});

test("tenant mismatch is denied", async () => {
  const result = await runCase(principal("operator"), "other");
  assert.equal(result.calls, 0);
  assert.equal(result.error?.code, "AGENT_POLICY_DENIED");
});

test("verified operator is allowed", async () => {
  const result = await runCase(principal("operator"));
  assert.equal(result.error, null);
  assert.equal(result.calls, 1);
});
