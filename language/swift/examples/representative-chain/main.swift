import Foundation
import PraxoCore

final class ChainState {
    var effects: [String: Int] = [:]
    var otel = 0
    var harmovela = 0
    var childCalls = 0
}

final class FakeMcpTransport: McpTransport {
    let state: ChainState

    init(_ state: ChainState) {
        self.state = state
    }

    func request(_ method: String, _ params: [String: Any],
                 timeout: TimeInterval) throws -> [String: Any] {
        if method == "initialize" {
            return ["protocolVersion": "2024-11-05",
                    "serverInfo": ["name": "fake-mcp"]]
        }
        if method == "tools/list" {
            return ["tools": [[
                "name": "record",
                "description": "Record a target",
                "inputSchema": [
                    "type": "object",
                    "properties": ["target": ["type": "string"]],
                    "required": ["target"],
                ],
            ]]]
        }
        if method == "tools/call" {
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let target = arguments["target"] as? String ?? ""
            state.effects[target] = (state.effects[target] ?? 0) + 1
            return ["content": [["type": "text", "text": "recorded:\(target)"]]]
        }
        return [:]
    }

    func notify(_ method: String, _ params: [String: Any]) throws {}
    func close() {}
}

final class CaptureOtel: OtelTransport {
    let state: ChainState

    init(_ state: ChainState) {
        self.state = state
    }

    func send(_ request: OtelHTTPRequest) throws -> OtelHTTPResponse {
        state.otel += 1
        return OtelHTTPResponse(statusCode: 200, body: "")
    }
}

final class CaptureHarmovela: HarmovelaTransport {
    let state: ChainState

    init(_ state: ChainState) {
        self.state = state
    }

    func send(_ request: HarmovelaHTTPRequest) throws -> HarmovelaHTTPResponse {
        state.harmovela += 1
        return HarmovelaHTTPResponse(statusCode: 202, body: "")
    }
}

final class OtelEventSink: EventSink {
    let sink: OtelSink

    init(_ sink: OtelSink) {
        self.sink = sink
    }

    func emit(_ event: Event) {
        try? sink.emit(event)
    }
}

final class HarmovelaEventSink: EventSink {
    let sink: HarmovelaSink

    init(_ sink: HarmovelaSink) {
        self.sink = sink
    }

    func emit(_ event: Event) {
        try? sink.emit(event)
    }
}

final class ScriptedModel: Model {
    var steps: [[String: Any]]
    let finalContent: String
    let onCall: (() -> Void)?
    var calls = 0

    init(_ steps: [[String: Any]], _ finalContent: String,
         onCall: (() -> Void)? = nil) {
        self.steps = steps
        self.finalContent = finalContent
        self.onCall = onCall
    }

    func generate(_ request: Request) throws -> Response {
        calls += 1
        onCall?()
        if !steps.isEmpty {
            let step = steps.removeFirst()
            let calls = step["toolCalls"] as? [ToolCall] ?? []
            return Response(message: Message.assistant(step["content"] as? String ?? "",
                                                       toolCalls: calls))
        }
        return Response(message: Message.assistant(finalContent))
    }
}

struct ParentPolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" { return Decision(allowed: true) }
        guard action.kind == "tool.invoke" else { return Decision(allowed: false) }
        if action.toolName == "record" {
            let target = action.arguments?["target"] as? String ?? ""
            return Decision(allowed: target != "blocked", reason: "blocked target")
        }
        if action.toolName == "delegate" { return Decision(allowed: true) }
        return Decision(allowed: false, reason: "parent tool is not allowed")
    }
}

struct ChildPolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" { return Decision(allowed: true) }
        if action.kind == "tool.invoke" && action.toolName == "record" {
            return Decision(allowed: true)
        }
        return Decision(allowed: false, reason: "child may only record")
    }
}

struct ComposedPolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        let parent = ParentPolicy().authorize(action)
        if !parent.allowed { return parent }
        return ChildPolicy().authorize(action)
    }
}

func recordCall(_ id: String, _ target: String) -> ToolCall {
    ToolCall(id: id, name: "record", arguments: ["target": target])
}

func response(_ call: ToolCall) -> Response {
    Response(message: Message.assistant("", toolCalls: [call]))
}

