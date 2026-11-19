const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");

const { PluginCallError, ProcessHost } = require("../dist");

const fixture = path.join(__dirname, "fixtures", "process-plugin.cjs");

function config(overrides = {}) {
  return {
    pluginId: "com.example.echo",
    path: process.execPath,
    args: [fixture],
    startTimeoutMs: 5000,
    invokeTimeoutMs: 2000,
    gracePeriodMs: 2000,
    ...overrides,
  };
}

test("process host health and invoke", async () => {
  const host = new ProcessHost(config());
  await host.start();
  try {
    assert.equal(host.isActive, true);
    const payload = Buffer.from('{"text":"hi"}');
    assert.deepEqual(await host.invoke("tool.provider", "echo", payload), payload);
  } finally {
    await host.stop();
  }
  assert.equal(host.isActive, false);
});

test("process host maps plugin errors", async () => {
  const host = new ProcessHost(config());
  await host.start();
  try {
    await assert.rejects(
      host.invoke("tool.provider", "denied"),
      (error) => error instanceof PluginCallError && error.callCode === "CAPABILITY_DENIED",
    );
    await assert.rejects(
      host.invoke("tool.provider", "missing"),
      (error) => error instanceof PluginCallError && error.callCode === "NOT_FOUND",
    );
  } finally {
    await host.stop();
  }
});

test("process host rejects invoke before start", async () => {
  const host = new ProcessHost(config());
  await assert.rejects(
    host.invoke("tool.provider", "echo"),
    (error) => error instanceof PluginCallError && error.callCode === "NOT_ACTIVE",
  );
});

test("process host times out and terminates", async () => {
  const host = new ProcessHost(config({ invokeTimeoutMs: 200 }));
  await host.start();
  try {
    await assert.rejects(
      host.invoke("tool.provider", "block"),
      (error) => error instanceof PluginCallError && error.callCode === "TIMEOUT",
    );
  } finally {
    await host.stop();
  }
});
