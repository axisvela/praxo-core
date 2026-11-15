import Foundation
import PraxoCore

final class FixtureModel: Model {
    func generate(_ request: Request) throws -> Response {
        if request.messages.last?.role == Roles.tool {
            return Response(message: Message.assistant("done"))
        }
        return Response(message: Message.assistant("", toolCalls: [
            ToolCall(
                id: "write-note-1",
                name: "write_note",
                arguments: ["text": "hello", "visibility": "public"]
            ),
        ]))
    }
}

final class WriteNoteTool: Tool {
    let name = "write_note"
    let description = "Write a short note with the requested visibility."
    private(set) var notes: [String] = []

    func invoke(_ arguments: [String: Any]) throws -> Any {
        notes.append(arguments["text"] as? String ?? "")
        return "written"
    }
}

struct PublicNotesPolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
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

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func buildAgent(_ decision: InterruptDecision) throws -> (Agent, WriteNoteTool) {
    let tool = WriteNoteTool()
    let registry = ToolRegistry()
    registry.register(tool)
    let options = AgentOptions(FixtureModel())
    options.tools = registry
    options.maxSteps = 3
    options.allowedTools = ["write_note"]
    options.policy = PublicNotesPolicy()
    options.interruptOn = ["write_note"]
    options.onInterruptDecision = { _ in decision }
    return (try Agent(options), tool)
}

do {
    let (agent, tool) = try buildAgent(InterruptDecision(action: INTERRUPT_APPROVE))
    let result = try agent.run(Session(id: "hitl-approve"), "Write a note.")
    if result.output != "done" || tool.notes.count != 1 {
        fail("approve scenario failed: output=\(result.output) effects=\(tool.notes.count)")
    }
    print("approve: written; effects=1")
} catch {
    fail("approve scenario failed: \(error)")
}

do {
    let (agent, tool) = try buildAgent(InterruptDecision(
        action: INTERRUPT_EDIT,
        arguments: ["text": "hello", "visibility": "private"]
    ))
    do {
        _ = try agent.run(Session(id: "hitl-edit"), "Write a note.")
        fail("edited private note was not denied")
    } catch let error as PraxoError {
        if error.code != "AGENT_POLICY_DENIED" || !tool.notes.isEmpty {
            fail("edit scenario failed: code=\(error.code) effects=\(tool.notes.count)")
        }
    }
    print("edit: policy rejected; effects=0")
} catch let error as PraxoError {
    fail("edit scenario failed: code=\(error.code)")
} catch {
    fail("edit scenario failed: \(error)")
}
