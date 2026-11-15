import Foundation
import XCTest
@testable import PraxoCore

private final class HitlSink: EventSink {
    var events: [Event] = []
    var types: [String] { events.map(\.type) }

    func emit(_ event: Event) {
        events.append(event)
    }
}

private final class HitlModel: Model {
    private let call: ToolCall
    private(set) var requests: [Request] = []

    init(_ call: ToolCall) {
        self.call = call
    }

    func generate(_ request: Request) throws -> Response {
        requests.append(request)
        if request.messages.last?.role == Roles.tool {
            return Response(message: Message.assistant("done"))
        }
        return Response(message: Message.assistant("", toolCalls: [call]))
    }
}

private final class HitlTool: Tool {
    let name: String
    let description = "Write a short note with the requested visibility."
    private(set) var calls: [[String: Any]] = []
    private let result: Any

    init(_ name: String, result: Any = "written") {
        self.name = name
        self.result = result
    }

    func invoke(_ arguments: [String: Any]) throws -> Any {
        calls.append(arguments)
        return result
    }
}

private final class HitlPolicy: PolicyHook {
    private(set) var actions: [Action] = []

    var toolActions: [Action] {
        actions.filter { $0.kind == "tool.invoke" }
    }

    func authorize(_ action: Action) -> Decision {
        actions.append(action)
        if action.kind == "model.generate" {
            return Decision(allowed: true, reason: "model generation")
        }
        if action.kind == "tool.invoke" {
            let visibility = action.arguments?["visibility"] as? String
            return Decision(
                allowed: action.toolName == "write_note" && visibility == "public",
                reason: "only public notes are permitted"
            )
        }
        return Decision(allowed: false, reason: "unsupported action")
    }
}

private func hitlArguments(_ visibility: String = "public") -> [String: Any] {
    ["text": "hello", "visibility": visibility]
}

private func hitlToolCall(_ visibility: String = "public") -> ToolCall {
    ToolCall(id: "write-note-1", name: "write_note", arguments: hitlArguments(visibility))
}

private func makeHitlAgent(
    _ model: HitlModel,
    _ tool: HitlTool,
    policy: PolicyHook? = nil,
    sink: EventSink? = nil,
    decision: InterruptHandler? = nil,
    approval: InterruptApproval? = nil
) throws -> Agent {
    let registry = ToolRegistry()
    registry.register(tool)
    let options = AgentOptions(model)
    options.tools = registry
    options.maxSteps = 3
    options.allowedTools = ["write_note"]
    options.policy = policy
    options.events = sink
    options.interruptOn = ["write_note"]
    options.onInterruptDecision = decision
    options.onInterrupt = approval
    return try Agent(options)
}

final class HitlTests: XCTestCase {
    func testHitlApproveContinues() throws {
        let sink = HitlSink()
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        var observed: Interrupt?
        let agent = try makeHitlAgent(model, tool, sink: sink, decision: { interrupt in
            observed = interrupt
            return InterruptDecision(action: INTERRUPT_APPROVE)
        })

        let result = try agent.run(Session(id: "hitl-approve"), "Write a note.")

        XCTAssertEqual(result.output, "done")
        XCTAssertEqual(tool.calls.count, 1)
        XCTAssertEqual(tool.calls.first?["visibility"] as? String, "public")
        XCTAssertEqual(observed?.sessionID, "hitl-approve")
        XCTAssertEqual(observed?.sessionId, "hitl-approve")
        XCTAssertEqual(observed?.call.name, "write_note")
        XCTAssertEqual(observed?.call.arguments["text"] as? String, "hello")
        XCTAssertFalse(observed?.runID.isEmpty ?? true)
        XCTAssertFalse(observed?.runId.isEmpty ?? true)

        let interrupts = sink.events.filter { $0.type == "tool.interrupt" }
        XCTAssertEqual(interrupts.count, 1)
        XCTAssertEqual(interrupts.first?.data?["name"] as? String, "write_note")
        let arguments = interrupts.first?.data?["arguments"] as? [String: Any]
        XCTAssertEqual(arguments?["visibility"] as? String, "public")
    }

    func testHitlEditReauthorizesAndDeniesBeforeEffect() throws {
        let policy = HitlPolicy()
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        let agent = try makeHitlAgent(model, tool, policy: policy, decision: { _ in
            InterruptDecision(action: INTERRUPT_EDIT, arguments: hitlArguments("private"))
        })

        XCTAssertThrowsError(try agent.run(Session(id: "hitl-edit"), "Write a note.")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_POLICY_DENIED")
        }
        XCTAssertEqual(tool.calls.count, 0)
        XCTAssertEqual(policy.toolActions.count, 2)
        XCTAssertEqual(policy.toolActions.first?.arguments?["visibility"] as? String, "public")
        XCTAssertEqual(policy.toolActions.last?.arguments?["visibility"] as? String, "private")
    }

