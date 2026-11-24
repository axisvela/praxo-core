const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const SESSION = "session-100";

class NegotiationModel {
  constructor(sessionId) {
    this.sessionId = sessionId;
  }

  async generate(request) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    if (toolMessages.length === 0) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "transcript-1", name: "read_transcript",
            arguments: { session_id: this.sessionId },
          }],
        },
      };
    }
    if (toolMessages.length === 1) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "notes-1", name: "draft_notes",
            arguments: { session_id: this.sessionId, action: "draft_summary" },
          }],
        },
      };
    }
    const transcript = JSON.parse(toolMessages[0].content);
    const notes = JSON.parse(toolMessages[1].content);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "negotiation_notes_drafted",
          transcript,
          notes,
          mind_reading_claims: 0,
          live_guarantee: false,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.toolName === "read_transcript") {
      return {
        allowed: action.arguments?.session_id === SESSION,
        reason: "only session-100 is in scope",
      };
    }
    if (action.toolName === "draft_notes") {
      return {
        allowed: action.arguments?.session_id === SESSION &&
          action.arguments?.action === "draft_summary",
        reason: "only a session-100 draft_summary is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runNegotiation(sessionId, { simulateFailure = false } = {}) {
  let transcriptCalls = 0;
  let notesCalls = 0;
  const tools = new Registry();
  tools.register({
    name: "read_transcript",
    description: "Read a fixed bilingual transcript excerpt; no live audio.",
    risk: "read",
    parameters: {
      type: "object", required: ["session_id"],
      properties: { session_id: { type: "string" } },
    },
    async invoke(args) {
      transcriptCalls += 1;
      if (simulateFailure) throw new Error("TRANSCRIPT_UNAVAILABLE");
      if (args.session_id !== SESSION) throw new Error("session not found");
      return {
        session_id: SESSION,
        segments: 3,
        terminology: [{ term: "keigo", note: "honorific register" }],
        ambiguity: "high",
        cues: 0,
        source: "transcript_fixture",
      };
    },
  });
  tools.register({
    name: "draft_notes",
    description: "Draft review-only negotiation notes; never claims to read minds.",
    risk: "write",
    parameters: {
      type: "object", required: ["session_id", "action"],
      properties: { session_id: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      notesCalls += 1;
      if (args.session_id !== SESSION) throw new Error("session not found");
      if (args.action !== "draft_summary") throw new Error("invalid notes action");
      return {
        notes_id: "notes-100",
        session_id: SESSION,
        action: "draft_summary",
        notes: ["Confirm the honorific register before replying", "Flag the ambiguous commitment"],
        status: "draft_only",
        review_required: true,
        mind_reading_claims: 0,
        live_guarantee: false,
      };
    },
  });
  const agent = new Agent({
    model: new NegotiationModel(sessionId),
    tools,
    maxSteps: 4,
    allowedTools: ["read_transcript", "draft_notes"],
    policy: buildPolicy(),
    systemPrompt: "Compare fixed transcripts and draft review-only notes.",
  });
  const result = await agent.run(
    { id: "negotiation-interpretation" },
    "Compare the fixed transcript and draft review-only notes.",
  );
  return { output: result.output, transcriptCalls, notesCalls };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runNegotiation(SESSION);
  const report = JSON.parse(success.output);
  assert.equal(success.transcriptCalls, 1);
  assert.equal(success.notesCalls, 1);
  assert.equal(report.transcript.segments, 3);
  assert.equal(report.transcript.ambiguity, "high");
  assert.equal(report.transcript.cues, 0);
  assert.equal(report.notes.status, "draft_only");
  assert.equal(report.mind_reading_claims, 0);
  assert.equal(report.live_guarantee, false);

  await assert.rejects(
    () => runNegotiation("session-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runNegotiation(SESSION, { simulateFailure: true }),
    (error) => /TRANSCRIPT_UNAVAILABLE/.test(error.message),
  );

  console.log("TypeScript negotiation-interpretation tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--session");
    const session = index >= 0 ? process.argv[index + 1] : SESSION;
    const simulateFailure = process.argv.includes("--simulate-failure");
    runNegotiation(session, { simulateFailure })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runNegotiation, NegotiationModel };
