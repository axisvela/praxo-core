const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const SHOW = "show-100";

class LiveShowModel {
  constructor(show) {
    this.show = show;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("events-1", "read_engagement", { show: this.show });
    }
    if (tools.length === 1) {
      return call("order-1", "draft_running_order", {
        show: this.show,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "running_order_drafted",
          engagement: JSON.parse(tools[0].content),
          order: JSON.parse(tools[tools.length - 1].content),
          stream_controls: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.show !== SHOW) {
      return { allowed: false, reason: "only show-100 is in scope" };
    }
    if (action.toolName === "read_engagement") return { allowed: true };
    if (action.toolName === "draft_running_order") {
      return {
        allowed: action.arguments?.action === "draft",
        reason: "only a review-only running order is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runShow(show, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "read_engagement",
    description: "Replay fixed engagement events; no audience profiling.",
    risk: "read",
    parameters: {
      type: "object", required: ["show"],
      properties: { show: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.show !== SHOW) throw new Error("show not found");
      if (simulateFailure) throw new Error("ENGAGEMENT_UNAVAILABLE");
      return {
        show: SHOW,
        events: 5,
        peak_minute: 12,
        segments: { returning: 3, new: 2 },
        profiled: false,
        source: "engagement_fixture",
      };
    },
  });
  tools.register({
    name: "draft_running_order",
    description: "Draft a review-only presentation order; no stream control.",
    risk: "write",
    parameters: {
      type: "object", required: ["show", "action"],
      properties: { show: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        order_id: "order-100",
        show: args.show,
        action: args.action,
        segments: 3,
        status: "draft_only",
        review_required: true,
        stream_controls: 0,
        coupons_sent: 0,
      };
    },
  });
  const agent = new Agent({
    model: new LiveShowModel(show),
    tools,
    maxSteps: 4,
    allowedTools: ["read_engagement", "draft_running_order"],
    policy: buildPolicy(),
    systemPrompt: "Replay fixed engagement and draft a review-only running order.",
  });
  const result = await agent.run(
    { id: "live-show" },
    "Replay fixed events and draft a running order without stream control.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runShow(SHOW);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.engagement.events, 5);
  assert.equal(report.engagement.profiled, false);
  assert.equal(report.order.status, "draft_only");
  assert.equal(report.order.coupons_sent, 0);
  assert.equal(report.stream_controls, 0);

  await assert.rejects(
    () => runShow("show-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runShow(SHOW, { simulateFailure: true }),
    (error) => /ENGAGEMENT_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript MD-07 live-show tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--show");
    const show = index >= 0 ? process.argv[index + 1] : SHOW;
    runShow(show, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runShow, LiveShowModel };
