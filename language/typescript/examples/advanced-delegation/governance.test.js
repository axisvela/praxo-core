const assert = require("node:assert/strict");
const test = require("node:test");

const { FuncHook, PolicyDeniedError, Registry } = require("@axisvela/praxo-core");
const {
  BudgetExhausted,
  DelegationError,
  Governor,
  SharedBudget,
  allowAll,
  recordPolicy,
} = require("./governance");
const {
  FixtureModel,
  ParentOnlyTool,
  RecordTool,
} = require("./delegation");

function governor(overrides = {}) {
  return new Governor({
    allowed: new Set(["record"]),
    delegable: new Set(["record"]),
    maxDepth: 1,
    maxChildren: 1,
    budget: new SharedBudget(2),
    policy: new FuncHook(allowAll),
    ...overrides,
  });
}

test("governed delegation rejects scope escalation", async () => {
  const record = new RecordTool();
  const parentOnly = new ParentOnlyTool();
  const tools = new Registry();
  tools.register(record);
  tools.register(parentOnly);
  const root = governor({
    allowed: new Set(["record", "parent_only"]),
    maxChildren: 2,
  });
  assert.throws(
    () => root.delegate({ allowed: ["parent_only"] }),
    DelegationError
  );
  assert.equal(record.calls, 0);
  assert.equal(parentOnly.calls, 0);
  const child = root.delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  child.release();
});

test("governed delegation rejects excess depth", () => {
  const root = governor();
  const child = root.delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  child.authority.delegable = new Set(["record"]);
  assert.throws(
    () => new Governor(child.authority).delegate({ allowed: ["record"] }),
    DelegationError
  );
  child.release();
});

test("governed delegation rejects excess children", () => {
  const root = governor();
  const first = root.delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  assert.throws(
    () => root.delegate({ allowed: ["record"] }),
    DelegationError
  );
  first.release();
  const second = root.delegate({ allowed: ["record"] });
  second.release();
});

test("governed delegation shares the sibling budget", async () => {
  const record = new RecordTool();
  const tools = new Registry();
  tools.register(record);
  const root = governor({
    maxChildren: 2,
    budget: new SharedBudget(1),
  });
  const first = root.delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  const second = root.delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  try {
    await first.run(
      new FixtureModel("record", { target: "first" }, "first-done"),
      tools,
      "record once"
    );
    await assert.rejects(
      () =>
        second.run(
          new FixtureModel("record", { target: "second" }, "second-done"),
          tools,
          "record twice"
        ),
      BudgetExhausted
    );
  } finally {
    first.release();
    second.release();
  }
  assert.equal(record.calls, 1);
});

test("governed delegation cancels before effects", async () => {
  const record = new RecordTool();
  const tools = new Registry();
  tools.register(record);
  const controller = new AbortController();
  const child = governor().delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  try {
    await assert.rejects(
      () =>
        child.run(
          new FixtureModel("record", { target: "safe" }, "unexpected"),
          tools,
          "cancel before effect",
          {
            signal: controller.signal,
            middleware: [
              {
                beforeTool() {
                  controller.abort();
                },
              },
            ],
          }
        ),
      (error) => error.name === "AbortError"
    );
  } finally {
    child.release();
  }
  assert.equal(record.calls, 0);
});

test("governed delegation reauthorizes final arguments", async () => {
  const record = new RecordTool();
  const tools = new Registry();
  tools.register(record);
  const child = governor().delegate({
    allowed: ["record"],
    policy: new FuncHook(recordPolicy),
  });
  try {
    await assert.rejects(
      () =>
        child.run(
          new FixtureModel("record", { target: "safe" }, "unexpected"),
          tools,
          "record safely",
          {
            middleware: [
              {
                beforeTool(call) {
                  call.call.arguments.target = "blocked";
                },
              },
            ],
          }
        ),
      PolicyDeniedError
    );
  } finally {
    child.release();
  }
  assert.equal(record.calls, 0);
});
