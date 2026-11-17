const assert = require("node:assert/strict");

const {
  Agent,
  FuncHook,
  HarmovelaSink,
  McpClient,
  MultiSink,
  OtelSink,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  mcpTools,
} = require("@axisvela/praxo-core");

class FakeMcpTransport {
  constructor(effects) {
    this.effects = effects;
    this.handlers = [];
    this.closeHandlers = [];
    this.closed = false;
  }

  send(line) {
    const message = JSON.parse(line);
    const method = message.method;
    const id = message.id;
    const params = message.params || {};
    let result;
    if (method === "initialize") {
      result = {
        protocolVersion: params.protocolVersion || "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "fake-mcp", version: "0.0.1" },
      };
    } else if (method === "tools/list") {
      result = {
        tools: [
          {
            name: "record",
            description: "Record a target",
            inputSchema: {
              type: "object",
              properties: { target: { type: "string" } },
              required: ["target"],
            },
          },
        ],
      };
    } else if (method === "tools/call") {
      if (params.name !== "record") {
        result = {
          isError: true,
          content: [{ type: "text", text: "unknown tool" }],
        };
      } else {
        const target = String((params.arguments || {}).target || "");
        this.effects[target] = (this.effects[target] || 0) + 1;
        result = { content: [{ type: "text", text: `recorded:${target}` }] };
      }
    } else {
      result = {};
    }
    if (id !== undefined) {
      queueMicrotask(() => {
        for (const handler of this.handlers) {
          handler(JSON.stringify({ jsonrpc: "2.0", id, result }));
        }
      });
    }
  }

  onLine(handler) {
    this.handlers.push(handler);
  }

  onClose(handler) {
    this.closeHandlers.push(handler);
  }

  async close() {
    if (this.closed) return;
    this.closed = true;
    for (const handler of this.closeHandlers) handler();
  }
}

class ScriptedModel {
  constructor(steps, final) {
    this.steps = [...steps];
    this.final = final;
    this.calls = 0;
  }

  async generate() {
    this.calls += 1;
    if (this.steps.length > 0) {
      const step = this.steps.shift();
      return {
        message: {
          role: ROLE_ASSISTANT,
          content: step.content || "",
          toolCalls: step.toolCalls || [],
        },
      };
    }
    return { message: { role: ROLE_ASSISTANT, content: this.final } };
  }
}

class ComposedPolicy {
  constructor(hooks) {
    this.hooks = hooks.filter(Boolean);
  }

  async authorize(action) {
    for (const hook of this.hooks) {
      const decision = await hook.authorize(action);
      if (!decision.allowed) return decision;
    }
    return { allowed: true, reason: "delegation policy chain allowed" };
  }
}

function parentPolicy(action) {
  if (action.kind === "model.generate") return { allowed: true };
  if (action.kind !== "tool.invoke") {
    return { allowed: false, reason: "unsupported action" };
  }
  if (action.toolName === "record") {
    if ((action.arguments || {}).target === "blocked") {
      return { allowed: false, reason: "blocked target" };
    }
    return { allowed: true };
  }
  if (action.toolName === "delegate") return { allowed: true };
  return { allowed: false, reason: "parent tool is not allowed" };
}

function childOnlyPolicy(action) {
  if (action.kind === "model.generate") return { allowed: true };
  if (action.kind === "tool.invoke" && action.toolName === "record") {
    return { allowed: true };
  }
  return { allowed: false, reason: "child may only record" };
}

class DelegateTool {
  constructor(record, childModel, effects, events) {
    this.record = record;
    this.childModel = childModel;
    this.effects = effects;
    this.events = events;
    this.name = "delegate";
    this.description = "Run a governed child agent with the narrowed record scope";
    this.parameters = {
      type: "object",
      properties: { task: { type: "string" } },
      required: ["task"],
    };
  }

  async invoke() {
    const registry = new Registry();
    registry.register(this.record);
    const child = new Agent({
      model: this.childModel,
      tools: registry,
      maxSteps: 3,
      allowedTools: ["record"],
      policy: new ComposedPolicy([
        new FuncHook(parentPolicy),
        new FuncHook(childOnlyPolicy),
      ]),
      requirePolicy: true,
      requireToolScope: true,
      events: this.events,
    });
    const result = await child.run({ id: "chain-child" }, "record child");
    return { output: result.output, effects: this.effects.child || 0 };
  }
}

