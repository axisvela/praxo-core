const assert = require("node:assert/strict");
const test = require("node:test");

const praxo = require("../dist");

test("schema integer rejects fractions", () => {
  const schema = { type: "integer" };
  assert.equal(praxo.validate(schema, 2).length, 0);
  assert.equal(praxo.validate(schema, 2.5).length, 1);
});

test("schema length counts Unicode code points", () => {
  const schema = { type: "string", minLength: 2, maxLength: 2 };
  assert.equal(praxo.validate(schema, "你好").length, 0);
  assert.equal(praxo.validate(schema, "你").length, 1);
});

test("model call limit fails closed", async () => {
  class Model {
    async generate() {
      return {
        message: {
          role: "assistant",
          content: "",
          toolCalls: [{ id: "c1", name: "echo", arguments: {} }],
        },
      };
    }
  }
  const tools = new praxo.Registry();
  tools.register(new praxo.FuncTool("echo", "Echo", (args) => args));
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    modelCallLimit: 1,
  });
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.ModelCallLimitError
  );
});

test("tool call limit fails closed", async () => {
  class Model {
    async generate() {
      return {
        message: {
          role: "assistant",
          content: "",
          toolCalls: [
            { id: "c1", name: "echo", arguments: {} },
            { id: "c2", name: "echo", arguments: {} },
          ],
        },
      };
    }
  }
  const tools = new praxo.Registry();
  tools.register(new praxo.FuncTool("echo", "Echo", (args) => args));
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    toolCallLimit: 1,
  });
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.ToolCallLimitError
  );
});

test("context budget fails closed", async () => {
  const agent = new praxo.Agent({
    model: {
      async generate() {
        return { message: { role: "assistant", content: "done" } };
      },
    },
    systemPrompt: "x".repeat(1000),
    context: new praxo.ContextBudget(10),
  });
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.ContextBudgetError
  );
});
