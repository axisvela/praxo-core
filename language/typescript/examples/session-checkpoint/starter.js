const {
  Agent,
  Allowlist,
  ROLE_ASSISTANT,
  ROLE_USER,
} = require("@axisvela/praxo-core");

class TurnModel {
  async generate(request) {
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: `turn ${request.messages.length}`,
      },
    };
  }
}

class MemoryStore {
  constructor() {
    this.records = new Map();
  }

  save(sessionId, payload) {
    this.records.set(sessionId, payload);
  }

  load(sessionId) {
    return this.records.get(sessionId);
  }
}

function checkpointPayload(allowlist, session) {
  return allowlist.marshal("session", { messages: session.messages });
}

function restore(allowlist, payload) {
  return allowlist.unmarshal(payload).messages;
}

async function run(write = (line) => console.log(line)) {
  const allowlist = new Allowlist();
  allowlist.register("session", () => ({ messages: [] }));
  const store = new MemoryStore();
  const session = {
    id: "session-1",
    messages: [
      { role: ROLE_USER, content: "first" },
      { role: ROLE_ASSISTANT, content: "ack" },
    ],
  };
  store.save(session.id, checkpointPayload(allowlist, session));

  const agent = new Agent({ model: new TurnModel(), maxSteps: 2 });

  let stored = store.load(session.id);
  session.messages = restore(allowlist, stored);
  let result = await agent.run(session, "second");
  if (result.output !== "turn 3") {
    throw new Error(`unexpected second turn: ${result.output}`);
  }

  session.messages.push({ role: ROLE_USER, content: "second" });
  session.messages.push({ role: ROLE_ASSISTANT, content: result.output });
  store.save(session.id, checkpointPayload(allowlist, session));

  stored = store.load(session.id);
  session.messages = restore(allowlist, stored);
  result = await agent.run(session, "third");
  if (result.output !== "turn 5") {
    throw new Error(`unexpected third turn: ${result.output}`);
  }

  write(`restored messages: ${session.messages.length}`);
  write(`output: ${result.output}`);
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { run };
