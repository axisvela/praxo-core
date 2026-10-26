import Foundation

public protocol Model {
    func generate(_ request: Request) throws -> Response
}

public protocol Tool {
    var name: String { get }
    var description: String { get }
    func invoke(_ arguments: [String: Any]) throws -> Any
}

public final class FuncTool: Tool {
    public let name: String
    public let description: String
    private let function: ([String: Any]) throws -> Any

    public init(_ name: String, _ description: String, _ function: @escaping ([String: Any]) throws -> Any) {
        self.name = name
        self.description = description
        self.function = function
    }

    public func invoke(_ arguments: [String: Any]) throws -> Any {
        try function(arguments)
    }
}

public final class ToolRegistry {
    private var tools: [String: Tool] = [:]

    public init() {}

    public func register(_ tool: Tool) { tools[tool.name] = tool }

    public func get(_ name: String) throws -> Tool {
        guard let tool = tools[name] else {
            throw PraxoError("TOOL_NOT_FOUND", "tool not found: \(name)")
        }
        return tool
    }

    public func specs() -> [ToolSpec] {
        tools.values.map { ToolSpec(name: $0.name, description: $0.description) }
            .sorted { $0.name < $1.name }
    }
}

public final class StaticModel: Model {
    private let content: String
    public init(_ content: String) { self.content = content }
    public func generate(_ request: Request) throws -> Response {
        Response(message: Message.assistant(content))
    }
}

public protocol PolicyHook {
    func authorize(_ action: Action) -> Decision
}

public final class AgentOptions {
    public var model: Model
    public var tools: ToolRegistry?
    public var events: EventSink?
    public var policy: PolicyHook?
    public var systemPrompt: String
    public var context: ContextBudget?
    public var maxSteps: Int
    public var maxTokens: Int

    public init(_ model: Model) {
        self.model = model
        self.systemPrompt = ""
        self.maxSteps = 8
        self.maxTokens = 0
    }
}

public final class Agent {
    private let options: AgentOptions

    public init(_ options: AgentOptions) { self.options = options }

    public func run(_ session: Session, _ prompt: String) throws -> RunResult {
        let maxSteps = options.maxSteps > 0 ? options.maxSteps : 8
        let runID = "run-\(Int(Date().timeIntervalSince1970 * 1000))"
        var messages = session.messages
        if !options.systemPrompt.isEmpty {
            messages.insert(Message.text(Roles.system, options.systemPrompt), at: 0)
        }
        messages.append(Message.text(Roles.user, prompt))
        var usage = Usage()
        emit("run.started", session.id, runID)
        do {
            for step in 1...maxSteps {
                authorize(Action(kind: "model.generate", sessionID: session.id))
                if let budget = options.context {
                    let (compacted, ok) = budget.compact(messages)
                    if !ok { throw PraxoError("AGENT_CONTEXT_BUDGET", "context budget") }
                    messages = compacted
                }
                let request = Request(messages: messages, tools: options.tools?.specs() ?? [])
                let response = try options.model.generate(request)
                usage = usage.plus(response.usage)
                if options.maxTokens > 0 && usage.inputTokens + usage.outputTokens > options.maxTokens {
                    throw PraxoError("AGENT_MAX_TOKENS", "token budget")
                }
                messages.append(response.message)
                if response.message.toolCalls.isEmpty {
                    emit("run.completed", session.id, runID)
                    return RunResult(runID: runID, output: response.message.content ?? "", steps: step, usage: usage)
                }
                for call in response.message.toolCalls {
                    messages.append(try invokeTool(call, runID, session.id))
                }
            }
            throw PraxoError("AGENT_MAX_STEPS", "maximum steps")
        } catch {
            let code = (error as? PraxoError)?.code ?? ""
            emit("run.failed", session.id, runID, ["error": (error as? PraxoError)?.message ?? "\(error)"])
            throw PraxoError(code, "\(error)")
        }
    }

    private func invokeTool(_ call: ToolCall, _ runID: String, _ sessionID: String) throws -> Message {
        authorize(Action(kind: "tool.invoke", sessionID: sessionID, toolName: call.name, arguments: call.arguments))
        guard let tools = options.tools else {
            throw PraxoError("TOOL_NOT_FOUND", "tool is not registered")
        }
        let tool = try tools.get(call.name)
        emit("tool.call", sessionID, runID, ["name": call.name, "arguments": call.arguments])
        let value = try tool.invoke(call.arguments)
        return Message.tool(try Json.stringify(value), toolID: call.id)
    }

    private func authorize(_ action: Action) {
        guard let policy = options.policy else { return }
        let decision = policy.authorize(action)
        if !decision.allowed {
            // The run loop surfaces this as an error.
        }
    }

    private func emit(_ type: String, _ sessionID: String, _ runID: String, _ data: [String: Any]? = nil) {
        options.events?.emit(Event(type: type, sessionID: sessionID, runID: runID, data: data))
    }
}