function otelTransport(log) {
  return (request) => {
    const payload = JSON.parse(request.body);
    for (const resource of payload.resourceSpans || []) {
      for (const scope of resource.scopeSpans || []) {
        for (const span of scope.spans || []) log.push(span.name);
      }
    }
    return { status: 200, body: "" };
  };
}

function harmovelaTransport(log) {
  return (request) => {
    const payload = JSON.parse(request.body);
    log.push(payload.type);
    return { status: 202, body: "" };
  };
}

async function runChain() {
  const effects = {};
  const transport = new FakeMcpTransport(effects);
  const client = await McpClient.connect({ transport });
  try {
    const tools = await client.listTools();
    const record = mcpTools(client, tools)[0];
    const otel = [];
    const harmovela = [];
    const events = new MultiSink([
      new OtelSink({ transport: otelTransport(otel) }),
      new HarmovelaSink({
        baseUrl: "http://harmovela.local",
        transport: harmovelaTransport(harmovela),
      }),
    ]);
    const childModel = new ScriptedModel(
      [
        {
          toolCalls: [
            { id: "child-record", name: "record", arguments: { target: "child" } },
          ],
        },
      ],
      "CHILD-DONE"
    );
    const parentModel = new ScriptedModel(
      [
        {
          toolCalls: [
            { id: "parent-record", name: "record", arguments: { target: "parent" } },
          ],
        },
        {
          toolCalls: [
            { id: "parent-delegate", name: "delegate", arguments: { task: "child" } },
          ],
        },
      ],
      "DONE"
    );
    const registry = new Registry();
    registry.register(record);
    registry.register(new DelegateTool(record, childModel, effects, events));
    const parent = new Agent({
      model: parentModel,
      tools: registry,
      maxSteps: 6,
      allowedTools: ["record", "delegate"],
      policy: new FuncHook(parentPolicy),
      requirePolicy: true,
      requireToolScope: true,
      events,
    });
    const result = await parent.run(
      { id: "chain-parent" },
      "run the representative chain"
    );
    return {
      output: result.output,
      effects: { ...effects },
      childCalls: childModel.calls,
      otel,
      harmovela,
    };
  } finally {
    await client.close();
  }
}

async function runDenial() {
  const effects = {};
  const transport = new FakeMcpTransport(effects);
  const client = await McpClient.connect({ transport });
  try {
    const tools = await client.listTools();
    const record = mcpTools(client, tools)[0];
    const registry = new Registry();
    registry.register(record);
    const model = new ScriptedModel(
      [
        {
          toolCalls: [
            { id: "denied-record", name: "record", arguments: { target: "safe" } },
          ],
        },
      ],
      "UNEXPECTED"
    );
    const agent = new Agent({
      model,
      tools: registry,
      maxSteps: 2,
      allowedTools: ["record"],
      policy: new FuncHook(parentPolicy),
      middleware: [
        {
          beforeTool(call) {
            call.call.arguments.target = "blocked";
          },
        },
      ],
      requirePolicy: true,
      requireToolScope: true,
    });
    try {
      await agent.run({ id: "chain-denial" }, "call record");
    } catch (error) {
      if (error instanceof PolicyDeniedError) {
        return { blocked: effects.blocked || 0, code: error.code };
      }
      throw error;
    }
    throw new Error("denial path unexpectedly succeeded");
  } finally {
    await client.close();
  }
}

async function main() {
  const result = await runChain();
  assert.equal(result.output, "DONE");
  assert.equal(result.effects.parent, 1);
  assert.equal(result.effects.child, 1);
  assert.ok(result.childCalls >= 2);
  for (const span of ["praxo.run.started", "praxo.tool.call", "praxo.run.completed"]) {
    assert.ok(result.otel.includes(span), span);
  }
  for (const kind of ["run.started", "tool.call", "run.completed"]) {
    assert.ok(result.harmovela.includes(kind), kind);
  }
  const denial = await runDenial();
  assert.equal(denial.blocked, 0);
  assert.equal(denial.code, "AGENT_POLICY_DENIED");
  console.log("output:", result.output);
  console.log("effects:", result.effects);
  console.log("child calls:", result.childCalls);
  console.log("otel spans:", result.otel.length);
  console.log("harmovela events:", result.harmovela.length);
  console.log("denied effects:", denial.blocked);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { main, runChain, runDenial };
