const { Agent, ROLE_ASSISTANT } = require("@axisvela/praxo-core");

class StreamingModel {
  constructor(chunks) {
    this.chunks = chunks;
  }

  async generate() {
    return {
      message: { role: ROLE_ASSISTANT, content: this.chunks.join("") },
    };
  }

  async generateStream(request, onDelta) {
    for (const chunk of this.chunks) onDelta(chunk);
    return this.generate(request);
  }
}

async function run(model, onDelta, prompt = "Check the status.") {
  const agent = new Agent({
    model,
    onDelta,
    systemPrompt: "Answer with the current status.",
    maxSteps: 2,
  });
  const result = await agent.run({ id: "streaming" }, prompt);
  return result.output;
}

module.exports = { StreamingModel, run };
