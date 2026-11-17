const {
  Agent,
  FuncHook,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
  PolicyDeniedError,
} = require("@axisvela/praxo-core");

class FixtureModel {
  constructor(toolName, args, final) {
    this.toolName = toolName;
    this.args = args;
    this.final = final;
    this.calls = 0;
  }

  async generate(request) {
    this.calls += 1;
    const last = request.messages[request.messages.length - 1];
    if (last.role === ROLE_TOOL) {
      return { message: { role: ROLE_ASSISTANT, content: this.final } };
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        toolCalls: [
          {
            id: `call-${this.calls}`,
            name: this.toolName,
            arguments: this.args,
          },
        ],
      },
    };
  }
}

class RecordTool {
  constructor() {
    this.name = "record";
    this.description = "Record a child result in an in-memory counter.";
    this.risk = "write";
    this.parameters = {
      type: "object",
      required: ["target"],
      properties: { target: { type: "string" } },
    };
    this.calls = 0;
  }

  async invoke(args) {
    this.calls += 1;
    return `recorded:${args.target || ""}`;
  }
}

class ParentOnlyTool {
  constructor() {
    this.name = "parent_only";
    this.description = "A tool that must remain outside the child scope.";
    this.risk = "write";
    this.parameters = { type: "object", properties: {} };
    this.calls = 0;
  }

  async invoke() {
    this.calls += 1;
    return "parent-effect";
  }
}

function buildChild(record) {
  const tools = new Registry();
  tools.register(record);
  const policy = new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind === "tool.invoke") {
      return {
        allowed: action.toolName === "record",
        reason: "child may only record",
      };
    }
    return { allowed: false, reason: "unsupported action" };
  });
  return new Agent({
    model: new FixtureModel("record", { target: "delegated" }, "child-recorded"),
    tools,
    maxSteps: 3,
    allowedTools: ["record"],
    policy,
    requirePolicy: true,
    requireToolScope: true,
  });
}

class DelegateTool {
  constructor(record) {
    this.record = record;
    this.name = "delegate";
    this.description = "Run the child agent with a restricted tool scope.";
    this.risk = "write";
    this.parameters = {
      type: "object",
      required: ["task"],
      properties: { task: { type: "string" } },
    };
  }

  async invoke(args) {
    const child = buildChild(this.record);
    const result = await child.run(
      { id: "advanced-delegation-child" },
      String(args.task || "")
    );
    return { output: result.output, effects: this.record.calls };
  }
}

function buildParent(record) {
  const tools = new Registry();
  tools.register(new DelegateTool(record));
  tools.register(new ParentOnlyTool());
  const policy = new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind === "tool.invoke") {
      return {
        allowed: ["delegate", "parent_only"].includes(action.toolName),
        reason: "parent may delegate but not record",
      };
    }
    return { allowed: false, reason: "unsupported action" };
  });
  return new Agent({
    model: new FixtureModel(
      "delegate",
      { task: "record the delegated result" },
      "parent-done"
    ),
    tools,
    maxSteps: 3,
    allowedTools: ["delegate", "parent_only"],
    policy,
    requirePolicy: true,
    requireToolScope: true,
  });
}

async function run(write = (line) => console.log(line)) {
  const record = new RecordTool();
  const parent = buildParent(record);
  const result = await parent.run(
    { id: "advanced-delegation-parent" },
    "Delegate the record operation to the child agent."
  );
  if (result.output !== "parent-done" || record.calls !== 1) {
    throw new Error(
      `delegation failed: output=${JSON.stringify(result.output)} effects=${record.calls}`
    );
  }
  write("delegation: child recorded; parent scope enforced");

  const tools = new Registry();
  tools.register(record);
  const denied = new Agent({
    model: new FixtureModel("record", { target: "parent" }, "unexpected"),
    tools,
    maxSteps: 3,
    allowedTools: ["record"],
    policy: new FuncHook((action) => ({
      allowed: action.kind === "model.generate",
      reason: "parent may not record",
    })),
    requirePolicy: true,
    requireToolScope: true,
  });
  try {
    await denied.run({ id: "advanced-delegation-direct" }, "Record directly.");
  } catch (error) {
    if (!(error instanceof PolicyDeniedError)) throw error;
    if (record.calls !== 1) {
      throw new Error("denied parent call produced a child effect");
    }
    write("deny: parent record blocked; child effect unchanged");
    return;
  }
  throw new Error("parent recorded outside the delegated scope");
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  FixtureModel,
  ParentOnlyTool,
  RecordTool,
  buildChild,
  buildParent,
  run,
};