    func testHitlRejectPreventsEffects() throws {
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        let agent = try makeHitlAgent(model, tool, decision: { _ in
            InterruptDecision(action: INTERRUPT_REJECT, reason: "not allowed")
        })

        XCTAssertThrowsError(try agent.run(Session(id: "hitl-reject"), "Write a note.")) { error in
            let praxo = error as? PraxoError
            XCTAssertEqual(praxo?.code, "AGENT_APPROVAL_DENIED")
            XCTAssertTrue(praxo?.message.contains("not allowed") ?? false)
        }
        XCTAssertEqual(tool.calls.count, 0)
    }

    func testHitlRespondSkipsToolAndUsesResponse() throws {
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        let agent = try makeHitlAgent(model, tool, decision: { _ in
            InterruptDecision(action: INTERRUPT_RESPOND, response: "use cached result")
        })

        let result = try agent.run(Session(id: "hitl-respond"), "Write a note.")

        XCTAssertEqual(result.output, "done")
        XCTAssertEqual(tool.calls.count, 0)
        XCTAssertEqual(model.requests.count, 2)
        let last = model.requests[1].messages.last
        XCTAssertEqual(last?.role, Roles.tool)
        XCTAssertEqual(last?.content, "\"use cached result\"")
        XCTAssertEqual(last?.toolID, "write-note-1")
    }

    func testHitlUnhandledRequiresHandler() throws {
        let sink = HitlSink()
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        let agent = try makeHitlAgent(model, tool, sink: sink)

        XCTAssertThrowsError(try agent.run(Session(id: "hitl-unhandled"), "Write a note.")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_INTERRUPT_UNHANDLED")
        }
        XCTAssertEqual(tool.calls.count, 0)
        XCTAssertFalse(sink.types.contains("tool.interrupt"))
    }

    func testHitlRejectsInvalidDecision() throws {
        let unknownTool = HitlTool("write_note")
        let unknownModel = HitlModel(hitlToolCall())
        let unknown = try makeHitlAgent(unknownModel, unknownTool, decision: { _ in
            InterruptDecision(action: "unknown")
        })

        XCTAssertThrowsError(try unknown.run(Session(id: "hitl-invalid"), "Write a note.")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_INTERRUPT_DECISION_INVALID")
        }
        XCTAssertEqual(unknownTool.calls.count, 0)

        let editTool = HitlTool("write_note")
        let editModel = HitlModel(hitlToolCall())
        let edit = try makeHitlAgent(editModel, editTool, decision: { _ in
            InterruptDecision(action: INTERRUPT_EDIT)
        })

        XCTAssertThrowsError(try edit.run(Session(id: "hitl-invalid-edit"), "Write a note.")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_INTERRUPT_DECISION_INVALID")
        }
        XCTAssertEqual(editTool.calls.count, 0)
    }

    func testHitlApprovalCallbackCanDeny() throws {
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        let agent = try makeHitlAgent(model, tool, approval: { _ in false })

        XCTAssertThrowsError(try agent.run(Session(id: "hitl-approval"), "Write a note.")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_APPROVAL_DENIED")
        }
        XCTAssertEqual(tool.calls.count, 0)
    }

    func testHitlRunsAfterBeforeToolMiddleware() throws {
        let policy = HitlPolicy()
        let tool = HitlTool("write_note")
        let model = HitlModel(hitlToolCall())
        var observed: String?
        let registry = ToolRegistry()
        registry.register(tool)
        let options = AgentOptions(model)
        options.tools = registry
        options.maxSteps = 3
        options.allowedTools = ["write_note"]
        options.policy = policy
        options.interruptOn = ["write_note"]
        options.middleware = [
            ToolMiddleware(beforeTool: { _, _, call in
                var updated = call
                updated.arguments["text"] = "from-middleware"
                return updated
            }),
        ]
        options.onInterruptDecision = { interrupt in
            observed = interrupt.call.arguments["text"] as? String
            return InterruptDecision(action: INTERRUPT_APPROVE)
        }

        let result = try Agent(options).run(Session(id: "hitl-middleware"), "Write a note.")

        XCTAssertEqual(result.output, "done")
        XCTAssertEqual(observed, "from-middleware")
        XCTAssertEqual(tool.calls.first?["text"] as? String, "from-middleware")
    }

    func testHitlExampleApproveAndEditScenarios() throws {
        let approveTool = HitlTool("write_note")
        let approveModel = HitlModel(hitlToolCall())
        let approve = try makeHitlAgent(approveModel, approveTool, policy: HitlPolicy(), decision: { _ in
            InterruptDecision(action: INTERRUPT_APPROVE)
        })
        let approveResult = try approve.run(Session(id: "hitl-approve"), "Write a note.")
        XCTAssertEqual(approveResult.output, "done")
        XCTAssertEqual(approveTool.calls.count, 1)

        let editTool = HitlTool("write_note")
        let editModel = HitlModel(hitlToolCall())
        let edit = try makeHitlAgent(editModel, editTool, policy: HitlPolicy(), decision: { _ in
            InterruptDecision(action: INTERRUPT_EDIT, arguments: hitlArguments("private"))
        })
        XCTAssertThrowsError(try edit.run(Session(id: "hitl-edit"), "Write a note.")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_POLICY_DENIED")
        }
        XCTAssertEqual(editTool.calls.count, 0)
    }
}
