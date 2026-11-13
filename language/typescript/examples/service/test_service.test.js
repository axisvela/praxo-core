const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");

const { FakeModel, createAgent, createHandler } = require("./service");

async function withServer(run) {
  const server = http.createServer(
    createHandler(createAgent(new FakeModel()), "local")
  );
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await run(base);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test("requires a principal", async () => {
  await withServer(async (base) => {
    const response = await fetch(`${base}/run`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt: "hi" }),
    });
    assert.equal(response.status, 401);
  });
});

test("returns output for an authenticated caller", async () => {
  await withServer(async (base) => {
    const response = await fetch(`${base}/run`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Praxo-Principal": "user-1",
      },
      body: JSON.stringify({ prompt: "hi" }),
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      output: "hello from the service",
    });
  });
});

test("health check does not require a principal", async () => {
  await withServer(async (base) => {
    const response = await fetch(`${base}/healthz`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: "ok" });
  });
});
