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

test("call limit state is isolated by run", () => {
  const middleware = praxo.callLimitMiddleware(1, 0);
  middleware.beforeRun({ runId: "a" });
  middleware.beforeRun({ runId: "b" });
  middleware.beforeModel({
    runId: "a",
    sessionId: "s1",
    request: { messages: [] },
  });
  middleware.beforeModel({
    runId: "b",
    sessionId: "s1",
    request: { messages: [] },
  });
});

test("maxParallelTools starts tools concurrently and keeps order", async () => {
  class Model {
    constructor() {
      this.requests = [];
      this.step = 0;
    }

    async generate(request) {
      this.requests.push(request);
      this.step += 1;
      if (this.step === 1) {
        return {
          message: {
            role: "assistant",
            content: "",
            toolCalls: [
              { id: "c1", name: "barrier", arguments: { value: 1 } },
              { id: "c2", name: "barrier", arguments: { value: 2 } },
            ],
          },
        };
      }
      return { message: { role: "assistant", content: "done" } };
    }
  }
  class BarrierTool {
    constructor() {
      this.name = "barrier";
      this.description = "waits for both calls";
      this.calls = [];
      this.started = 0;
      this.bothStarted = new Promise((resolve) => {
        this.release = resolve;
      });
    }

    async invoke(args) {
      this.calls.push(args);
      this.started += 1;
      if (this.started === 2) this.release();
      await this.bothStarted;
      return args;
    }
  }
  const tool = new BarrierTool();
  const tools = new praxo.Registry();
  tools.register(tool);
  const model = new Model();
  const agent = new praxo.Agent({
    model,
    tools,
    maxParallelTools: 2,
  });
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new Error("tools did not start in parallel")),
      2000
    );
  });
  try {
    const result = await Promise.race([
      agent.run({ id: "s1" }, "go"),
      timeout,
    ]);
    assert.equal(result.output, "done");
  } finally {
    clearTimeout(timer);
  }
  assert.deepEqual(tool.calls, [{ value: 1 }, { value: 2 }]);
  const toolMessages = model.requests[1].messages.filter(
    (message) => message.role === "tool"
  );
  assert.deepEqual(
    toolMessages.map((message) => message.toolId),
    ["c1", "c2"]
  );
});

test("stream callback failure aborts run", async () => {
  class Model {
    async generate() {
      return { message: { role: "assistant", content: "done" } };
    }

    async generateStream(request, onDelta) {
      onDelta("he");
      return { message: { role: "assistant", content: "done" } };
    }
  }
  const agent = new praxo.Agent({
    model: new Model(),
    onDelta: () => {
      throw new Error("stream down");
    },
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /stream down/);
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
