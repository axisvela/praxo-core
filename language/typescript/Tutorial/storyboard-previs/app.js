const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const SCENE = "scene-100";

class PrevisModel {
  constructor(scene) {
    this.scene = scene;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("script-1", "read_script", { scene: this.scene });
    }
    if (tools.length === 1) {
      return call("shots-1", "draft_shot_plan", {
        scene: this.scene,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "shot_plan_drafted",
          script: JSON.parse(tools[0].content),
          plan: JSON.parse(tools[tools.length - 1].content),
          renders: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.scene !== SCENE) {
      return { allowed: false, reason: "only scene-100 is in scope" };
    }
    if (action.toolName === "read_script") return { allowed: true };
    if (action.toolName === "draft_shot_plan") {
      return {
        allowed: action.arguments?.action === "draft",
        reason: "only a review-only shot plan is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runPrevis(scene, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "read_script",
    description: "Read one fixed script scene; no rendering or engine call.",
    risk: "read",
    parameters: {
      type: "object", required: ["scene"],
      properties: { scene: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.scene !== SCENE) throw new Error("scene not found");
      if (simulateFailure) throw new Error("SCRIPT_UNAVAILABLE");
      return {
        scene: SCENE,
        pages: 2,
        beats: ["arrival", "conflict", "exit"],
        location: "studio-a",
        source: "script_fixture",
      };
    },
  });
  tools.register({
    name: "draft_shot_plan",
    description: "Draft a bounded shot plan; no render or Unreal integration.",
    risk: "write",
    parameters: {
      type: "object", required: ["scene", "action"],
      properties: { scene: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        plan_id: "shot-plan-100",
        scene: args.scene,
        action: args.action,
        shots: 3,
        virtual_production: false,
        status: "draft_only",
        review_required: true,
        renders: 0,
      };
    },
  });
  const agent = new Agent({
    model: new PrevisModel(scene),
    tools,
    maxSteps: 4,
    allowedTools: ["read_script", "draft_shot_plan"],
    policy: buildPolicy(),
    systemPrompt: "Turn a fixed scene into a review-only shot plan.",
  });
  const result = await agent.run(
    { id: "storyboard-previs" },
    "Read the fixed scene and draft a shot plan without rendering.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runPrevis(SCENE);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.script.pages, 2);
  assert.equal(report.script.beats.length, 3);
  assert.equal(report.plan.shots, 3);
  assert.equal(report.plan.status, "draft_only");
  assert.equal(report.renders, 0);

  await assert.rejects(
    () => runPrevis("scene-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runPrevis(SCENE, { simulateFailure: true }),
    (error) => /SCRIPT_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript MD-01 storyboard-previs tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--scene");
    const scene = index >= 0 ? process.argv[index + 1] : SCENE;
    runPrevis(scene, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runPrevis, PrevisModel };
