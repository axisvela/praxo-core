import Foundation
import PraxoCore

final class RecordingSink: EventSink {
    var types: [String] = []
    func emit(_ event: Event) { types.append(event.type) }
}

final class ScriptedModel: Model {
    private let steps: [[String: Any]]
    private var next = 0

    init(_ steps: [Any]) {
        self.steps = steps.compactMap { $0 as? [String: Any] }
    }

    func generate(_ request: Request) throws -> Response {
        guard next < steps.count else { throw PraxoError("SCRIPT", "script exhausted") }
        let step = steps[next]
        next += 1
        let calls = Json.array(step, "toolCalls").compactMap { item -> ToolCall? in
            guard let item = item as? [String: Any] else { return nil }
            return ToolCall(
                id: item["id"] as? String ?? "",
                name: item["name"] as? String ?? "",
                arguments: item["arguments"] as? [String: Any] ?? [:]
            )
        }
        return Response(
            message: Message.assistant(step["content"] as? String ?? "", toolCalls: calls),
            usage: Usage(
                inputTokens: Json.int(step, "inputTokens"),
                outputTokens: Json.int(step, "outputTokens")
            )
        )
    }
}

struct FixedSelector: ToolSelector {
    let names: [String]
    func select(_ query: String, _ tools: [ToolSpec]) -> [String] { names }
}

func code(_ error: Error) -> String { (error as? PraxoError)?.code ?? "" }

func runMemory(_ input: Any?, _ expect: Any?) throws {
    let store = MemoryStore()
    for item in Json.array(input, "puts") {
        let record = Json.get(item, "record")
        store.put(Json.string(item, "session") ?? "", MemoryRecord(
            id: Json.string(record, "id") ?? "",
            frame: Json.string(record, "frame") ?? "",
            content: Json.string(record, "content") ?? "",
            createdAt: Json.string(record, "createdAt")
        ))
    }
    let records = store.search(Json.string(input, "session") ?? "",
                               Json.string(input, "query") ?? "", Json.int(input, "limit"))
    let ids: Any = records.isEmpty ? NSNull() : records.map { $0.id }
    let contents: Any = records.isEmpty ? NSNull() : records.map { $0.content }
    try check(Json.equals(ids, Json.get(expect, "ids")), "ids mismatch")
    try check(Json.equals(contents, Json.get(expect, "contents")), "contents mismatch")
}

func runEvent(_ input: Any?, _ expect: Any?) throws {
    let events = Json.array(input, "events").map {
        Event(type: $0 as? String ?? "", sessionID: "s1")
    }
    if Json.string(input, "sink") == "multi" {
        let count = max(1, Json.int(input, "sinkCount", fallback: 1))
        let sinks = (0..<count).map { _ in RecordingSink() }
        let multi = MultiSink(sinks)
        events.forEach { multi.emit($0) }
        let perSink = sinks.map { $0.types }
        try check(Json.equals(perSink, Json.get(expect, "perSink")), "perSink mismatch")
        return
    }
    let sink = RecordingSink()
    let predicate = Json.get(input, "predicateTypes") as? [Any]
    let allowed = predicate.map { Set($0.compactMap { $0 as? String }) }
    let filter = FilterSink(sink) { event in allowed?.contains(event.type) ?? true }
    events.forEach { filter.emit($0) }
    let delivered: Any = sink.types.isEmpty ? NSNull() : sink.types
    try check(Json.equals(delivered, Json.get(expect, "delivered")), "delivered mismatch")
}

func runStream(_ expect: Any?) throws {
    try check(Json.equals(streamKinds, Json.get(expect, "kinds")), "kinds mismatch")
}

func runCheckpoint(_ input: Any?, _ expect: Any?) throws {
    let allow = CheckpointAllowlist()
    for type in Json.array(input, "registered") {
        try allow.register(type as? String ?? "")
    }
    let operation = Json.string(input, "operation") ?? "roundtrip"
    let type = Json.string(input, "type") ?? ""
    let value = Json.get(input, "value")
    if operation == "roundtrip" {
        let data = try allow.marshal(type, value)
        try check(Json.equals(try allow.unmarshal(data), Json.get(expect, "value")), "value mismatch")
        return
    }
    var caught = ""
    do {
        if operation == "marshal" {
            _ = try allow.marshal(type, value)
        } else if operation == "unmarshal" {
            _ = try allow.unmarshal(try Json.stringify(["type": type, "data": value ?? NSNull()]))
        } else {
            throw PraxoError("CHECKPOINT_ERROR", "unknown operation")
        }
    } catch {
        caught = code(error)
    }
    try check(caught == (Json.string(expect, "errorCode") ?? ""), "errorCode: got \(caught)")
}

func runPolicy(_ input: Any?, _ expect: Any?) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("praxo-policy-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for dir in Json.array(input, "makeDirs") {
        let path = root.appendingPathComponent(dir as? String ?? "")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    }
    let grants = Json.array(input, "grants").compactMap { item -> PathGrant? in
        let grantRoot = root.appendingPathComponent(Json.string(item, "root") ?? "")
        try? FileManager.default.createDirectory(at: grantRoot, withIntermediateDirectories: true)
        return PathGrant(root: grantRoot.path, access: Json.string(item, "access") ?? "read")
    }
    let checker = PathChecker(grants)
    let target = root.appendingPathComponent(Json.string(input, "target") ?? "").path
    let need = Json.string(input, "need") ?? "read"
    if Json.bool(expect, "error") {
        var caught = false
        do { _ = try checker.check(target, need) } catch { caught = true }
        try check(caught, "expected a policy error")
        return
    }
    let allowed = try checker.check(target, need).allowed
    try check(allowed == Json.bool(expect, "allowed"), "allowed mismatch")
}

