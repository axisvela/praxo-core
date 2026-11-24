const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const CUSTOMER = "customer-100";
const ORDER = "order-100";

class OrchestrationModel {
  constructor(customer, mismatch) {
    this.customer = customer;
    this.mismatch = mismatch;
  }

  async generate(request) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (toolMessages.length === 0) {
      return call("customer-1", "read_customer", { customer: this.customer });
    }
    if (toolMessages.length === 1) {
      return call("order-1", "read_order", { order: ORDER });
    }
    const order = JSON.parse(toolMessages[1].content);
    if (order.schema_ok === false) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          content: JSON.stringify({
            stage: "schema_mismatch",
            reason: "order.amount must be numeric",
            order,
            reconciled: false,
            writes: 0,
          }),
        },
      };
    }
    if (toolMessages.length === 2) {
      return call("mapping-1", "draft_integration", {
        mapping_id: "map-100",
        customer: this.customer,
        order: ORDER,
      });
    }
    const customer = JSON.parse(toolMessages[0].content);
    const mapping = JSON.parse(toolMessages[2].content);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "integration_drafted",
          customer,
          order,
          integration: mapping,
          reconciled: true,
          writes: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.toolName === "read_customer") {
      return {
        allowed: action.arguments?.customer === CUSTOMER,
        reason: "only customer-100 is in scope",
      };
    }
    if (action.toolName === "read_order") {
      return {
        allowed: action.arguments?.order === ORDER,
        reason: "only order-100 is in scope",
      };
    }
    if (action.toolName === "draft_integration") {
      return {
        allowed: action.arguments?.mapping_id === "map-100" &&
          action.arguments?.customer === CUSTOMER,
        reason: "only a map-100 review draft is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runOrchestration(customer, { mismatch = false, simulateFailure = false } = {}) {
  let customerReads = 0;
  let orderReads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "read_customer",
    description: "Read a fixed customer API fixture; no network.",
    risk: "read",
    parameters: {
      type: "object", required: ["customer"],
      properties: { customer: { type: "string" } },
    },
    async invoke(args) {
      customerReads += 1;
      if (simulateFailure) throw new Error("CUSTOMER_API_UNAVAILABLE");
      if (args.customer !== CUSTOMER) throw new Error("customer not found");
      return { customer_id: CUSTOMER, name: "Acme", tier: "gold", schema_ok: true };
    },
  });
  tools.register({
    name: "read_order",
    description: "Read a fixed order API fixture and validate its schema.",
    risk: "read",
    parameters: {
      type: "object", required: ["order"],
      properties: { order: { type: "string" } },
    },
    async invoke(args) {
      orderReads += 1;
      if (args.order !== ORDER) throw new Error("order not found");
      return {
        order_id: ORDER,
        customer_id: CUSTOMER,
        amount: mismatch ? "120.00" : 120,
        currency: "USD",
        schema_ok: !mismatch,
      };
    },
  });
  tools.register({
    name: "draft_integration",
    description: "Draft a review-only integration mapping; no partner write.",
    risk: "write",
    parameters: {
      type: "object", required: ["mapping_id", "customer"],
      properties: { mapping_id: { type: "string" }, customer: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        mapping_id: args.mapping_id,
        customer: args.customer,
        order: ORDER,
        status: "draft_only",
        review_required: true,
        writes: 0,
      };
    },
  });
  const agent = new Agent({
    model: new OrchestrationModel(customer, mismatch),
    tools,
    maxSteps: 5,
    allowedTools: ["read_customer", "read_order", "draft_integration"],
    policy: buildPolicy(),
    systemPrompt: "Map two fixed APIs and draft a review-only integration.",
  });
  const result = await agent.run(
    { id: "api-orchestration" },
    "Read the fixed customer and order, validate schemas and draft a mapping.",
  );
  return { output: result.output, customerReads, orderReads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runOrchestration(CUSTOMER);
  const report = JSON.parse(success.output);
  assert.equal(success.customerReads, 1);
  assert.equal(success.orderReads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.reconciled, true);
  assert.equal(report.integration.status, "draft_only");
  assert.equal(report.writes, 0);

  const mismatch = await runOrchestration(CUSTOMER, { mismatch: true });
  const mismatchReport = JSON.parse(mismatch.output);
  assert.equal(mismatch.customerReads, 1);
  assert.equal(mismatch.orderReads, 1);
  assert.equal(mismatch.drafts, 0);
  assert.equal(mismatchReport.stage, "schema_mismatch");
  assert.equal(mismatchReport.reconciled, false);
  assert.equal(mismatchReport.writes, 0);

  await assert.rejects(
    () => runOrchestration("customer-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runOrchestration(CUSTOMER, { simulateFailure: true }),
    (error) => /CUSTOMER_API_UNAVAILABLE/.test(error.message),
  );

  console.log("TypeScript api-orchestration tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--customer");
    const customer = index >= 0 ? process.argv[index + 1] : CUSTOMER;
    runOrchestration(customer, {
      mismatch: process.argv.includes("--mismatch"),
      simulateFailure: process.argv.includes("--simulate-failure"),
    })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runOrchestration, OrchestrationModel };
