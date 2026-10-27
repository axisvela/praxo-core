import Foundation
import XCTest
@testable import PraxoCore

private final class TestSink: EventSink {
    var types: [String] = []
    func emit(_ event: Event) { types.append(event.type) }
}

private final class ScriptedTestModel: Model {
    private let steps: [Message]
    private var next = 0

    init(_ steps: [Message]) { self.steps = steps }

    func generate(_ request: Request) throws -> Response {
        guard next < steps.count else { throw PraxoError("SCRIPT", "exhausted") }
        let step = steps[next]
        next += 1
        return Response(message: step)
    }
}

final class CoreTests: XCTestCase {
    func testContextEstimateAndCompact() {
        let messages = [Message.text(Roles.system, "sys")]
            + (0...9).map { Message.text(Roles.user, "message \($0)") }
        XCTAssertEqual(ContextEstimator.estimate(messages), 64)

        let (out, ok) = ContextBudget(maxTokens: 30, keepRecent: 2).compact(messages)
        XCTAssertTrue(ok)
        XCTAssertEqual(ContextEstimator.estimate(out), 25)
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(out[0].content, "sys")
        XCTAssertEqual(out[1].content, "[context compacted: 8 older messages omitted]")
        XCTAssertEqual(out[2].content, "message 9")
    }

    func testContextFailsClosedForImpossibleBudget() {
        let messages = [Message.text(Roles.system, String(repeating: "x", count: 100))]
        XCTAssertFalse(ContextBudget(maxTokens: 2, keepRecent: 0).compact(messages).1)
    }

    func testMemorySearchNewestFirst() {
        let store = MemoryStore()
        store.put("s1", MemoryRecord(
            id: "m1", frame: "event", content: "Alpha", createdAt: "2026-01-01T00:00:00Z"
        ))
        store.put("s1", MemoryRecord(
            id: "m2", frame: "event", content: "beta", createdAt: "2026-01-02T00:00:00Z"
        ))
        store.put("s1", MemoryRecord(
            id: "m3", frame: "decision", content: "ALPHABET", createdAt: "2026-01-03T00:00:00Z"
        ))
        XCTAssertEqual(store.search("s1", "alpha", 10).map(\.id), ["m3", "m1"])
        XCTAssertEqual(store.search("s1", "", 1).map(\.id), ["m3"])
    }

    func testCheckpointAllowlist() throws {
        let allowlist = CheckpointAllowlist()
        try allowlist.register("spec.payload")
        let envelope = try allowlist.marshal("spec.payload", ["value": "x"])
        let decoded = try allowlist.unmarshal(envelope) as? [String: Any]
        XCTAssertEqual(decoded?["value"] as? String, "x")

        XCTAssertThrowsError(try allowlist.marshal("spec.missing", [:])) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "CHECKPOINT_TYPE_NOT_ALLOWED")
        }
    }

    func testPathCheckerConfinesRoots() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("praxo-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("root")
        let sibling = base.appendingPathComponent("root-evil")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)

        let checker = PathChecker([PathGrant(root: root.path, access: "readwrite")])
        XCTAssertTrue(try checker.check(root.appendingPathComponent("a.txt").path, "read").allowed)
        XCTAssertFalse(try checker.check(sibling.appendingPathComponent("x.txt").path, "read").allowed)
        XCTAssertThrowsError(try checker.check(root.path, "execute"))
    }

    func testMiddlewareBehaviors() throws {
        XCTAssertEqual(PiiRedactor().redact("email a@b.com"), "email [REDACTED:email]")

        let schema: [String: Any] = [
            "type": "object",
            "properties": ["value": ["type": "integer"]],
            "required": ["value"],
        ]
        let structured = StructuredOutput(schema: schema, maxRepairs: 0)
        XCTAssertEqual(structured.apply("{\"value\":1}").0, "{\"value\":1}")
        XCTAssertEqual(structured.apply("not json").1, "AGENT_STRUCTURED_OUTPUT")

        let limit = CallLimit(modelLimit: 1, toolLimit: 0)
        try limit.beforeModel()
        XCTAssertThrowsError(try limit.beforeModel()) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_MODEL_CALL_LIMIT")
        }

        let selection = ToolSelection(["echo"])
        XCTAssertEqual(selection.filter([ToolSpec(name: "echo"), ToolSpec(name: "other")]).map(\.name),
                       ["echo"])
        XCTAssertThrowsError(try selection.reject("other")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_TOOL_NOT_SELECTED")
        }

        let middleware = Fallback.wrap(StaticModel("fallback"))
        let handler = middleware { _ in
            throw PraxoError("PRIMARY_FAILED", "primary")
        }
        XCTAssertEqual(try handler(Request()).message.content, "fallback")
    }

    func testAgentLoopRunsToolThenAnswers() throws {
        var invocations = 0
        let registry = ToolRegistry()
        registry.register(FuncTool("echo", "Echo arguments") { arguments in
            invocations += 1
            return arguments
        })
        let model = ScriptedTestModel([
            Message.assistant("", toolCalls: [
                ToolCall(id: "c1", name: "echo", arguments: ["text": "hi"]),
            ]),
            Message.assistant("done"),
        ])
        let sink = TestSink()
        let options = AgentOptions(model)
        options.tools = registry
        options.events = sink

        let result = try Agent(options).run(Session(id: "s1"), "use the tool")
        XCTAssertEqual(result.output, "done")
        XCTAssertEqual(result.steps, 2)
        XCTAssertEqual(invocations, 1)
        XCTAssertEqual(sink.types, ["run.started", "tool.call", "run.completed"])
    }

    func testAgentLoopFailsClosedAtMaxSteps() {
        let registry = ToolRegistry()
        registry.register(FuncTool("echo", "Echo arguments") { $0 })
        let model = ScriptedTestModel([
            Message.assistant("", toolCalls: [ToolCall(id: "c1", name: "echo")]),
            Message.assistant("", toolCalls: [ToolCall(id: "c2", name: "echo")]),
        ])
        let options = AgentOptions(model)
        options.tools = registry
        options.maxSteps = 1

        XCTAssertThrowsError(try Agent(options).run(Session(id: "s1"), "loop")) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "AGENT_MAX_STEPS")
        }
    }

    func testEventSinks() {
        let first = TestSink()
        let second = TestSink()
        let multi = MultiSink([first, second])
        multi.emit(Event(type: "run.started", sessionID: "s1"))
        multi.emit(Event(type: "run.completed", sessionID: "s1"))
        XCTAssertEqual(first.types, ["run.started", "run.completed"])
        XCTAssertEqual(second.types, ["run.started", "run.completed"])

        let filtered = TestSink()
        let filter = FilterSink(filtered) { $0.type == "run.started" }
        multi.emit(Event(type: "tool.call", sessionID: "s1"))
        filter.emit(Event(type: "run.started", sessionID: "s1"))
        filter.emit(Event(type: "tool.call", sessionID: "s1"))
        XCTAssertEqual(filtered.types, ["run.started"])
    }
}
