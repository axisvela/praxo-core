const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const ASSET = "asset-100";

class CopyrightModel {
  constructor(asset) {
    this.asset = asset;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("compare-1", "compare_assets", { asset: this.asset });
    }
    if (tools.length === 1) {
      return call("packet-1", "draft_packet", {
        asset: this.asset,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "evidence_packet_drafted",
          comparison: JSON.parse(tools[0].content),
          packet: JSON.parse(tools[tools.length - 1].content),
          notices_sent: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.asset !== ASSET) {
      return { allowed: false, reason: "only asset-100 is in scope" };
    }
    if (action.toolName === "compare_assets") return { allowed: true };
    if (action.toolName === "draft_packet") {
      return {
        allowed: action.arguments?.action === "draft",
        reason: "only a review-only evidence packet is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runCopyright(asset, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "compare_assets",
    description: "Compare fixed authorized assets; no crawl or adjudication.",
    risk: "read",
    parameters: {
      type: "object", required: ["asset"],
      properties: { asset: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.asset !== ASSET) throw new Error("asset not found");
      if (simulateFailure) throw new Error("ASSET_INDEX_UNAVAILABLE");
      return {
        asset: ASSET,
        authorized: true,
        compared: 3,
        matches: [
          { id: "match-100", similarity: 0.92 },
          { id: "match-101", similarity: 0.88 },
        ],
        source: "asset_fixture",
      };
    },
  });
  tools.register({
    name: "draft_packet",
    description: "Draft a review-only evidence packet; no DMCA notice.",
    risk: "write",
    parameters: {
      type: "object", required: ["asset", "action"],
      properties: { asset: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        packet_id: "packet-100",
        asset: args.asset,
        action: args.action,
        matches: 2,
        status: "draft_only",
        review_required: true,
        infringement_verdict: false,
        notices_sent: 0,
      };
    },
  });
  const agent = new Agent({
    model: new CopyrightModel(asset),
    tools,
    maxSteps: 4,
    allowedTools: ["compare_assets", "draft_packet"],
    policy: buildPolicy(),
    systemPrompt: "Compare fixed assets and draft a review-only evidence packet.",
  });
  const result = await agent.run(
    { id: "copyright-evidence" },
    "Compare the fixed assets and draft an evidence packet without notices.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runCopyright(ASSET);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.comparison.compared, 3);
  assert.equal(report.comparison.matches.length, 2);
  assert.equal(report.packet.status, "draft_only");
  assert.equal(report.packet.infringement_verdict, false);
  assert.equal(report.notices_sent, 0);

  await assert.rejects(
    () => runCopyright("asset-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runCopyright(ASSET, { simulateFailure: true }),
    (error) => /ASSET_INDEX_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript LJ-05 copyright-evidence tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--asset");
    const asset = index >= 0 ? process.argv[index + 1] : ASSET;
    runCopyright(asset, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runCopyright, CopyrightModel };
