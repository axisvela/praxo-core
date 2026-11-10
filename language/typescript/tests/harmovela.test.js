const assert = require("node:assert/strict");
const test = require("node:test");

const { HarmovelaSink } = require("../dist");

function event(overrides = {}) {
  return {
    type: "tool.call",
    sessionId: "s1",
    runId: "run-123",
    data: { name: "echo" },
    at: "2026-11-10T07:00:00.000Z",
    ...overrides,
  };
}

function capture(status = 201, body = "") {
  const calls = [];
  const transport = (request) => {
    calls.push(request);
    return { status, body };
  };
  return { calls, transport };
}

test("Harmovela sink posts the documented envelope", async () => {
  const { calls, transport } = capture();
  const sink = new HarmovelaSink({
    baseUrl: "http://harmovela.test/aep/api/",
    transport,
  });
  await sink.emit(event());
  assert.equal(calls.length, 1);
  assert.equal(calls[0].method, "POST");
  assert.equal(calls[0].url, "http://harmovela.test/aep/api/events");
  assert.equal(calls[0].headers["content-type"], "application/json");
  const envelope = JSON.parse(calls[0].body);
  assert.equal(envelope.spec_version, "0.2");
  assert.equal(envelope.id, "run-123-1794294000000000000");
  assert.equal(envelope.type, "tool.call");
  assert.equal(envelope.source, "praxo-core");
  assert.equal(envelope.created_at, "2026-11-10T07:00:00.000000000Z");
  assert.deepEqual(envelope.payload, {
    name: "echo",
    session_id: "s1",
    run_id: "run-123",
  });
});

test("Harmovela sink merges payload and honors overrides", async () => {
  const { calls, transport } = capture();
  const sink = new HarmovelaSink({
    baseUrl: "http://harmovela.test",
    source: "custom",
    specVersion: "0.3",
    transport,
  });
  await sink.emit(
    event({
      runId: undefined,
      data: { name: "echo", session_id: "event-side", run_id: "old" },
    })
  );
  const envelope = JSON.parse(calls[0].body);
  assert.equal(envelope.source, "custom");
  assert.equal(envelope.spec_version, "0.3");
  assert.ok(envelope.id.startsWith("s1-"));
  assert.deepEqual(envelope.payload, {
    name: "echo",
    session_id: "s1",
    run_id: "old",
  });
});

test("Harmovela sink accepts 2xx statuses", async () => {
  for (const status of [200, 201, 204, 299]) {
    const { transport } = capture(status);
    await new HarmovelaSink({
      baseUrl: "http://harmovela.test",
      transport,
    }).emit(event());
  }
});

test("Harmovela sink reports status and bounded body on non-2xx", async () => {
  const { transport } = capture(503, "service down ".repeat(100));
  const sink = new HarmovelaSink({
    baseUrl: "http://harmovela.test",
    transport,
  });
  await assert.rejects(sink.emit(event()), (error) => {
    assert.match(error.message, /503/);
    assert.match(error.message, /service down/);
    assert.ok(error.message.length <= 600);
    return true;
  });
});
