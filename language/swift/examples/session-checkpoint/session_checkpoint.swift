import PraxoCore

final class TurnModel: Model {
    func generate(_ request: Request) throws -> Response {
        Response(message: Message.assistant("turn \(request.messages.count)"))
    }
}

var session = Session(id: "session-1", messages: [
    Message.text(Roles.user, "first"),
    Message.text(Roles.assistant, "ack"),
])
let options = AgentOptions(TurnModel())
options.maxSteps = 2
let agent = Agent(options)

var result = try agent.run(session, "second")
precondition(result.output == "turn 3")
session.messages.append(Message.text(Roles.user, "second"))
session.messages.append(Message.assistant(result.output))

let allowlist = CheckpointAllowlist()
try allowlist.register("session")
let envelope = try allowlist.marshal("session", [
    "messages": session.messages.map { $0.wire() },
])
let restored = try allowlist.unmarshal(envelope) as? [String: Any]
let items = restored?["messages"] as? [[String: Any]] ?? []
session.messages = items.map {
    Message(
        role: $0["role"] as? String ?? "",
        content: $0["content"] as? String
    )
}

result = try agent.run(session, "third")
precondition(result.output == "turn 5")
print("restored messages: \(session.messages.count)")
print("output: \(result.output)")
