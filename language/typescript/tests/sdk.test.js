const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const praxo = require("../dist");
const { runAll } = require("../dist/conformance/run");
const { checkParity } = require("../dist/conformance/parity");

test("SDK_VERSION matches package version", () => {
  const pkg = require("../package.json");
  assert.equal(praxo.SDK_VERSION, pkg.version);
});

test("all spec vectors pass", async () => {
  const failures = await runAll(path.resolve(__dirname, "../../.."));
  assert.deepEqual(failures, []);
});

test("missing required vector group fails", async () => {
  const source = path.resolve(__dirname, "../../..");
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "praxo-vectors-"));
  try {
    fs.mkdirSync(path.join(root, "spec", "vectors"), { recursive: true });
    fs.copyFileSync(
      path.join(source, "spec", "SPEC_VERSION"),
      path.join(root, "spec", "SPEC_VERSION")
    );
    fs.copyFileSync(
      path.join(source, "spec", "vectors", "toolcall.json"),
      path.join(root, "spec", "vectors", "toolcall.json")
    );
    const failures = await runAll(root);
    assert.ok(
      failures.some((failure) =>
        failure.detail.includes("missing required vector group")
      )
    );
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("TypeScript parity snapshot is current", () => {
  const failures = checkParity(path.resolve(__dirname, "../../.."));
  assert.deepEqual(failures, []);
});

test("agent runs a tool and returns the final answer", async () => {
  class ScriptedModel {
    constructor() {
      this.step = 0;
    }

    async generate() {
      this.step += 1;
      if (this.step === 1) {
        return {
          message: {
            role: "assistant",
            content: "",
            toolCalls: [{ id: "c1", name: "echo", arguments: { text: "hi" } }],
          },
        };
      }
      return { message: { role: "assistant", content: "done" } };
    }
  }

  const tools = new praxo.Registry();
  tools.register(new praxo.FuncTool("echo", "Echo", (args) => args));
  const events = [];
  const sink = { async emit(event) { events.push(event.type); } };
  const agent = new praxo.Agent({
    model: new ScriptedModel(),
    tools,
    events: sink,
  });
  const result = await agent.run({ id: "s1" }, "go");
  assert.equal(result.output, "done");
  assert.equal(result.steps, 2);
  assert.deepEqual(events, ["run.started", "tool.call", "run.completed"]);
});

test("context budget compacts under the limit", () => {
  const messages = [{ role: "system", content: "sys" }];
  for (let index = 0; index < 10; index += 1) {
    messages.push({ role: "user", content: `message ${index}` });
  }
  const budget = new praxo.ContextBudget(30, 2);
  const [out, ok] = budget.compact(messages);
  assert.equal(ok, true);
  assert.ok(praxo.estimateTokens(out) <= 30);
  assert.ok(out.some((message) => message.content.includes("context compacted")));
});

test("PII middleware redacts email", () => {
  const redactor = new praxo.PIIRedactor(praxo.defaultPiiRules());
  assert.equal(redactor.redact("a@b.com"), "[REDACTED:email]");
});

test("PII middleware redacts tool-call history", () => {
  const middleware = praxo.piiMiddleware(
    new praxo.PIIRedactor(praxo.defaultPiiRules())
  );
  const call = {
    runId: "r1",
    sessionId: "s1",
    request: {
      messages: [
        {
          role: "assistant",
          toolCalls: [
            {
              id: "call-1",
              name: "lookup",
              arguments: {
                email: "a@b.com",
                nested: { ssn: "123-45-6789" },
              },
            },
          ],
        },
      ],
    },
  };
  middleware.beforeModel(call);
  const args = call.request.messages[0].toolCalls[0].arguments;
  assert.equal(args.email, "[REDACTED:email]");
  assert.equal(args.nested.ssn, "[REDACTED:ssn]");
});

test("plugin manifest rejects unknown fields", () => {
  const valid = {
    schemaVersion: 1,
    id: "com.example.echo",
    version: "1.0.0",
    kind: "tool.provider.v1",
    entrypoint: { type: "process", command: "echo" },
    protocol: "jsonrpc-2",
    capabilities: [],
    permissions: {},
    limits: {},
    health: {},
    isolation: "process",
  };
  assert.equal(praxo.parseManifest(JSON.stringify(valid)).id, "com.example.echo");
  assert.throws(() =>
    praxo.parseManifest(JSON.stringify({ ...valid, extra: true }))
  );
});

test("path checker denies traversal", () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), "praxo-policy-"));
  try {
    const root = path.join(base, "root");
    fs.mkdirSync(root, { recursive: true });
    const checker = new praxo.PathChecker([
      { root, access: "readwrite" },
    ]);
    assert.equal(checker.allowed(path.join(root, "a.txt"), "read"), true);
    assert.equal(
      checker.allowed(path.join(base, "outside", "a.txt"), "read"),
      false
    );
  } finally {
    fs.rmSync(base, { recursive: true, force: true });
  }
});

