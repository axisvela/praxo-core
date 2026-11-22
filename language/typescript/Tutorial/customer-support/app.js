const http = require("node:http");
const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const AUTH = "Bearer demo-a-token";
const ORDER = { id: "order-100", status: "delayed", shipment: "awaiting_carrier" };
const POLICY = {
  id: "shipping",
  snippet: "Delayed orders may be eligible for a carrier trace after 48 hours.",
};

class SupportModel {
  constructor(orderId) {
    this.orderId = orderId;
  }

  async generate(request) {
    return this.generateStream(request, () => {});
  }

  async generateStream(request, onDelta) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    if (toolMessages.length === 0) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "order-1", name: "lookup_order",
            arguments: { order_id: this.orderId },
          }],
        },
      };
    }
    if (toolMessages.length === 1) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "policy-1", name: "search_policy",
            arguments: { query: "delayed shipping", scope: "public" },
          }],
        },
      };
    }
    const order = JSON.parse(toolMessages[0].content);
    const policy = JSON.parse(toolMessages[1].content);
    const top = policy.matches[0];
    const output = JSON.stringify({
      answer: `Your order ${order.id} is ${order.status}; ${top.snippet}`,
      citations: [top.id],
    });
    for (const chunk of output.match(/.{1,48}/gs) || [output]) onDelta(chunk);
    return { message: { role: ROLE_ASSISTANT, content: output } };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.toolName === "lookup_order") {
      return {
        allowed: action.arguments?.order_id === "order-100",
        reason: "only order-100 is in the support scope",
      };
    }
    if (action.toolName === "search_policy") {
      return {
        allowed: action.arguments?.scope === "public",
        reason: "only public policy fixtures are readable",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runSupport(orderId, { simulateFailure = false, onDelta = () => {} } = {}) {
  let orderCalls = 0;
  let policyCalls = 0;
  const tools = new Registry();
  tools.register({
    name: "lookup_order",
    description: "Read the fixed support order fixture; no writes.",
    risk: "read",
    parameters: {
      type: "object", required: ["order_id"],
      properties: { order_id: { type: "string" } },
    },
    async invoke(args) {
      orderCalls += 1;
      if (simulateFailure) throw new Error("simulated support dependency unavailable");
      if (args.order_id !== ORDER.id) throw new Error("order not found");
      return ORDER;
    },
  });
  tools.register({
    name: "search_policy",
    description: "Read the fixed public shipping policy; no arbitrary files.",
    risk: "read",
    parameters: {
      type: "object", required: ["query", "scope"],
      properties: { query: { type: "string" }, scope: { type: "string" } },
    },
    async invoke(args) {
      policyCalls += 1;
      if (args.scope !== "public") throw new Error("policy scope denied");
      return { scope: "public", matches: [POLICY] };
    },
  });
  const agent = new Agent({
    model: new SupportModel(orderId),
    tools,
    maxSteps: 4,
    allowedTools: ["lookup_order", "search_policy"],
    policy: buildPolicy(),
    onDelta,
    systemPrompt: "Answer the customer with scoped evidence and citations.",
  });
  const result = await agent.run({ id: "customer-support" }, "Handle the customer ticket.");
  return { output: result.output, orderCalls, policyCalls };
}

function createApp({ simulateFailure = false } = {}) {
  return http.createServer(async (req, res) => {
    if (req.method === "GET" && req.url === "/healthz") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end('{"status":"ok"}');
      return;
    }
    if (req.method !== "POST" || req.url !== "/support/order-100") {
      res.writeHead(404, { "Content-Type": "application/json" });
      res.end('{"error":"not_found"}');
      return;
    }
    if (req.headers.authorization !== AUTH) {
      res.writeHead(401, { "Content-Type": "application/json" });
      res.end('{"error":"unauthenticated"}');
      return;
    }
    let started = false;
    const start = () => {
      if (started) return;
      started = true;
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      });
    };
    try {
      const result = await runSupport("order-100", {
        simulateFailure,
        onDelta: (delta) => {
          start();
          res.write(`data: ${JSON.stringify({ delta })}\n\n`);
        },
      });
      start();
      const report = JSON.parse(result.output);
      res.write(`data: ${JSON.stringify({ citations: report.citations, done: true })}\n\n`);
      res.end();
    } catch (error) {
      if (!started) {
        res.writeHead(503, { "Content-Type": "application/json" });
        res.end('{"error":"support_failed"}');
      } else {
        res.write(`data: ${JSON.stringify({ error: "support_failed" })}\n\n`);
        res.end();
      }
    }
  });
}

async function test() {
  const assert = require("node:assert/strict");
  const server = createApp();
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;
  const url = `http://127.0.0.1:${port}/support/order-100`;
  try {
    const allowed = await fetch(url, {
      method: "POST", headers: { Authorization: AUTH },
    });
    assert.equal(allowed.status, 200);
    const body = await allowed.text();
    assert.match(body, /"citations":\["shipping"\]/);
    assert.match(body, /Your order order-100 is delayed/);
    assert.match(body, /"done":true/);

    const denied = await fetch(url, { method: "POST" });
    assert.equal(denied.status, 401);

    const failedServer = createApp({ simulateFailure: true });
    await new Promise((resolve) => failedServer.listen(0, "127.0.0.1", resolve));
    try {
      const failed = await fetch(
        `http://127.0.0.1:${failedServer.address().port}/support/order-100`,
        { method: "POST", headers: { Authorization: AUTH } },
      );
      assert.equal(failed.status, 503);
    } finally {
      await new Promise((resolve) => failedServer.close(resolve));
    }

    await assert.rejects(
      () => runSupport("order-200"),
      (error) => error instanceof PolicyDeniedError,
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
  console.log("TypeScript customer-support tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const port = Number(process.env.PORT || 8088);
    createApp().listen(port, "127.0.0.1", () => {
      console.log(`Support stream: http://127.0.0.1:${port}/support/order-100`);
    });
  }
}

module.exports = { createApp, runSupport, SupportModel };
