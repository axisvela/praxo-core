const {
  Agent,
  FuncHook,
  FuncTool,
  OpenAICompatibleModel,
  Registry,
} = require("@axisvela/praxo-core");

function envOr(name, fallback) {
  return process.env[name] || fallback;
}

async function main() {
  const baseUrl = envOr("PRAXO_BASE_URL", "http://localhost:11434/v1");
  const modelName = envOr("PRAXO_MODEL", "llama3.2");
  const prompt = envOr(
    "PRAXO_PROMPT",
    "What time is it? Use the get_time tool and reply with the time."
  );

  const tools = new Registry();
  const getTime = new FuncTool(
    "get_time",
    "Return the current time in ISO 8601 format.",
    () => new Date().toISOString()
  );
  getTime.parameters = { type: "object", properties: {} };
  getTime.risk = "read";
  tools.register(getTime);

  const policy = new FuncHook((action) => {
    if (action.kind === "model.generate") {
      return { allowed: true };
    }
    if (action.kind === "tool.invoke") {
      return {
        allowed: action.toolName === "get_time",
        reason: "only get_time is permitted",
      };
    }
    return { allowed: false, reason: "unsupported action" };
  });

  const agent = new Agent({
    model: new OpenAICompatibleModel({
      baseUrl,
      apiKey: process.env.PRAXO_API_KEY || "",
      model: modelName,
    }),
    tools,
    systemPrompt:
      "You are a concise assistant. Use the provided tools when they help.",
    maxSteps: 4,
    allowedTools: ["get_time"],
    policy,
  });

  try {
    const result = await agent.run({ id: "live-model" }, prompt);
    console.log(result.output);
  } catch (error) {
    console.error(
      `live model run failed: ${error.message}\n\n` +
        `Check PRAXO_BASE_URL (${baseUrl}), PRAXO_MODEL (${modelName}), and PRAXO_API_KEY`
    );
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main();
}

module.exports = { main };
