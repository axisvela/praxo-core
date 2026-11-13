const assert = require("node:assert/strict");
const test = require("node:test");

const {
  SubagentManager,
  SubagentUpdateUnsupported,
} = require("../dist");

function request() {
  return {
    parentSessionId: "parent",
    agentId: "child",
    prompt: "do work",
    mode: "fork",
  };
}

test("launch and wait complete a child run", async () => {
  const runner = {
    async run() {
      return { output: "done" };
    },
  };
  const manager = new SubagentManager(runner);
  const task = await manager.launch(request());
  assert.equal(task.parentSessionId, "parent");
  assert.equal(task.agentId, "child");
  assert.equal(task.mode, "fork");
  const final = await manager.wait(task.id, 2000);
  assert.equal(final.status, "completed");
  assert.equal(final.output, "done");
});

test("failure is reported", async () => {
  const manager = new SubagentManager({
    async run() {
      throw new Error("boom");
    },
  });
  const task = await manager.launch(request());
  const final = await manager.wait(task.id, 2000);
  assert.equal(final.status, "failed");
  assert.match(final.error, /boom/);
});

test("cancel marks a running task canceled", async () => {
  const manager = new SubagentManager({ run: () => new Promise(() => {}) });
  const task = await manager.launch(request());
  await new Promise((resolve) => setImmediate(resolve));
  await manager.cancel(task.id);
  const final = await manager.wait(task.id, 2000);
  assert.equal(final.status, "canceled");
});

test("update forwards to a controllable runner", async () => {
  let release;
  const updates = [];
  const runner = {
    async run() {
      await new Promise((resolve) => {
        release = resolve;
      });
      return { output: "released" };
    },
    async update(taskId, prompt) {
      updates.push([taskId, prompt]);
    },
  };
  const manager = new SubagentManager(runner);
  const task = await manager.launch(request());
  await new Promise((resolve) => setImmediate(resolve));
  await manager.update(task.id, "steer");
  assert.deepEqual(updates, [[task.id, "steer"]]);
  release();
  const final = await manager.wait(task.id, 2000);
  assert.equal(final.status, "completed");
});

test("update is rejected without a controllable runner", async () => {
  const manager = new SubagentManager({ run: () => new Promise(() => {}) });
  const task = await manager.launch(request());
  await new Promise((resolve) => setImmediate(resolve));
  await assert.rejects(
    () => manager.update(task.id, "steer"),
    SubagentUpdateUnsupported
  );
  await manager.cancel(task.id);
});

test("unknown tasks are rejected", async () => {
  const manager = new SubagentManager({ async run() { return { output: "" }; } });
  assert.equal(manager.check("missing"), undefined);
  await assert.rejects(() => manager.wait("missing", 100));
});
