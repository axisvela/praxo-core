import Foundation
import PraxoCore

#if canImport(ucrt)
import ucrt
#elseif canImport(Glibc)
import Glibc
#else
import Darwin
#endif

final class FixtureModel: Model {
    let target: String

    init(_ target: String) {
        self.target = target
    }

    func generate(_ request: Request) throws -> Response {
        if request.messages.last?.role == Roles.tool {
            return Response(message: Message.assistant("recorded"))
        }
        return Response(message: Message.assistant("", toolCalls: [
            ToolCall(id: "record-1", name: "record", arguments: ["target": target]),
        ]))
    }
}

final class RecordTool: Tool {
    let name = "record"
    let description = "Record a target in an in-memory counter."
    var calls = 0

    func invoke(_ arguments: [String: Any]) throws -> Any {
        calls += 1
        return "recorded"
    }
}

struct GovernedPolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" {
            return Decision(allowed: true, reason: "model generation")
        }
        if action.kind == "tool.invoke" {
            let target = action.arguments?["target"] as? String
            return Decision(
                allowed: action.toolName == "record" && target == "public",
                reason: "only the public target is permitted"
            )
        }
        return Decision(allowed: false, reason: "unsupported action")
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func runScenario(_ target: String, _ effects: inout Int) throws -> String {
    let tool = RecordTool()
    defer { effects = tool.calls }
    let registry = ToolRegistry()
    registry.register(tool)
    let options = AgentOptions(FixtureModel(target))
    options.tools = registry
    options.maxSteps = 3
    options.allowedTools = ["record"]
    options.policy = GovernedPolicy()
    let result = try Agent(options).run(
        Session(id: "consumer-\(target)"),
        "Record the requested target."
    )
    return result.output
}

var allowedEffects = 0
var output = ""
do {
    output = try runScenario("public", &allowedEffects)
} catch {
    fail("allow verification failed: \(error)")
}
if output != "recorded" || allowedEffects != 1 {
    fail("allow verification failed: output=\(output) effects=\(allowedEffects)")
}
print("allow: recorded; effects=1")

var deniedEffects = 0
do {
    _ = try runScenario("private", &deniedEffects)
    fail("private target was not denied; effects=\(deniedEffects)")
} catch let error as PraxoError {
    if error.code != "POLICY_ERROR" || deniedEffects != 0 {
        fail("deny verification failed: effects=\(deniedEffects) code=\(error.code)")
    }
    print("deny: policy rejected; effects=0")
} catch {
    fail("deny verification failed: \(error)")
}
