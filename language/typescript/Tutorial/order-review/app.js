const { Agent, Registry, FuncHook } = require("@axisvela/praxo-core");

async function review(baseUrl, token, order, allowedOrder = "order-100") {
  const origin = new URL(baseUrl);
  if (origin.protocol !== "http:" || origin.pathname !== "/") {
    throw new Error("Local teaching service requires an HTTP origin");
  }
  async function request(method, path, body) {
    const response = await fetch(new URL(path, origin), {
      method,
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json",
        "Idempotency-Key": "typescript-review-1" },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(5000),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(`business service ${response.status}: ${data.error}`);
    return data;
  }
  const tools = new Registry();
  tools.register({
    name: "review_order", description: "Read an order and create a draft, never a refund.", risk: "write",
    parameters: { type: "object", required: ["order_id"], properties: { order_id: { type: "string" } } },
    async invoke(args) {
      const record = await request("GET", `/v1/orders/${args.order_id}`);
      const draft = await request("POST", `/v1/orders/${record.id}/drafts`, {
        recommendation: record.status === "delayed" ? "Contact carrier" : "Monitor shipment",
      });
      return JSON.stringify({ order: record, draft });
    },
  });
  const model = {
    async generate(request) {
      const last = request.messages.at(-1);
      return { message: last.role === "tool"
        ? { role: "assistant", content: last.content }
        : { role: "assistant", toolCalls: [{ id: "review-1", name: "review_order", arguments: { order_id: order } }] } };
    },
  };
  const policy = new FuncHook((action) => ({
    allowed: action.kind === "model.generate" || (action.kind === "tool.invoke"
      && action.toolName === "review_order" && action.arguments?.order_id === allowedOrder),
    reason: "fixed order scope",
  }));
  const result = await new Agent({ model, tools, maxSteps: 3, allowedTools: ["review_order"], policy })
    .run({ id: "order-review" }, `Review ${order}; create a draft only.`);
  return result.output;
}

if (require.main === module) {
  review(process.env.DEMO_BASE_URL || "http://127.0.0.1:8765", process.env.DEMO_TOKEN || "demo-a-token",
    process.env.DEMO_ORDER || "order-100").then(console.log).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
module.exports = { review };