func runContext(_ input: Any?, _ expect: Any?) throws {
    let messages = Json.array(input, "messages").map { item in
        Message(role: Json.string(item, "role") ?? "", content: Json.string(item, "content"))
    }
    if Json.string(input, "operation") == "estimate" {
        try check(ContextEstimator.estimate(messages) == Json.int(expect, "tokens"), "tokens mismatch")
        return
    }
    let budget = ContextBudget(
        maxTokens: Json.int(Json.get(input, "budget"), "maxTokens"),
        keepRecent: Json.int(Json.get(input, "budget"), "keepRecent")
    )
    let (output, ok) = budget.compact(messages)
    try check(ok == Json.bool(expect, "ok"), "ok mismatch")
    if !ok { return }
    try check(ContextEstimator.estimate(output) == Json.int(expect, "tokens"), "tokens mismatch")
    try check(Json.equals(output.map { $0.wire() }, Json.get(expect, "messages")), "messages mismatch")
}

func runMiddleware(_ input: Any?, _ expect: Any?) throws {
    switch Json.string(input, "operation") ?? "" {
    case "pii":
        try check(PiiRedactor().redact(Json.string(input, "text") ?? "") == (Json.string(expect, "text") ?? ""), "text mismatch")
    case "pii-value":
        try check(Json.equals(PiiRedactor().redactValue(Json.get(input, "value")), Json.get(expect, "value")), "value mismatch")
    case "structured":
        let output = StructuredOutput(schema: Json.get(input, "schema") as? [String: Any] ?? [:],
                                      maxRepairs: Json.int(input, "maxRepairs"))
        if let repair = Json.string(input, "repairOutput") { output.repairer = { _ in repair } }
        let result = output.apply(Json.string(input, "output") ?? "")
        if Json.bool(expect, "ok") {
            try check(result.0 == (Json.string(expect, "output") ?? ""), "output mismatch")
        } else {
            try check(result.1 == (Json.string(expect, "errorCode") ?? ""), "errorCode mismatch")
        }
    case "call-limit":
        let limit = CallLimit(modelLimit: Json.int(input, "modelLimit"), toolLimit: Json.int(input, "toolLimit"))
        var outcomes: [String] = []
        for item in Json.array(input, "calls") {
            do {
                if (item as? String) == "model" { try limit.beforeModel() } else { try limit.beforeTool() }
                outcomes.append("ok")
            } catch { outcomes.append(code(error)) }
        }
        try check(Json.equals(outcomes, Json.get(expect, "outcomes")), "outcomes mismatch")
    case "tool-selection":
        let selection = ToolSelection((Json.get(input, "selected") as? [Any] ?? []).compactMap { $0 as? String })
        let tools = Json.array(input, "tools").compactMap { ($0 as? String).map { ToolSpec(name: $0) } }
        let advertised = selection.filter(tools).map { $0.name }
        try check(Json.equals(advertised, Json.get(expect, "advertised")), "advertised mismatch")
        var rejected = "ok"
        do { try selection.reject(Json.string(input, "requested") ?? "") } catch { rejected = code(error) }
        try check(rejected == (Json.string(expect, "reject") ?? ""), "reject mismatch")
    case "fallback":
        let content = Json.string(input, "fallbackContent") ?? ""
        let middleware = Fallback.wrap(StaticModel(content))
        let handler = middleware { _ in throw PraxoError("PRIMARY_FAILED", "primary") }
        let response = try handler(Request())
        try check(response.message.content == content, "output mismatch")
    default:
        throw PraxoError("CONFORMANCE", "unknown middleware operation")
    }
}

func runAgentLoop(_ input: Any?, _ expect: Any?) throws {
    var invocations = 0
    let registry = ToolRegistry()
    for tool in Json.array(input, "tools") {
        registry.register(FuncTool(Json.string(tool, "name") ?? "",
                                   Json.string(tool, "description") ?? "") { args in
            invocations += 1
            return args
        })
    }
    let sink = RecordingSink()
    let options = AgentOptions(ScriptedModel(Json.array(input, "script")))
    options.tools = registry
    options.events = sink
    options.maxSteps = Json.int(input, "maxSteps")
    options.maxTokens = Json.int(input, "maxTokens")
    let agent = Agent(options)
    var result: RunResult?
    var failure: Error?
    do { result = try agent.run(Session(id: "s1"), Json.string(input, "prompt") ?? "") }
    catch { failure = error }
    if Json.bool(expect, "error") {
        try check(failure != nil, "unexpected success")
        if let expected = Json.string(expect, "errorCode") {
            try check(code(failure!) == expected, "errorCode mismatch")
        }
    } else {
        try check(failure == nil, "unexpected failure")
        try check(result?.output == (Json.string(expect, "output") ?? ""), "output mismatch")
        try check(result?.steps == Json.int(expect, "steps"), "steps mismatch")
    }
    try check(invocations == Json.int(expect, "toolInvocations"), "tool invocations mismatch")
    let events: Any = sink.types.isEmpty ? NSNull() : sink.types
    try check(Json.equals(events, Json.get(expect, "events")), "events mismatch")
}
