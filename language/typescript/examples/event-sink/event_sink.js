const {
  Agent,
  FilterSink,
  FuncTool,
  MultiSink,
  Registry,
  ROLE_ASSISTANT,
} = require("@axisvela/praxo-core");

class RecordingSink {
  constructor() {
    this.events = [];
  }

  async emit(event) {
    this.events.push(event);
  }

  types() {
    return this.events.map((event) => event.type);
  }
}

function createAgent(model, allSink, toolSink) {
  const tools = new Registry();
  tools.register(
    new FuncTool("lookup", "Look up a small status value.", (args) => ({
      key: args.key ?? "",
      value: "green",
    }))
  );
  const events = new MultiSink([
    allSink,
    new FilterSink(toolSink, (event) => event.type === "tool.call"),
  ]);
  return new Agent({
    model,
    tools,
    events,
    systemPrompt: "Use tools when asked for status.",
    maxSteps: 3,
  });
}

async function run(model, allSink, toolSink, prompt = "Check the status.") {
  const result = await createAgent(model, allSink, toolSink).run(
    { id: "event-sink" },
    prompt
  );
  return result.output;
}

module.exports = { RecordingSink, createAgent, run, ROLE_ASSISTANT };
