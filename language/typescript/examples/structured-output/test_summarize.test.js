const test = require("node:test");
const assert = require("node:assert/strict");

const { ROLE_ASSISTANT } = require("@axisvela/praxo-core");
const { summarize } = require("./summarize");

class FakeModel {
  async generate() {
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          title: "Release status",
          summary: "All checks are green.",
          tags: ["release", "status"],
        }),
      },
    };
  }
}

test("summary matches schema", async () => {
  const output = await summarize(
    "Quarterly status: all checks green.",
    new FakeModel()
  );
  const data = JSON.parse(output);
  assert.deepEqual(Object.keys(data).sort(), ["summary", "tags", "title"]);
  assert.ok(Array.isArray(data.tags));
});