test("checkpoint allowlist round-trips", () => {
  const allow = new praxo.Allowlist();
  allow.register("spec.payload", () => ({}));
  const data = allow.marshal("spec.payload", { value: "x" });
  assert.deepEqual(allow.unmarshal(data), { value: "x" });
  assert.throws(() =>
    allow.marshal("spec.missing", {})
  );
});

test("middleware argument changes are reauthorized", async () => {
  const calls = [];
  class Model {
    constructor() {
      this.step = 0;
    }
    async generate() {
      this.step += 1;
      if (this.step === 1) {
        return {
          message: {
            role: "assistant",
            content: "",
            toolCalls: [{ id: "c1", name: "echo", arguments: { text: "ok" } }],
          },
        };
      }
      return { message: { role: "assistant", content: "done" } };
    }
  }
  class Tool {
    constructor(name) {
      this.name = name;
      this.description = name;
      this.calls = [];
    }
    async invoke(args) {
      this.calls.push(args);
      return args;
    }
  }
  const tool = new Tool("echo");
  const tools = new praxo.Registry();
  tools.register(tool);
  const actions = [];
  const hook = {
    authorize(action) {
      actions.push(action);
      return {
        allowed: !(action.arguments && action.arguments.text === "denied"),
        reason: "fixture",
      };
    },
  };
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    policy: hook,
    middleware: [
      {
        beforeTool(call) {
          call.call.arguments = { text: "denied" };
        },
      },
    ],
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /denied/);
  assert.deepEqual(tool.calls, []);
  const toolActions = actions.filter((action) => action.kind === "tool.invoke");
  assert.deepEqual(
    toolActions.map((action) => [action.toolName, action.arguments]),
    [
      ["echo", { text: "ok" }],
      ["echo", { text: "denied" }],
    ]
  );
});

test("middleware name changes use the final tool and authorization", async () => {
  class Model {
    constructor() {
      this.step = 0;
    }
    async generate() {
      this.step += 1;
      if (this.step === 1) {
        return {
          message: {
            role: "assistant",
            content: "",
            toolCalls: [{ id: "c1", name: "echo", arguments: {} }],
          },
        };
      }
      return { message: { role: "assistant", content: "done" } };
    }
  }
  class Tool {
    constructor(name) {
      this.name = name;
      this.description = name;
      this.calls = [];
    }
    async invoke(args) {
      this.calls.push(args);
      return args;
    }
  }
  const original = new Tool("echo");
  const replacement = new Tool("admin");
  const tools = new praxo.Registry();
  tools.register(original);
  tools.register(replacement);
  const actions = [];
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    policy: {
      authorize(action) {
        actions.push(action);
        return { allowed: true };
      },
    },
    middleware: [
      {
        beforeTool(call) {
          call.call.name = "admin";
        },
      },
    ],
  });
  const result = await agent.run({ id: "s1" }, "go");
  assert.equal(result.output, "done");
  assert.deepEqual(original.calls, []);
  assert.deepEqual(replacement.calls, [{}]);
  assert.deepEqual(
    actions
      .filter((action) => action.kind === "tool.invoke")
      .map((action) => action.toolName),
    ["echo", "admin"]
  );
});

