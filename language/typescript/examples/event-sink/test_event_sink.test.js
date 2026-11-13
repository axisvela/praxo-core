const test = require("node:test");
const assert = require("node:assert/strict");

const { RecordingSink, run, ROLE_ASSISTANT } = require("./event_sink");

class ToolThenAnswerModel {
  constructor() {
    this.calls = 0;
  }

  async generate() {
    this.calls += 1;
    if (this.calls === 1) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [
            {
              id: "call-1",
              name: "lookup",
              arguments: { key: "status" },
            },
          ],
        },
      };
    }
    return {
      message: { role: ROLE_ASSISTANT, content: "status: green" },
    };
  }
}

test("records run and tool events", async () => {
  const model = new ToolThenAnswerModel();
  const allSink = new RecordingSink();
  const toolSink = new RecordingSink();

  const output = await run(model, allSink, toolSink);

  assert.equal(output, "status: green");
  assert.deepEqual(allSink.types(), [
    "run.started",
    "tool.call",
    "run.completed",
  ]);
  assert.deepEqual(toolSink.types(), ["tool.call"]);
  assert.equal(toolSink.events[0].data.name, "lookup");
});
