const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const MEETING = "meeting-100";

class MeetingModel {
  constructor(meeting) {
    this.meeting = meeting;
  }

  async generate(request) {
    const tools = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, arguments_) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: arguments_ }] },
    });
    if (tools.length === 0) {
      return call("calendar-1", "read_calendar", { meeting: this.meeting });
    }
    if (tools.length === 1) {
      return call("minutes-1", "draft_minutes", {
        meeting: this.meeting,
        action: "draft",
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "minutes_drafted",
          calendar: JSON.parse(tools[0].content),
          minutes: JSON.parse(tools[tools.length - 1].content),
          invitations_sent: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.arguments?.meeting !== MEETING) {
      return { allowed: false, reason: "only meeting-100 is in scope" };
    }
    if (action.toolName === "read_calendar") return { allowed: true };
    if (action.toolName === "draft_minutes") {
      return {
        allowed: action.arguments?.action === "draft",
        reason: "only a review-only minutes draft is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runMeeting(meeting, { simulateFailure = false } = {}) {
  let reads = 0;
  let drafts = 0;
  const tools = new Registry();
  tools.register({
    name: "read_calendar",
    description: "Read fixed calendar evidence for one meeting; no invitations.",
    risk: "read",
    parameters: {
      type: "object", required: ["meeting"],
      properties: { meeting: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (args.meeting !== MEETING) throw new Error("meeting not found");
      if (simulateFailure) throw new Error("CALENDAR_UNAVAILABLE");
      return {
        meeting: MEETING,
        attendees: 3,
        slots: ["2026-11-25T09:00", "2026-11-25T14:00"],
        conflicts: 1,
        source: "calendar_fixture",
      };
    },
  });
  tools.register({
    name: "draft_minutes",
    description: "Draft review-only minutes and tasks; never sends invitations.",
    risk: "write",
    parameters: {
      type: "object", required: ["meeting", "action"],
      properties: { meeting: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      drafts += 1;
      return {
        minutes_id: "minutes-100",
        meeting: args.meeting,
        action: args.action,
        tasks: 2,
        status: "draft_only",
        review_required: true,
        invitations_sent: 0,
      };
    },
  });
  const agent = new Agent({
    model: new MeetingModel(meeting),
    tools,
    maxSteps: 4,
    allowedTools: ["read_calendar", "draft_minutes"],
    policy: buildPolicy(),
    systemPrompt: "Reconcile fixed calendar evidence and draft review-only minutes.",
  });
  const result = await agent.run(
    { id: "meeting-coordination" },
    "Read the fixed calendar and draft minutes without sending invitations.",
  );
  return { output: result.output, reads, drafts };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runMeeting(MEETING);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.drafts, 1);
  assert.equal(report.calendar.attendees, 3);
  assert.equal(report.calendar.conflicts, 1);
  assert.equal(report.minutes.status, "draft_only");
  assert.equal(report.invitations_sent, 0);

  await assert.rejects(
    () => runMeeting("meeting-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runMeeting(MEETING, { simulateFailure: true }),
    (error) => /CALENDAR_UNAVAILABLE/.test(error.message),
  );
  console.log("TypeScript OP-02 meeting-coordination tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--meeting");
    const meeting = index >= 0 ? process.argv[index + 1] : MEETING;
    runMeeting(meeting, { simulateFailure: process.argv.includes("--simulate-failure") })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runMeeting, MeetingModel };
