const test = require("node:test");
const assert = require("node:assert/strict");
const { ROLE_ASSISTANT } = require("@axisvela/praxo-core");

const { run } = require("./fallback");

class FailingModel {
  constructor() {
    this.calls = 0;
  }

  async generate() {
    this.calls += 1;
    throw new Error("primary unavailable");
  }
}

class StaticModel {
  constructor(content) {
    this.content = content;
    this.calls = 0;
  }

  async generate() {
    this.calls += 1;
    return {
      message: { role: ROLE_ASSISTANT, content: this.content },
    };
  }
}

test("uses fallback after primary failure", async () => {
  const primary = new FailingModel();
  const fallback = new StaticModel("fallback response");
  assert.equal(await run(primary, fallback), "fallback response");
  assert.equal(primary.calls, 1);
  assert.equal(fallback.calls, 1);
});

test("primary is used when it succeeds", async () => {
  const primary = new StaticModel("primary response");
  const fallback = new StaticModel("fallback response");
  assert.equal(await run(primary, fallback), "primary response");
  assert.equal(primary.calls, 1);
  assert.equal(fallback.calls, 0);
});

test("both failures reject", async () => {
  await assert.rejects(run(new FailingModel(), new FailingModel()));
});
