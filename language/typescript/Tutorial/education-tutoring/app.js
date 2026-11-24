const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const LEARNER = "learner-100";

class TutorModel {
  constructor(learner) {
    this.learner = learner;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("learner-1", "read_learner", { learner: this.learner });
    }
    if (tools.length === 1) {
      return call("question-1", "draft_question", {
        learner: this.learner,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "question_drafted",
          learner: JSON.parse(tools[0].content),
          question: JSON.parse(tools[tools.length - 1].content),
          grades_issued: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.learner !== LEARNER) {
      return { allowed: false, reason: "only learner-100 is in scope" };
    }
    if (action.toolName === "read_learner") return { allowed: true };
    if (action.toolName === "draft_question") {
      return {
        allowed: action.arguments?.action === "draft",
        reason: "only a review-only question draft is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runTutor(learner, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "read_learner",
    description: "Read fixed learner attempts; no personal data or grading.",
    risk: "read",
    parameters: {
      type: "object", required: ["learner"],
      properties: { learner: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.learner !== LEARNER) throw new Error("learner not found");
      if (simulateFailure) throw new Error("LEARNER_DATA_UNAVAILABLE");
      return {
        learner: LEARNER,
        attempts: 3,
        correct: 2,
        misconception: "unit_conversion",
        source: "learner_fixture",
      };
    },
  });
  tools.register({
    name: "draft_question",
    description: "Draft one graded Socratic question for human review.",
    risk: "write",
    parameters: {
      type: "object", required: ["learner", "action"],
      properties: { learner: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        question_id: "question-100",
        learner: args.learner,
        action: args.action,
        difficulty: "medium",
        focus: "unit_conversion",
        status: "draft_only",
        review_required: true,
        grades_issued: 0,
      };
    },
  });
  const agent = new Agent({
    model: new TutorModel(learner),
    tools,
    maxSteps: 4,
    allowedTools: ["read_learner", "draft_question"],
    policy: buildPolicy(),
    systemPrompt: "Use fixed attempts to draft one review-only Socratic question.",
  });
  const result = await agent.run(
    { id: "education-tutoring" },
    "Read fixed attempts and draft a question without grading.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runTutor(LEARNER);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.learner.attempts, 3);
  assert.equal(report.learner.correct, 2);
  assert.equal(report.learner.misconception, "unit_conversion");
  assert.equal(report.question.status, "draft_only");
  assert.equal(report.grades_issued, 0);

  await assert.rejects(
    () => runTutor("learner-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runTutor(LEARNER, { simulateFailure: true }),
    (error) => /LEARNER_DATA_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript PE-01 education-tutoring tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--learner");
    const learner = index >= 0 ? process.argv[index + 1] : LEARNER;
    runTutor(learner, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runTutor, TutorModel };
