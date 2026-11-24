import Foundation
import PraxoCore

#if canImport(ucrt)
import ucrt
#elseif canImport(Glibc)
import Glibc
#else
import Darwin
#endif

let scopeID = "owner-100"

final class FixtureModel: Model {
    let scope: String

    init(_ scope: String) {
        self.scope = scope
    }

    func generate(_ request: Request) throws -> Response {
        let toolMessages = request.messages.filter { $0.role == Roles.tool }
        if toolMessages.isEmpty {
            return Response(message: Message.assistant("", toolCalls: [
                ToolCall(id: "tool-1", name: "recall_memory", arguments: [
                    "owner_id": scope, "action": "draft_deletion",
                ]),
            ]))
        }
        let result = toolMessages[toolMessages.count - 1].content ?? "{}"
        let report = """
        {"stage":"memory_drafted","result":\(result),"writes":0}
        """
        return Response(message: Message.assistant(report))
    }
}

final class FixtureTool: Tool {
    let name = "recall_memory"
    let description = "Read fixed digital twin memory fixtures and draft a review-only result."
    let simulateFailure: Bool
    var calls = 0

    init(simulateFailure: Bool) {
        self.simulateFailure = simulateFailure
    }

    func invoke(_ arguments: [String: Any]) throws -> Any {
        calls += 1
        guard arguments["owner_id"] as? String == scopeID else {
            throw PraxoError("AGENT_POLICY_DENIED", "scope outside fixture")
        }
        if simulateFailure {
            throw PraxoError("MEMORY_UNAVAILABLE", "fixture unavailable")
        }
        return [
            "id": scopeID,
            "count": 2,
            "secondary": 1,
            "status": "draft_only",
            "review_required": true,
            "writes": 0,
            "source": "fixture",
        ] as [String: Any]
    }
}

struct FixturePolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" {
            return Decision(allowed: true, reason: "deterministic tutorial review")
        }
        guard action.kind == "tool.invoke" else {
            return Decision(allowed: false, reason: "unsupported action")
        }
        guard action.arguments?["owner_id"] as? String == scopeID else {
            return Decision(allowed: false, reason: "only owner-100 is in scope")
        }
        if action.toolName == "recall_memory",
           action.arguments?["action"] as? String == "draft_deletion" {
            return Decision(allowed: true, reason: "owner-100 review-only draft")
        }
        return Decision(allowed: false, reason: "only a review-only draft is allowed")
    }
}

struct Outcome {
    let output: String
    let reads: Int
    let error: Error?
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func runScenario(_ scope: String, simulateFailure: Bool = false) -> Outcome {
    let tool = FixtureTool(simulateFailure: simulateFailure)
    let registry = ToolRegistry()
    registry.register(tool)
    let options = AgentOptions(FixtureModel(scope))
    options.tools = registry
    options.maxSteps = 3
    options.allowedTools = ["recall_memory"]
    options.policy = FixturePolicy()
    options.requirePolicy = true
    options.requireToolScope = true
    do {
        let result = try Agent(options).run(
            Session(id: "digital-twin-memory"),
            "Read fixed digital twin memory fixtures and draft a review-only result."
        )
        return Outcome(output: result.output, reads: tool.calls, error: nil)
    } catch {
        return Outcome(output: "", reads: tool.calls, error: error)
    }
}

func runTests() {
    let success = runScenario(scopeID)
    if success.error != nil || success.reads != 1 {
        fail("success failed: reads=\(success.reads) error=\(String(describing: success.error))")
    }
    guard let data = success.output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let report = object as? [String: Any],
          let result = report["result"] as? [String: Any] else {
        fail("success output is not JSON")
    }
    if result["status"] as? String != "draft_only"
        || result["writes"] as? Int != 0
        || report["writes"] as? Int != 0 {
        fail("unexpected draft result")
    }
    print("success: owner-100 status=draft_only writes=0 reads=1")

    let denied = runScenario("owner-200")
    if let error = denied.error as? PraxoError, error.code == "AGENT_POLICY_DENIED" {
        print("deny: AGENT_POLICY_DENIED reads=0")
    } else {
        fail("policy denial failed")
    }

    let failed = runScenario(scopeID, simulateFailure: true)
    if let error = failed.error as? PraxoError, error.code == "MEMORY_UNAVAILABLE" {
        print("failure: MEMORY_UNAVAILABLE reads=1")
    } else {
        fail("source failure failed")
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--test") {
    runTests()
} else {
    var scope = scopeID
    if let index = arguments.firstIndex(of: "--owner"), index + 1 < arguments.count {
        scope = arguments[index + 1]
    }
    let outcome = runScenario(scope, simulateFailure: arguments.contains("--simulate-failure"))
    if let error = outcome.error {
        fail("error: \(error) reads=\(outcome.reads)")
    }
    print(outcome.output)
    print("reads=\(outcome.reads)")
}
