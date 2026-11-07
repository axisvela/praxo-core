const assert = require("node:assert/strict");
const test = require("node:test");

const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

class FixtureModel {
  async generate(request) {
    const last = request.messages[request.messages.length - 1];
    if (last.role === ROLE_TOOL) {
      return { message: { role: ROLE_ASSISTANT, content: "recorded" } };
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        toolCalls: [
          { id: "record-1", name: "record", arguments: { target: "public" } },
        ],
      },
    };
  }
}

class RecordTool {
  constructor() {
    this.name = "record";
    this.description = "Record a target in an in-memory counter.";
    this.calls = 0;
  }

  async invoke() {
    this.calls += 1;
    return "recorded";
  }
}

function governedOptions(hook, allowed, extra = {}) {
  if (!hook) throw new Error("governed: mandatory policy is missing");
  if (!allowed || allowed.length === 0) {
    throw new Error("governed: explicit tool scope is required");
  }
  const tool = new RecordTool();
  const tools = new Registry();
  tools.register(tool);
  return {
    tool,
    options: {
      model: new FixtureModel(),
      tools,
      maxSteps: 3,
      policy: hook,
      allowedTools: [...allowed],
      ...extra,
    },
  };
}

function publicOnly(checked) {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind === "tool.invoke") {
      const target = action.arguments?.target;
      checked.push(target);
      return {
        allowed: target === "public",
        reason: "only the public target is permitted",
      };
    }
    return { allowed: false, reason: "unsupported action" };
  });
}

test("missing policy is rejected", () => {
  assert.throws(() => governedOptions(null, ["record"]), /mandatory policy/);
});

test("empty tool scope is rejected", () => {
  assert.throws(() => governedOptions(publicOnly([]), []), /explicit tool scope/);
});

test("final arguments are reauthorized", async () => {
  const checked = [];
  const { tool, options } = governedOptions(publicOnly(checked), ["record"]);
  options.middleware = [
    {
      beforeTool(call) {
        call.call.arguments = { target: "private" };
      },
    },
  ];
  const agent = new Agent(options);
  await assert.rejects(
    agent.run({ id: "compat-final-args" }, "record"),
    PolicyDeniedError
  );
  assert.equal(tool.calls, 0);
  assert.deepEqual(checked, ["public", "private"]);
});

test("policy error fails closed", async () => {
  const hook = new FuncHook((action) => {
    if (action.kind === "tool.invoke") {
      throw new Error("policy service unavailable");
    }
    return { allowed: true };
  });
  const { tool, options } = governedOptions(hook, ["record"]);
  const agent = new Agent(options);
  await assert.rejects(
    agent.run({ id: "compat-policy-error" }, "record"),
    /policy service unavailable/
  );
  assert.equal(tool.calls, 0);
});
