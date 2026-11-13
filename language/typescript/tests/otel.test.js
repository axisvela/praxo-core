const assert = require("node:assert/strict");
const test = require("node:test");

const { OtelSink } = require("../dist");

function event(overrides = {}) {
  return {
    type: "tool.call",
    sessionId: "s1",
    runId: "run-123",
    data: { name: "echo", secret: "hidden" },
    at: "2026-11-10T07:00:00.000Z",
    ...overrides,
  };
}

function capture(status = 200, body = "") {
  const calls = [];
  const transport = (request) => {
    calls.push(request);
    return { status, body };
  };
  return { calls, transport };
}

function spanOf(call) {
  return JSON.parse(call.body).resourceSpans[0].scopeSpans[0].spans[0];
}

test("OTel sink posts an OTLP span with allowed attributes", async () => {
  const { calls, transport } = capture();
  const sink = new OtelSink({
    endpoint: "http://otel.test/v1/traces",
    serviceName: "praxo-test",
    transport,
    allowedDataKeys: ["name"],
  });
  await sink.emit(event());
  assert.equal(calls.length, 1);
  assert.equal(calls[0].method, "POST");
  assert.equal(calls[0].url, "http://otel.test/v1/traces");
  assert.equal(calls[0].headers["content-type"], "application/json");
  const payload = JSON.parse(calls[0].body);
  assert.equal(
    payload.resourceSpans[0].resource.attributes[0].value.stringValue,
    "praxo-test"
  );
  const span = spanOf(calls[0]);
  assert.equal(span.name, "praxo.tool.call");
  assert.equal(span.traceId.length, 32);
  assert.equal(span.spanId.length, 16);
  assert.equal(span.startTimeUnixNano, span.endTimeUnixNano);
  const attributes = Object.fromEntries(
    span.attributes.map((item) => [item.key, item.value.stringValue])
  );
  assert.equal(attributes["praxo.event.type"], "tool.call");
  assert.equal(attributes["praxo.session.id"], "s1");
  assert.equal(attributes["praxo.run.id"], "run-123");
  assert.equal(attributes["praxo.event.data.name"], "echo");
  assert.equal(attributes["praxo.event.data.secret"], undefined);
});

test("OTel sink identifiers are deterministic", async () => {
  const { calls, transport } = capture();
  const sink = new OtelSink({ transport });
  await sink.emit(event());
  await sink.emit(event());
  assert.equal(spanOf(calls[0]).traceId, spanOf(calls[1]).traceId);
  assert.equal(spanOf(calls[0]).spanId, spanOf(calls[1]).spanId);
});

test("OTel sink rejects non-2xx responses", async () => {
  const sink = new OtelSink({ transport: capture(503, "down").transport });
  await assert.rejects(() => sink.emit(event()));
});
