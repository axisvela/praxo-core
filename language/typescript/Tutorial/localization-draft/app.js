const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const PRODUCT = "product-100";

class LocalizationModel {
  constructor(productId) {
    this.productId = productId;
  }

  async generate(request) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    if (toolMessages.length === 0) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "terms-1", name: "read_terms",
            arguments: { product_id: this.productId },
          }],
        },
      };
    }
    if (toolMessages.length === 1) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "draft-1", name: "draft_localization",
            arguments: { product_id: this.productId, action: "draft_localized" },
          }],
        },
      };
    }
    const terms = JSON.parse(toolMessages[0].content);
    const draft = JSON.parse(toolMessages[1].content);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "localization_drafted",
          terms,
          draft,
          legal_guarantees: 0,
          tax_claims: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.toolName === "read_terms") {
      return {
        allowed: action.arguments?.product_id === PRODUCT,
        reason: "only product-100 is in scope",
      };
    }
    if (action.toolName === "draft_localization") {
      return {
        allowed: action.arguments?.product_id === PRODUCT &&
          action.arguments?.action === "draft_localized",
        reason: "only a product-100 draft_localized is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runLocalization(productId, { simulateFailure = false } = {}) {
  let termsCalls = 0;
  let draftCalls = 0;
  const tools = new Registry();
  tools.register({
    name: "read_terms",
    description: "Read fixed localization rules for one product; no legal advice.",
    risk: "read",
    parameters: {
      type: "object", required: ["product_id"],
      properties: { product_id: { type: "string" } },
    },
    async invoke(args) {
      termsCalls += 1;
      if (simulateFailure) throw new Error("TERMS_INDEX_UNAVAILABLE");
      if (args.product_id !== PRODUCT) throw new Error("product not found");
      return {
        product_id: PRODUCT,
        markets: ["de"],
        rules: ["formal-address", "unit-cm"],
        source: "terms_fixture",
      };
    },
  });
  tools.register({
    name: "draft_localization",
    description: "Draft review-only localized text; no legal or tax guarantee.",
    risk: "write",
    parameters: {
      type: "object", required: ["product_id", "action"],
      properties: { product_id: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      draftCalls += 1;
      if (args.product_id !== PRODUCT) throw new Error("product not found");
      if (args.action !== "draft_localized") throw new Error("invalid localization action");
      return {
        draft_id: "localization-100",
        product_id: PRODUCT,
        action: "draft_localized",
        segments: 2,
        status: "draft_only",
        review_required: true,
        legal_guarantees: 0,
        tax_claims: 0,
      };
    },
  });
  const agent = new Agent({
    model: new LocalizationModel(productId),
    tools,
    maxSteps: 4,
    allowedTools: ["read_terms", "draft_localization"],
    policy: buildPolicy(),
    systemPrompt: "Compare fixed localization rules and draft review-only text.",
  });
  const result = await agent.run(
    { id: "localization-draft" },
    "Compare the fixed rules and draft review-only localized text.",
  );
  return { output: result.output, termsCalls, draftCalls };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runLocalization(PRODUCT);
  const report = JSON.parse(success.output);
  assert.equal(success.termsCalls, 1);
  assert.equal(success.draftCalls, 1);
  assert.deepEqual(report.terms.markets, ["de"]);
  assert.deepEqual(report.terms.rules, ["formal-address", "unit-cm"]);
  assert.equal(report.draft.status, "draft_only");
  assert.equal(report.draft.segments, 2);
  assert.equal(report.legal_guarantees, 0);
  assert.equal(report.tax_claims, 0);

  await assert.rejects(
    () => runLocalization("product-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runLocalization(PRODUCT, { simulateFailure: true }),
    (error) => /TERMS_INDEX_UNAVAILABLE/.test(error.message),
  );

  console.log("TypeScript localization-draft tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--product");
    const product = index >= 0 ? process.argv[index + 1] : PRODUCT;
    const simulateFailure = process.argv.includes("--simulate-failure");
    runLocalization(product, { simulateFailure })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runLocalization, LocalizationModel };
