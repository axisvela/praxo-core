const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const WORKSPACE = "workspace-100";

class WorkspaceModel {
  constructor(workspaceId) {
    this.workspaceId = workspaceId;
  }

  async generate(request) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    const call = (id, name, args) => ({
      message: { role: ROLE_ASSISTANT, toolCalls: [{ id, name, arguments: args }] },
    });
    if (toolMessages.length === 0) {
      return call("read-1", "read_workspace", { workspace: this.workspaceId });
    }
    if (toolMessages.length === 1) {
      return call("edit-1", "apply_edit", {
        workspace: this.workspaceId,
        file: "app.js",
        action: "apply_edit_bounded",
      });
    }
    if (toolMessages.length === 2) {
      return call("inspect-1", "inspect_diagnostics", {
        workspace: this.workspaceId,
        action: "inspect",
      });
    }
    const workspace = JSON.parse(toolMessages[0].content);
    const edit = JSON.parse(toolMessages[1].content);
    const diagnostics = JSON.parse(toolMessages[2].content);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          workspace,
          edit,
          diagnostics,
          deployments: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    const inScope = action.arguments?.workspace === WORKSPACE;
    if (action.toolName === "read_workspace") {
      return { allowed: inScope, reason: "only workspace-100 is in scope" };
    }
    if (action.toolName === "apply_edit") {
      return {
        allowed: inScope &&
          action.arguments?.file === "app.js" &&
          action.arguments?.action === "apply_edit_bounded",
        reason: "only an allowlisted app.js bounded edit is allowed",
      };
    }
    if (action.toolName === "inspect_diagnostics") {
      return {
        allowed: inScope && action.arguments?.action === "inspect",
        reason: "only fixture diagnostics are allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runWorkspace(workspaceId, { simulateFailure = false } = {}) {
  let reads = 0;
  let edits = 0;
  let diagnostics = 0;
  const tools = new Registry();
  tools.register({
    name: "read_workspace",
    description: "Read a fixed allowlisted workspace; no host filesystem access.",
    risk: "read",
    parameters: {
      type: "object", required: ["workspace"],
      properties: { workspace: { type: "string" } },
    },
    async invoke(args) {
      reads += 1;
      if (simulateFailure) throw new Error("WORKSPACE_UNAVAILABLE");
      if (args.workspace !== WORKSPACE) throw new Error("workspace not found");
      return {
        workspace_id: WORKSPACE,
        empty: true,
        files: ["app.js", "app.test.js"],
        allowlist: ["app.js"],
        source: "workspace_fixture",
      };
    },
  });
  tools.register({
    name: "apply_edit",
    description: "Apply one bounded edit to an allowlisted fixture file; no deployment.",
    risk: "write",
    parameters: {
      type: "object", required: ["workspace", "file", "action"],
      properties: {
        workspace: { type: "string" },
        file: { type: "string" },
        action: { type: "string" },
      },
    },
    async invoke(args) {
      edits += 1;
      if (args.workspace !== WORKSPACE || args.file !== "app.js") throw new Error("edit out of scope");
      return {
        edit_id: "edit-100",
        workspace: WORKSPACE,
        file: args.file,
        action: args.action,
        changed: 1,
        status: "applied_fixture",
        deployments: 0,
      };
    },
  });
  tools.register({
    name: "inspect_diagnostics",
    description: "Inspect fixed synthetic diagnostics; no real compiler.",
    risk: "read",
    parameters: {
      type: "object", required: ["workspace", "action"],
      properties: { workspace: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      diagnostics += 1;
      if (args.workspace !== WORKSPACE) throw new Error("workspace not found");
      return {
        diagnostics_id: "diagnostics-100",
        workspace: WORKSPACE,
        action: args.action,
        diagnostics: 0,
        build_status: "ok_fixture",
        deployments: 0,
      };
    },
  });
  const agent = new Agent({
    model: new WorkspaceModel(workspaceId),
    tools,
    maxSteps: 6,
    allowedTools: ["read_workspace", "apply_edit", "inspect_diagnostics"],
    policy: buildPolicy(),
    systemPrompt: "Plan, edit and inspect one fixed workspace. No deployment.",
  });
  const result = await agent.run(
    { id: "workspace-plan" },
    "Plan, edit and inspect the fixed workspace without deploying.",
  );
  return { output: result.output, reads, edits, diagnostics };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runWorkspace(WORKSPACE);
  const report = JSON.parse(success.output);
  assert.equal(success.reads, 1);
  assert.equal(success.edits, 1);
  assert.equal(success.diagnostics, 1);
  assert.deepEqual(report.workspace.allowlist, ["app.js"]);
  assert.equal(report.edit.status, "applied_fixture");
  assert.equal(report.edit.changed, 1);
  assert.equal(report.diagnostics.build_status, "ok_fixture");
  assert.equal(report.diagnostics.diagnostics, 0);
  assert.equal(report.deployments, 0);

  await assert.rejects(
    () => runWorkspace("workspace-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runWorkspace(WORKSPACE, { simulateFailure: true }),
    (error) => /WORKSPACE_UNAVAILABLE/.test(error.message),
  );

  console.log("TypeScript workspace-plan tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--workspace");
    const workspace = index >= 0 ? process.argv[index + 1] : WORKSPACE;
    const simulateFailure = process.argv.includes("--simulate-failure");
    runWorkspace(workspace, { simulateFailure })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runWorkspace, WorkspaceModel };
