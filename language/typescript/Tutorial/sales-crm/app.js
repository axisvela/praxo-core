const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const CALL_ID = "call-100";

class SalesModel {
  constructor(call) {
    this.call = call;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("transcript-1", "read_transcript", { call: this.call });
    }
    if (tools.length === 1) {
      return call("crm-1", "draft_crm_update", {
        call: this.call,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "crm_update_drafted",
          transcript: JSON.parse(tools[0].content),
          update: JSON.parse(tools[tools.length - 1].content),
          crm_writes: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.call !== CALL_ID) {
      return { allowed: false, reason: "only call-100 is in scope" };
    }
    if (action.toolName === "read_transcript") return { allowed: true };
    if (action.toolName === "draft_crm_update") {
      return {
        allowed: action.arguments?.action === "draft",
        reason: "only a review-only CRM update is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runSales(call, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "read_transcript",
    description: "Extract objections from one fixed sales-call transcript.",
    risk: "read",
    parameters: {
      type: "object", required: ["call"],
      properties: { call: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.call !== CALL_ID) throw new Error("call not found");
      if (simulateFailure) throw new Error("TRANSCRIPT_UNAVAILABLE");
      return {
        call: CALL_ID,
        turns: 6,
        objections: [
          { id: "objection-100", topic: "price" },
          { id: "objection-101", topic: "timeline" },
        ],
        sentiment: "neutral",
        source: "transcript_fixture",
      };
    },
  });
  tools.register({
    name: "draft_crm_update",
    description: "Draft a review-only CRM update; never writes to the CRM.",
    risk: "write",
    parameters: {
      type: "object", required: ["call", "action"],
      properties: { call: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        update_id: "crm-100",
        call: args.call,
        action: args.action,
        objections: 2,
        next_step: "review_pricing_response",
        status: "draft_only",
        review_required: true,
        crm_writes: 0,
      };
    },
  });
  const agent = new Agent({
    model: new SalesModel(call),
    tools,
    maxSteps: 4,
    allowedTools: ["read_transcript", "draft_crm_update"],
    policy: buildPolicy(),
    systemPrompt: "Extract fixed objections and draft a review-only CRM update.",
  });
  const result = await agent.run(
    { id: "sales-crm" },
    "Review the fixed transcript and draft a CRM update without writing.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runSales(CALL_ID);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.transcript.objections.length, 2);
  assert.equal(report.update.status, "draft_only");
  assert.equal(report.update.crm_writes, 0);
  assert.equal(report.crm_writes, 0);

  await assert.rejects(
    () => runSales("call-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runSales(CALL_ID, { simulateFailure: true }),
    (error) => /TRANSCRIPT_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript CS-03 sales-crm tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--call");
    const call = index >= 0 ? process.argv[index + 1] : CALL_ID;
    runSales(call, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runSales, SalesModel };
