const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const praxo = require("../dist");
const { runAll } = require("../dist/conformance/run");
const { checkParity } = require("../dist/conformance/parity");

test("all spec vectors pass", async () => {
  const failures = await runAll(path.resolve(__dirname, "../.."));
  assert.deepEqual(failures, []);
});

test("TypeScript parity snapshot is current", () => {
  const failures = checkParity(path.resolve(__dirname, "../.."));
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
