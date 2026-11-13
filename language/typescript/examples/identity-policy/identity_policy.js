const {
  Agent,
  FuncHook,
  FuncTool,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const SESSION_ID = "session-1";

class PrincipalStore {
  constructor() {
    this.principals = new Map();
  }

  bind(sessionId, principal) {
    this.principals.set(sessionId, principal);
  }

  lookup(sessionId) {
    return this.principals.get(sessionId);
  }
}

class RecordingTool {
  constructor() {
    this.calls = 0;
  }

  invoke() {
    this.calls += 1;
    return "recorded";
  }
}

function authorize(store, action) {
  const principal = store.lookup(action.sessionId);
  if (!principal) return { allowed: false, reason: "trusted principal is missing" };
  if (!principal.active) return { allowed: false, reason: "trusted principal is inactive" };
  if (action.kind === "model.generate") {
    return { allowed: true, reason: "principal may run the agent" };
  }
  if (action.kind !== "tool.invoke") {
    return { allowed: false, reason: "unsupported action" };
  }
  if (principal.role !== "operator") {
    return { allowed: false, reason: "role is not permitted" };
  }
  if (action.arguments?.tenant !== principal.tenant) {
    return { allowed: false, reason: "tenant does not match the principal" };
  }
  if (action.toolName !== "record") {
    return { allowed: false, reason: "operation is not permitted" };
  }
  return { allowed: true, reason: "verified operator" };
}

class ClaimingModel {
  constructor(tenant, role) {
    this.tenant = tenant;
    this.role = role;
  }

  async generate(request) {
    const last = request.messages[request.messages.length - 1];
    if (last?.role === ROLE_TOOL) {
      return { message: { role: ROLE_ASSISTANT, content: "recorded" } };
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        toolCalls: [
          {
            id: "record-1",
            name: "record",
            arguments: { tenant: this.tenant, role: this.role },
          },
        ],
      },
    };
  }
}

async function runCase(principal, claimedTenant = "acme", claimedRole = "admin") {
  const store = new PrincipalStore();
  if (principal) store.bind(SESSION_ID, principal);
  const tool = new RecordingTool();
  const tools = new Registry();
  tools.register(new FuncTool("record", "Record a target.", () => tool.invoke()));
  const agent = new Agent({
    model: new ClaimingModel(claimedTenant, claimedRole),
    tools,
    policy: new FuncHook((action) => authorize(store, action)),
    allowedTools: ["record"],
    maxSteps: 3,
  });
  try {
    const result = await agent.run({ id: SESSION_ID }, "record");
    if (result.output !== "recorded") {
      return { calls: tool.calls, error: new Error(result.output) };
    }
    return { calls: tool.calls, error: null };
  } catch (error) {
    return { calls: tool.calls, error };
  }
}

module.exports = {
  ClaimingModel,
  PrincipalStore,
  RecordingTool,
  authorize,
  runCase,
};