test("unchanged tool is authorized once", async () => {
  class Model {
    constructor() {
      this.step = 0;
    }
    async generate() {
      this.step += 1;
      if (this.step === 1) {
        return {
          message: {
            role: "assistant",
            content: "",
            toolCalls: [{ id: "c1", name: "echo", arguments: { text: "ok" } }],
          },
        };
      }
      return { message: { role: "assistant", content: "done" } };
    }
  }
  class Tool {
    constructor() {
      this.name = "echo";
      this.description = "echo";
      this.calls = [];
    }
    async invoke(args) {
      this.calls.push(args);
      return args;
    }
  }
  const tool = new Tool();
  const tools = new praxo.Registry();
  tools.register(tool);
  const actions = [];
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    policy: {
      authorize(action) {
        actions.push(action);
        return { allowed: true };
      },
    },
  });
  await agent.run({ id: "s1" }, "go");
  assert.equal(
    actions.filter((action) => action.kind === "tool.invoke").length,
    1
  );
  assert.deepEqual(tool.calls, [{ text: "ok" }]);
});

test("final name must remain allowed", async () => {
  class Model {
    constructor() {
      this.step = 0;
    }
    async generate() {
      this.step += 1;
      if (this.step === 1) {
        return {
          message: {
            role: "assistant",
            content: "",
            toolCalls: [{ id: "c1", name: "echo", arguments: {} }],
          },
        };
      }
      return { message: { role: "assistant", content: "done" } };
    }
  }
  class Tool {
    constructor(name) {
      this.name = name;
      this.description = name;
      this.calls = [];
    }
    async invoke(args) {
      this.calls.push(args);
      return args;
    }
  }
  const original = new Tool("echo");
  const replacement = new Tool("admin");
  const tools = new praxo.Registry();
  tools.register(original);
  tools.register(replacement);
  let middlewareRan = false;
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    allowedTools: ["echo"],
    middleware: [
      {
        beforeTool(call) {
          middlewareRan = true;
          call.call.name = "admin";
        },
      },
    ],
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /not allowed/);
  assert.equal(middlewareRan, true);
  assert.deepEqual(original.calls, []);
  assert.deepEqual(replacement.calls, []);
});

