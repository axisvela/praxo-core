const test = require("node:test");
const assert = require("node:assert/strict");

const { FlakyModel, run } = require("./retry");

test("retries transient failures", async () => {
  const model = new FlakyModel(2);
  const output = await run(model, 3);
  assert.equal(output, "status: green");
  assert.equal(model.calls, 3);
});

test("exhausted attempts preserve the error", async () => {
  const model = new FlakyModel(3);
  await assert.rejects(
    () => run(model, 3),
    (error) => error.code === "MODEL_UNAVAILABLE"
  );
  assert.equal(model.calls, 3);
});
