const {
  Agent,
  FuncHook,
  INTERRUPT_APPROVE,
  INTERRUPT_EDIT,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

class FixtureModel {
  async generate(request) {
    const last = request.messages[request.messages.length - 1];
    if (last.role === ROLE_TOOL) {
      return { message: { role: ROLE_ASSISTANT, content: "done" } };
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        toolCalls: [
          {
            id: "write-note-1",
            name: "write_note",
            arguments: { text: "hello", visibility: "public" },
          },
        ],
      },
    };
  }
}

class WriteNoteTool {
  constructor() {
    this.name = "write_note";
    this.description = "Write a short note with the requested visibility.";
    this.risk = "write";
    this.parameters = {
      type: "object",
      required: ["text", "visibility"],
      properties: {
        text: { type: "string" },
        visibility: { type: "string", enum: ["public", "private"] },
      },
    };
    this.notes = [];
  }

  async invoke(args) {
    this.notes.push(args.text);
    return "written";
  }
}

function publicNotesPolicy(action) {
  if (action.kind === "model.generate") {
    return { allowed: true };
  }
  if (action.kind === "tool.invoke") {
    return {
      allowed:
        action.toolName === "write_note" &&
        action.arguments?.visibility === "public",
      reason: "only public notes are permitted",
    };
  }
  return { allowed: false, reason: "unsupported action" };
}

function buildAgent(decision) {
  const tool = new WriteNoteTool();
  const tools = new Registry();
  tools.register(tool);
  const agent = new Agent({
    model: new FixtureModel(),
    tools,
    maxSteps: 3,
    allowedTools: ["write_note"],
    policy: new FuncHook(publicNotesPolicy),
    interruptOn: ["write_note"],
    onInterruptDecision: () => decision,
  });
  return { agent, tool };
}

async function run(write = (line) => console.log(line)) {
  const approved = buildAgent({ action: INTERRUPT_APPROVE });
  const result = await approved.agent.run(
    { id: "hitl-approve" },
    "Write a note."
  );
  if (result.output !== "done" || approved.tool.notes.length !== 1) {
    throw new Error(
      `approve scenario failed: output=${result.output} effects=${approved.tool.notes.length}`
    );
  }
  write("approve: written; effects=1");

  const edited = buildAgent({
    action: INTERRUPT_EDIT,
    arguments: { text: "hello", visibility: "private" },
  });
  try {
    await edited.agent.run({ id: "hitl-edit" }, "Write a note.");
  } catch (error) {
    if (!(error instanceof PolicyDeniedError)) {
      throw error;
    }
    if (edited.tool.notes.length !== 0) {
      throw new Error(`edit produced effects=${edited.tool.notes.length}`);
    }
    write("edit: policy rejected; effects=0");
    return;
  }
  throw new Error("edited private note was not denied");
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { buildAgent, run };
