const test = require("node:test");
const assert = require("node:assert/strict");

const { StreamingModel, run } = require("./streaming");

test("deltas reconstruct the final output", async () => {
  const chunks = ["status: ", "green"];
  const received = [];

  const output = await run(new StreamingModel(chunks), (delta) =>
    received.push(delta)
  );

  assert.equal(output, "status: green");
  assert.deepEqual(received, chunks);
  assert.equal(received.join(""), output);
});
