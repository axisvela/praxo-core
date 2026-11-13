const { Agent } = require("@axisvela/praxo-core");

function createAgent(primary, fallback) {
  return new Agent({
    model: primary,
    fallbackModel: fallback,
    systemPrompt: "You are a concise assistant.",
    maxSteps: 2,
  });
}

async function run(primary, fallback, prompt = "Say hello.") {
  const result = await createAgent(primary, fallback).run(
    { id: "provider-fallback" },
    prompt
  );
  return result.output;
}

module.exports = { createAgent, run };
