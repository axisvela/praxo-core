const assert = require("node:assert/strict");
const test = require("node:test");

const praxo = require("../dist");

function toolResponse(argumentsValue = "original") {
  return {
    message: {
      role: "assistant",
      content: "",
      toolCalls: [
        { id: "call-1", name: "echo", arguments: { value: argumentsValue } },
      ],
    },
  };
}

function finalResponse(content = "final") {
  return { message: { role: "assistant", content, toolCalls: [] } };
}

class ScriptModel {
  constructor(responses) {
    this.responses = [...responses];
  }

  async generate() {
    return this.responses.shift();
  }
}

class EchoTool extends praxo.FuncTool {
  constructor(calls) {
    super("echo", "Echo", async (args) => {
      calls.push(args);
      return args;
    });
  }
}

function buildAgent(decision, extra = {}) {
  const calls = [];
  const tools = new praxo.Registry();
  tools.register(new EchoTool(calls));
  const agent = new praxo.Agent({
    model: new ScriptModel([toolResponse(), finalResponse()]),
    tools,
    interruptOn: ["echo"],
    onInterruptDecision: decision,
    ...extra,
  });
  return { agent, calls };
}

test("approve runs the tool with original arguments", async () => {
  const { agent, calls } = buildAgent(() => ({
    action: praxo.INTERRUPT_APPROVE,
  }));
  const result = await agent.run({ id: "s1" }, "go");
  assert.equal(result.output, "final");
  assert.deepEqual(calls, [{ value: "original" }]);
});

test("edit replaces arguments and reauthorizes", async () => {
  const actions = [];
  const policy = new praxo.FuncHook((action) => {
    if (action.kind === "tool.invoke") actions.push(action);
    return { allowed: true };
  });
  const { agent, calls } = buildAgent(
    () => ({
      action: praxo.INTERRUPT_EDIT,
      arguments: { value: "edited" },
    }),
    { policy }
  );
  const result = await agent.run({ id: "s1" }, "go");
  assert.equal(result.output, "final");
  assert.deepEqual(calls, [{ value: "edited" }]);
  assert.deepEqual(
    actions.map((action) => [action.toolName, action.arguments.value]),
    [
      ["echo", "original"],
      ["echo", "edited"],
    ]
  );
});

test("reject fails without effects", async () => {
  const { agent, calls } = buildAgent(() => ({
    action: praxo.INTERRUPT_REJECT,
    reason: "not allowed",
  }));
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.ApprovalDeniedError
  );
  assert.deepEqual(calls, []);
});

test("respond skips the tool and feeds the response back", async () => {
  const calls = [];
  const tools = new praxo.Registry();
  tools.register(new EchoTool(calls));
  class RespondModel {
    constructor() {
      this.count = 0;
    }

    async generate(request) {
      this.count += 1;
      if (this.count === 1) return toolResponse();
      const message = [...request.messages]
        .reverse()
        .find((item) => item.role === praxo.ROLE_TOOL);
      return finalResponse(message ? message.content : "final");
    }
  }
  const agent = new praxo.Agent({
    model: new RespondModel(),
    tools,
    interruptOn: ["echo"],
    onInterruptDecision: () => ({
      action: praxo.INTERRUPT_RESPOND,
      response: "human answer",
    }),
  });
  const result = await agent.run({ id: "s1" }, "go");
  assert.equal(result.output, '"human answer"');
  assert.deepEqual(calls, []);
});

test("invalid decision fails", async () => {
  const { agent, calls } = buildAgent(() => ({ action: "invalid" }));
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.InterruptDecisionInvalidError
  );
  assert.deepEqual(calls, []);
});

test("edit without arguments fails", async () => {
  const { agent, calls } = buildAgent(() => ({
    action: praxo.INTERRUPT_EDIT,
  }));
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.InterruptDecisionInvalidError
  );
  assert.deepEqual(calls, []);
});

test("unhandled interrupt fails", async () => {
  const calls = [];
  const tools = new praxo.Registry();
  tools.register(new EchoTool(calls));
  const agent = new praxo.Agent({
    model: new ScriptModel([toolResponse(), finalResponse()]),
    tools,
    interruptOn: ["echo"],
  });
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.InterruptUnhandledError
  );
  assert.deepEqual(calls, []);
});

test("boolean approval can deny", async () => {
  const { agent, calls } = buildAgent(undefined, {
    onInterrupt: () => false,
  });
  await assert.rejects(
    agent.run({ id: "s1" }, "go"),
    (error) => error instanceof praxo.ApprovalDeniedError
  );
  assert.deepEqual(calls, []);
});

test("emits tool.interrupt", async () => {
  const events = [];
  const { agent } = buildAgent(
    () => ({ action: praxo.INTERRUPT_APPROVE }),
    { events: { emit: async (event) => events.push(event) } }
  );
  await agent.run({ id: "s1" }, "go");
  const interrupts = events.filter(
    (event) => event.type === "tool.interrupt"
  );
  assert.equal(interrupts.length, 1);
  assert.equal(interrupts[0].data.name, "echo");
  assert.deepEqual(interrupts[0].data.arguments, { value: "original" });
});