test("initial policy denial prevents middleware and effect", async () => {
  class Model {
    async generate() {
      return {
        message: {
          role: "assistant",
          content: "",
          toolCalls: [{ id: "c1", name: "echo", arguments: {} }],
        },
      };
    }
  }
  class Tool {
    constructor(name) {
      this.name = name;
      this.description = name;
      this.calls = [];
    }
    async invoke(args) {
      this.calls.push(args);
      return args;
    }
  }
  const tool = new Tool("echo");
  const tools = new praxo.Registry();
  tools.register(tool);
  let middlewareRan = false;
  const agent = new praxo.Agent({
    model: new Model(),
    tools,
    policy: {
      authorize(action) {
        return {
          allowed: action.kind !== "tool.invoke",
          reason: "fixture",
        };
      },
    },
    middleware: [
      {
        beforeTool() {
          middlewareRan = true;
        },
      },
    ],
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /denied/);
  assert.equal(middlewareRan, false);
  assert.deepEqual(tool.calls, []);
});

test("startup failure cleans entered middleware without run events", async () => {
  const calls = [];
  const events = [];
  const first = {
    beforeRun() {
      calls.push("first.before");
    },
    afterRun(result, error) {
      calls.push(`first.after:${error instanceof Error ? error.name : "unknown"}`);
    },
  };
  const second = {
    beforeRun() {
      calls.push("second.before");
      throw new Error("startup failed");
    },
    afterRun() {
      calls.push("second.after");
    },
  };
  const third = {
    beforeRun() {
      calls.push("third.before");
    },
    afterRun() {
      calls.push("third.after");
    },
  };
  const agent = new praxo.Agent({
    model: { generate: async () => ({ message: { role: "assistant", content: "done" } }) },
    events: { emit: async (event) => events.push(event.type) },
    middleware: [first, second, third],
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /startup failed/);
  assert.deepEqual(calls, [
    "first.before",
    "second.before",
    "first.after:Error",
    "second.after",
  ]);
  assert.deepEqual(events, []);
});

test("cleanup continues and preserves the run error", async () => {
  const calls = [];
  const agent = new praxo.Agent({
    model: {
      generate: async () => {
        throw new Error("run failed");
      },
    },
    middleware: [
      {
        afterRun() {
          calls.push("first.after");
          throw new Error("cleanup failed");
        },
      },
      {
        afterRun() {
          calls.push("second.after");
        },
      },
    ],
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /run failed/);
  assert.deepEqual(calls, ["first.after", "second.after"]);
});

test("cleanup error after success fails closed", async () => {
  const calls = [];
  const events = [];
  const agent = new praxo.Agent({
    model: { generate: async () => ({ message: { role: "assistant", content: "done" } }) },
    events: { emit: async (event) => events.push(event.type) },
    middleware: [
      {
        afterRun() {
          calls.push("first.after");
          throw new Error("cleanup failed");
        },
      },
      {
        afterRun() {
          calls.push("second.after");
        },
      },
    ],
  });
  await assert.rejects(agent.run({ id: "s1" }, "go"), /cleanup failed/);
  assert.deepEqual(calls, ["first.after", "second.after"]);
  assert.deepEqual(events, ["run.started", "run.failed"]);
});

test("cancellation runs after-run and emits failed", async () => {
  const controller = new AbortController();
  let start;
  const started = new Promise((resolve) => {
    start = resolve;
  });
  const calls = [];
  const events = [];
  const agent = new praxo.Agent({
    model: {
      async generate() {
        start();
        return await new Promise((resolve, reject) => {
          controller.signal.addEventListener(
            "abort",
            () => reject(new Error("aborted")),
            { once: true }
          );
        });
      },
    },
    events: { emit: async (event) => events.push(event.type) },
    middleware: [
      {
        afterRun(result, error) {
          calls.push(error instanceof Error ? error.message : String(error));
        },
      },
    ],
    signal: controller.signal,
  });
  const run = agent.run({ id: "s1" }, "go");
  await started;
  controller.abort();
  await assert.rejects(run, /aborted/);
  assert.deepEqual(calls, ["aborted"]);
  assert.deepEqual(events, ["run.started", "run.failed"]);
});

test("tool cancellation runs after-run and emits failed", async () => {
  const controller = new AbortController();
  let start;
  const started = new Promise((resolve) => {
    start = resolve;
  });
  const calls = [];
  const events = [];
  const tool = {
    name: "wait",
    description: "wait",
    async invoke() {
      start();
      return await new Promise((resolve, reject) => {
        controller.signal.addEventListener(
          "abort",
          () => reject(new Error("tool aborted")),
          { once: true }
        );
      });
    },
  };
  const tools = new praxo.Registry();
  tools.register(tool);
  let step = 0;
  const agent = new praxo.Agent({
    model: {
      async generate() {
        step += 1;
        if (step === 1) {
          return {
            message: {
              role: "assistant",
              content: "",
              toolCalls: [{ id: "c1", name: "wait", arguments: {} }],
            },
          };
        }
        return { message: { role: "assistant", content: "done" } };
      },
    },
    tools,
    events: { emit: async (event) => events.push(event.type) },
    middleware: [
      {
        afterRun(result, error) {
          calls.push(error instanceof Error ? error.message : String(error));
        },
      },
    ],
    signal: controller.signal,
  });
  const run = agent.run({ id: "s1" }, "go");
  await started;
  controller.abort();
  await assert.rejects(run, /tool aborted/);
  assert.deepEqual(calls, ["tool aborted"]);
  assert.deepEqual(events, ["run.started", "tool.call", "run.failed"]);
});
