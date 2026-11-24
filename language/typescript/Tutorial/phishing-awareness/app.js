const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const EMAIL = "email-100";
const ORGANIZATION = "org-100";

class PhishingModel {
  constructor(email) {
    this.email = email;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("email-1", "classify_email", { email: this.email });
    }
    if (tools.length === 1) {
      return call("exercise-1", "draft_exercise", {
        organization: ORGANIZATION,
        email: this.email,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "exercise_drafted",
          classification: JSON.parse(tools[0].content),
          exercise: JSON.parse(tools[tools.length - 1].content),
          emails_sent: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.toolName === "classify_email") {
      return {
        allowed: action.arguments?.email === EMAIL,
        reason: "only email-100 is in scope",
      };
    }
    if (action.toolName === "draft_exercise") {
      return {
        allowed: action.arguments?.organization === ORGANIZATION &&
          action.arguments?.email === EMAIL &&
          action.arguments?.action === "draft",
        reason: "only a review-only org-100 exercise is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runAwareness(email, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "classify_email",
    description: "Classify one fixed synthetic email; no links or sends.",
    risk: "read",
    parameters: {
      type: "object", required: ["email"],
      properties: { email: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.email !== EMAIL) throw new Error("email not found");
      if (simulateFailure) throw new Error("EMAIL_FIXTURE_UNAVAILABLE");
      return {
        email: EMAIL,
        risk: "phishing",
        signals: ["lookalike_domain", "urgency_language"],
        links_followed: 0,
        source: "email_fixture",
      };
    },
  });
  tools.register({
    name: "draft_exercise",
    description: "Draft an authorized review-only awareness exercise; never sends.",
    risk: "write",
    parameters: {
      type: "object", required: ["organization", "email", "action"],
      properties: {
        organization: { type: "string" },
        email: { type: "string" },
        action: { type: "string" },
      },
    },
    async invoke(args) {
      drafts += 1;
      return {
        exercise_id: "exercise-100",
        organization: args.organization,
        email: args.email,
        action: args.action,
        signals: 2,
        status: "draft_only",
        review_required: true,
        emails_sent: 0,
      };
    },
  });
  const agent = new Agent({
    model: new PhishingModel(email),
    tools,
    maxSteps: 4,
    allowedTools: ["classify_email", "draft_exercise"],
    policy: buildPolicy(),
    systemPrompt: "Classify a fixed email and draft an authorized awareness exercise.",
  });
  const result = await agent.run(
    { id: "phishing-awareness" },
    "Classify the fixed email and draft a review-only exercise.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runAwareness(EMAIL);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.classification.risk, "phishing");
  assert.equal(report.classification.signals.length, 2);
  assert.equal(report.classification.links_followed, 0);
  assert.equal(report.exercise.status, "draft_only");
  assert.equal(report.emails_sent, 0);

  await assert.rejects(
    () => runAwareness("email-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runAwareness(EMAIL, { simulateFailure: true }),
    (error) => /EMAIL_FIXTURE_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript CY-04 phishing-awareness tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--email");
    const email = index >= 0 ? process.argv[index + 1] : EMAIL;
    runAwareness(email, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runAwareness, PhishingModel };
