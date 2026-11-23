const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const SKU_ID = "sku-100";
const SKU = {
  id: SKU_ID,
  stock: 4,
  reorder_point: 10,
  daily_sales: 3,
  own_price: 21,
  competitor_price: 19.5,
};

class ReplenishmentModel {
  constructor(sku) {
    this.sku = sku;
  }

  async generate(request) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    if (toolMessages.length === 0) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "inventory-1", name: "check_inventory",
            arguments: { sku: this.sku },
          }],
        },
      };
    }
    const inventory = JSON.parse(toolMessages[0].content);
    if (toolMessages.length === 1) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "po-1", name: "draft_purchase_order",
            arguments: {
              sku: this.sku,
              action: "replenish",
              quantity: inventory.suggested_quantity,
            },
          }],
        },
      };
    }
    const order = JSON.parse(toolMessages[1].content);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "replenishment_drafted",
          inventory,
          order,
          orders_sent: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.sku !== SKU_ID) {
      return { allowed: false, reason: "only sku-100 is in replenishment scope" };
    }
    if (action.toolName === "check_inventory") return { allowed: true };
    if (action.toolName === "draft_purchase_order") {
      return {
        allowed: action.arguments?.action === "replenish",
        reason: "only a replenish draft is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runReplenishment(sku, { simulateFailure = false } = {}) {
  let inventoryCalls = 0;
  let orderCalls = 0;
  const tools = new Registry();
  tools.register({
    name: "check_inventory",
    description: "Read fixed stock and pricing fixtures; no writes.",
    risk: "read",
    parameters: {
      type: "object", required: ["sku"],
      properties: { sku: { type: "string" } },
    },
    async invoke(args) {
      inventoryCalls += 1;
      if (simulateFailure) throw new Error("simulated inventory unavailable");
      if (args.sku !== SKU.id) throw new Error("sku not found");
      return {
        sku: SKU.id,
        stock: SKU.stock,
        reorder_point: SKU.reorder_point,
        needs_replenishment: SKU.stock < SKU.reorder_point,
        suggested_quantity: SKU.reorder_point + SKU.daily_sales * 7 - SKU.stock,
        competitor_gap: SKU.own_price - SKU.competitor_price,
        source: "inventory_fixture",
      };
    },
  });
  tools.register({
    name: "draft_purchase_order",
    description: "Draft a review-only purchase order; never submits it.",
    risk: "write",
    parameters: {
      type: "object", required: ["sku", "action", "quantity"],
      properties: {
        sku: { type: "string" },
        action: { type: "string" },
        quantity: { type: "number" },
      },
    },
    async invoke(args) {
      orderCalls += 1;
      if (args.sku !== SKU.id) throw new Error("sku not found");
      if (args.action !== "replenish") throw new Error("invalid replenishment action");
      return {
        po_id: "po-100",
        sku: args.sku,
        action: args.action,
        quantity: args.quantity,
        status: "draft_only",
        review_required: true,
        orders_sent: 0,
      };
    },
  });
  const agent = new Agent({
    model: new ReplenishmentModel(sku),
    tools,
    maxSteps: 4,
    allowedTools: ["check_inventory", "draft_purchase_order"],
    policy: buildPolicy(),
    requirePolicy: true,
    requireToolScope: true,
    systemPrompt: "Check fixed inventory and draft a review-only replenishment order.",
  });
  const result = await agent.run(
    { id: "retail-replenishment" },
    "Check the fixed SKU inventory and draft a purchase order.",
  );
  return { output: result.output, inventoryCalls, orderCalls };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runReplenishment(SKU_ID);
  const report = JSON.parse(success.output);
  assert.equal(success.inventoryCalls, 1);
  assert.equal(success.orderCalls, 1);
  assert.equal(report.inventory.needs_replenishment, true);
  assert.equal(report.inventory.suggested_quantity, 27);
  assert.equal(report.order.status, "draft_only");
  assert.equal(report.order.orders_sent, 0);
  assert.equal(report.orders_sent, 0);

  await assert.rejects(
    () => runReplenishment("sku-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runReplenishment(SKU_ID, { simulateFailure: true }),
    (error) => /simulated inventory/.test(error.message),
  );

  console.log("TypeScript retail-replenishment tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--sku");
    const sku = index >= 0 ? process.argv[index + 1] : SKU_ID;
    const simulateFailure = process.argv.includes("--simulate-failure");
    runReplenishment(sku, { simulateFailure })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runReplenishment, ReplenishmentModel };