func main() throws {
    let state = ChainState()
    let transport = FakeMcpTransport(state)
    let client = try McpClient(transport: transport).start()
    let tools = try client.listTools()
    guard tools.count == 1 else { throw PraxoError("MCP", "unexpected tools") }

    let otel = OtelSink(endpoint: "http://otel.local/v1/traces",
                        transport: CaptureOtel(state),
                        clock: { 1794294000000000000 })
    let harmovela = HarmovelaSink(baseURL: "http://harmovela.local",
                                  transport: CaptureHarmovela(state),
                                  clock: { HarmovelaTimestamp(unixNanos: 1794294000000000000,
                                                              createdAt: "2026-11-17T00:00:00.000000000Z") })
    let events = MultiSink([OtelEventSink(otel), HarmovelaEventSink(harmovela)])

    let record = FuncTool("record", "Record a target through the MCP client") { arguments in
        try client.callTool("record", arguments)
    }
    let childModel = ScriptedModel(
        [["content": "", "toolCalls": [recordCall("child-record", "child")]]],
        "DONE",
        onCall: { state.childCalls += 1 })
    let delegate = FuncTool("delegate", "Run a governed child agent") { _ in
        let options = AgentOptions(childModel)
        options.tools = ToolRegistry()
        options.tools?.register(record)
        options.allowedTools = ["record"]
        options.policy = ChildPolicy()
        options.requirePolicy = true
        options.requireToolScope = true
        options.maxSteps = 3
        options.events = events
        let result = try Agent(options).run(Session(id: "chain-child"), "record child")
        return result.output
    }

    let parentModel = ScriptedModel([
        ["content": "", "toolCalls": [recordCall("parent-record", "parent")]],
        ["content": "", "toolCalls": [ToolCall(id: "parent-delegate", name: "delegate",
                                               arguments: ["task": "record child"])]],
    ], "DONE")
    let parentOptions = AgentOptions(parentModel)
    parentOptions.tools = ToolRegistry()
    parentOptions.tools?.register(record)
    parentOptions.tools?.register(delegate)
    parentOptions.allowedTools = ["record", "delegate"]
    parentOptions.policy = ParentPolicy()
    parentOptions.requirePolicy = true
    parentOptions.requireToolScope = true
    parentOptions.maxSteps = 4
    parentOptions.events = events
    let parent = try Agent(parentOptions).run(Session(id: "chain-parent"),
                                              "record parent, then delegate")

    let deniedModel = ScriptedModel([
        ["content": "", "toolCalls": [recordCall("denied-record", "edit-me")]],
    ], "DONE")
    let deniedOptions = AgentOptions(deniedModel)
    deniedOptions.tools = ToolRegistry()
    deniedOptions.tools?.register(record)
    deniedOptions.allowedTools = ["record"]
    deniedOptions.policy = ParentPolicy()
    deniedOptions.requirePolicy = true
    deniedOptions.requireToolScope = true
    deniedOptions.maxSteps = 2
    deniedOptions.events = events
    deniedOptions.interruptOn = ["record"]
    deniedOptions.onInterruptDecision = { _ in
        InterruptDecision(action: INTERRUPT_EDIT, arguments: ["target": "blocked"])
    }
    var deniedError = ""
    do {
        _ = try Agent(deniedOptions).run(Session(id: "chain-denied"),
                                         "attempt a denied edit")
    } catch let error as PraxoError {
        deniedError = error.code
    }

    print("output: \(parent.output)")
    print("effects: parent=\(state.effects["parent"] ?? 0) child=\(state.effects["child"] ?? 0)")
    print("child calls: \(state.childCalls)")
    print("otel spans: \(state.otel)")
    print("harmovela events: \(state.harmovela)")
    print("denied effects: \(state.effects["blocked"] ?? 0)")
    guard parent.output == "DONE",
          state.effects["parent"] == 1,
          state.effects["child"] == 1,
          state.childCalls == 2,
          state.otel >= 3,
          state.harmovela >= 3,
          (state.effects["blocked"] ?? 0) == 0,
          !deniedError.isEmpty else {
        throw PraxoError("CHAIN", "representative chain failed")
    }
}

try main()
