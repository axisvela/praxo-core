import Foundation
import PraxoCore

final class GovState {
    var effects: [String: Int] = [:]
    var budget = 0
    var children = 0

    func record(_ target: String) {
        effects[target] = (effects[target] ?? 0) + 1
    }

    func count(_ target: String) -> Int {
        effects[target] ?? 0
    }
}

final class GovModel: Model {
    let tool: String
    let target: String
    let state: GovState
    var calls = 0

    init(tool: String, target: String, state: GovState) {
        self.tool = tool
        self.target = target
        self.state = state
    }

    func generate(_ request: Request) throws -> Response {
        calls += 1
        if calls == 1 {
            return Response(message: Message.assistant(
                "",
                toolCalls: [ToolCall(id: "call-1", name: tool,
                                     arguments: ["target": target])]))
        }
        return Response(message: Message.assistant("done"))
    }
}

struct GovPolicy: PolicyHook {
    let kind: Int

    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" { return Decision(allowed: true) }
        guard action.kind == "tool.invoke", let tool = action.toolName else {
            return Decision(allowed: false, reason: "unsupported action")
        }
        let target = action.arguments?["target"] as? String ?? ""
        if kind == 0 {
            return Decision(allowed: tool == "record", reason: "child may only record")
        }
        if kind == 1 {
            return Decision(allowed: tool == "record" && target != "blocked",
                            reason: "blocked target")
        }
        if kind == 2 {
            return Decision(allowed: tool == "delegate" ||
                            (tool == "record" && target != "blocked"),
                            reason: "parent policy")
        }
        return Decision(allowed: false, reason: "unknown policy")
    }
}

struct ChildConfig {
    var allowed: [String]
    var policyKind: Int
    var depth: Int
    var maxDepth: Int
    var maxChildren: Int
    var useBudget: Bool
    var useChildren: Bool
    var cancelled: Bool
    var editToBlocked: Bool
}

func deniedTask(_ status: String, _ code: String) -> SubagentTask {
    SubagentTask(id: "subagent", parentSessionID: "governance-parent",
                 agentID: "governance-child", mode: "isolated",
                 status: status, output: "", error: code,
                 createdAt: "", updatedAt: "")
}

func runChild(_ state: GovState, _ tool: String, _ target: String,
              _ config: ChildConfig) throws -> SubagentTask {
    if config.cancelled { return deniedTask("cancelled", "CANCELLED") }
    if config.maxDepth >= 0 && config.depth > config.maxDepth {
        return deniedTask("denied", "DEPTH_LIMIT")
    }
    if config.maxChildren >= 0 && state.children >= config.maxChildren {
        return deniedTask("denied", "CHILD_LIMIT")
    }
    if config.useBudget && state.budget <= 0 {
        return deniedTask("denied", "BUDGET_EXHAUSTED")
    }
    if config.useChildren { state.children += 1 }

    let tools = ToolRegistry()
    tools.register(FuncTool("record", "Record a target") { arguments in
        let value = arguments["target"] as? String ?? ""
        state.record(value)
        return "ok"
    })
    tools.register(FuncTool("write", "Write a target") { arguments in
        let value = arguments["target"] as? String ?? ""
        state.record(value)
        return "ok"
    })

    let options = AgentOptions(GovModel(tool: tool, target: target, state: state))
    options.tools = tools
    options.allowedTools = config.allowed
    options.policy = GovPolicy(kind: config.policyKind)
    options.requirePolicy = true
    options.requireToolScope = true
    options.maxSteps = 3
    if config.editToBlocked {
        options.interruptOn = ["record"]
        options.onInterruptDecision = { _ in
            InterruptDecision(action: INTERRUPT_EDIT,
                              arguments: ["target": "blocked"])
        }
    }

    let manager = SubagentManager(runner: { _ in
        let result = try Agent(options).run(
            Session(id: "governance-child"), "run child")
        return SubagentResult(taskID: "child", agentID: "child",
                              output: result.output)
    })
    let task = try manager.run(SubagentRequest(
        parentSessionID: "governance-parent",
        agentID: "governance-child",
        prompt: "run child"))
    if config.useBudget && task.status == "completed" {
        state.budget -= 1
    }
    return task
}

func runCase(_ state: GovState, _ tool: String, _ target: String,
             _ config: ChildConfig, _ status: String, _ error: String) throws {
    let task = try runChild(state, tool, target, config)
    guard task.status == status else {
        throw PraxoError("GOVERNANCE", "status \(task.status) expected \(status)")
    }
    if !error.isEmpty && task.error != error {
        throw PraxoError("GOVERNANCE", "error \(task.error) expected \(error)")
    }
}

func main() throws {
    let state = GovState()
    var config = ChildConfig(allowed: ["record"], policyKind: 0,
                             depth: 0, maxDepth: -1, maxChildren: -1,
                             useBudget: false, useChildren: false,
                             cancelled: false, editToBlocked: false)

    try runCase(state, "write", "escape", config, "failed", "")
    guard state.count("escape") == 0 else {
        throw PraxoError("GOVERNANCE", "escape effect")
    }

    config.policyKind = 2
    try runCase(state, "record", "blocked", config, "failed", "")
    guard state.count("blocked") == 0 else {
        throw PraxoError("GOVERNANCE", "blocked effect")
    }

    config.policyKind = 0
    config.useBudget = true
    state.budget = 1
    try runCase(state, "record", "sibling", config, "completed", "")
    try runCase(state, "record", "sibling", config, "denied", "BUDGET_EXHAUSTED")
    guard state.count("sibling") == 1 else {
        throw PraxoError("GOVERNANCE", "sibling effect")
    }

    config.useBudget = false
    config.useChildren = true
    config.maxChildren = 1
    state.children = 0
    try runCase(state, "record", "limit", config, "completed", "")
    try runCase(state, "record", "limit", config, "denied", "CHILD_LIMIT")

    config.useChildren = false
    config.maxChildren = -1
    config.depth = 2
    config.maxDepth = 1
    try runCase(state, "record", "limit", config, "denied", "DEPTH_LIMIT")
    guard state.count("limit") == 1 else {
        throw PraxoError("GOVERNANCE", "limit effect")
    }

    config.depth = 0
    config.maxDepth = -1
    config.cancelled = true
    try runCase(state, "record", "cancel", config, "cancelled", "CANCELLED")
    guard state.count("cancel") == 0 else {
        throw PraxoError("GOVERNANCE", "cancel effect")
    }

    config.cancelled = false
    config.policyKind = 1
    config.editToBlocked = true
    try runCase(state, "record", "edit-me", config, "failed", "")
    guard state.count("edit-me") == 0 else {
        throw PraxoError("GOVERNANCE", "edit effect")
    }
    guard state.count("blocked") == 0 else {
        throw PraxoError("GOVERNANCE", "edited blocked effect")
    }

    print("Swift advanced delegation governance: 6/6 passed")
}

try main()
