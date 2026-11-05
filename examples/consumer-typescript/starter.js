const {
  Agent,
  FuncHook,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
  PolicyDeniedError,
} = require("@axisvela/praxo-core");

class FixtureModel {
  constructor(target) {
    this.target = target;
  }

  async generate(request) {
    const last = request.messages[request.messages.length - 1];
    if (last.role === ROLE_TOOL) {
      return { message: { role: ROLE_ASSISTANT, content: "recorded" } };
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        toolCalls: [
          {
            id: "record-1",
            name: "record",
            arguments: { target: this.target },
          },
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

function buildAgent(target) {
  const tool = new RecordTool();
  const tools = new Registry();
  tools.register(tool);
  const policy = new FuncHook((action) => {
    if (action.kind === "model.generate") {
      return { allowed: true };
    }
    if (action.kind === "tool.invoke") {
      return {
        allowed:
          action.toolName === "record" &&
          action.arguments?.target === "public",
        reason: "only the public target is permitted",
      };
    }
    return { allowed: false, reason: "unsupported action" };
  });
  const agent = new Agent({
    model: new FixtureModel(target),
    tools,
    maxSteps: 3,
    allowedTools: ["record"],
    policy,
  });
  return { agent, tool };
}

async function run(write = (line) => console.log(line)) {
  const allowed = buildAgent("public");
  const result = await allowed.agent.run(
    { id: "starter-public" },
    "Record the requested target."
  );
  if (result.output !== "recorded" || allowed.tool.calls !== 1) {
    throw new Error(
      `allow verification failed: output=${JSON.stringify(result.output)} effects=${allowed.tool.calls}`
    );
  }
  write("allow: recorded; effects=1");

  const denied = buildAgent("private");
  try {
    await denied.agent.run(
      { id: "starter-private" },
      "Record the requested target."
    );
  } catch (error) {
    if (!(error instanceof PolicyDeniedError)) {
      throw error;
    }
    if (denied.tool.calls !== 0) {
      throw new Error(`denied call produced effects=${denied.tool.calls}`);
    }
    write("deny: policy rejected; effects=0");
    return;
  }
  throw new Error("private target was not denied");
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { buildAgent, run };
