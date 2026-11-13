const {
  Agent,
  OpenAICompatibleModel,
  StructuredOutput,
} = require("@axisvela/praxo-core");

const SUMMARY_SCHEMA = {
  type: "object",
  required: ["title", "summary", "tags"],
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    tags: {
      type: "array",
      items: { type: "string" },
    },
  },
};

function envOr(name, fallback) {
  return process.env[name] || fallback;
}

async function summarize(text, model) {
  const selected =
    model ||
    new OpenAICompatibleModel({
      baseUrl: envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
      apiKey: process.env.PRAXO_API_KEY || "",
      model: envOr("PRAXO_MODEL", "llama3.2"),
    });

  const agent = new Agent({
    model: selected,
    systemPrompt:
      "Summarize the supplied text as JSON with title, summary, and tags. Return only JSON.",
    structuredOutput: new StructuredOutput({
      schema: SUMMARY_SCHEMA,
      name: "summary",
    }),
  });

  const result = await agent.run({ id: "structured-output" }, text);
  return result.output;
}

async function main() {
  const text = process.argv.slice(2).join(" ").trim();
  if (!text) {
    console.error("usage: node summarize.js <text>");
    process.exitCode = 2;
    return;
  }
  try {
    console.log(await summarize(text));
  } catch (error) {
    console.error(
      `structured output run failed: ${error.message}\n\n` +
        "Check PRAXO_BASE_URL, PRAXO_MODEL, and PRAXO_API_KEY"
    );
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main();
}

module.exports = { summarize, SUMMARY_SCHEMA };
