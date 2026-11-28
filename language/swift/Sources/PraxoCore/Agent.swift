import Foundation

public protocol Model {
    func generate(_ request: Request) throws -> Response
}

public protocol StreamingModel: Model {
    func generateStream(_ request: Request, onDelta: (String) -> Void) throws -> Response
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
    public var allowedTools: [String] = []
    public var middleware: [ToolMiddleware] = []
    public var interruptOn: [String] = []
    public var onInterruptDecision: InterruptHandler?
    public var onInterrupt: InterruptApproval?
    public var onDelta: ((String) -> Void)?
    public var requirePolicy: Bool = false
    public var requireToolScope: Bool = false

    public init(_ model: Model) {
        self.model = model
        self.systemPrompt = ""
        self.maxSteps = 8
        self.maxTokens = 0
    }
}

private func validateAgentOptions(_ options: AgentOptions) throws {
    if options.requirePolicy && options.policy == nil {
        throw PraxoError("AGENT_INVALID_OPTIONS", "agent: require policy: policy is required")
    }
    if options.requireToolScope && options.allowedTools.isEmpty {
        throw PraxoError("AGENT_INVALID_OPTIONS", "agent: require tool scope: allowedTools must not be empty")
    }
}

public final class Agent {
    private let options: AgentOptions

    public init(_ options: AgentOptions) throws { try validateAgentOptions(options); self.options = options }

    public func run(_ session: Session, _ prompt: String) throws -> RunResult {
        let maxSteps = options.maxSteps > 0 ? options.maxSteps : 8
        let runID = "run-\(UUID().uuidString)"
        var messages = session.messages
        if !options.systemPrompt.isEmpty {
            messages.insert(Message.text(Roles.system, options.systemPrompt), at: 0)
        }
        messages.append(Message.text(Roles.user, prompt))
        var usage = Usage()
        emit("run.started", session.id, runID)
        do {
            for step in 1...maxSteps {
                try authorize(Action(kind: "model.generate", sessionID: session.id))
                if let budget = options.context {
                    let (compacted, ok) = budget.compact(messages)
                    if !ok { throw PraxoError("AGENT_CONTEXT_BUDGET", "context budget") }
                    messages = compacted
                }
                let specs = (options.tools?.specs() ?? []).filter {
                    options.allowedTools.isEmpty || options.allowedTools.contains($0.name)
                }
                let request = Request(messages: messages, tools: specs)
                let response: Response
                if let onDelta = options.onDelta {
                    guard let streaming = options.model as? StreamingModel else {
                        throw PraxoError("AGENT_STREAM", "agent: model does not support streaming")
                    }
                    response = try streaming.generateStream(request, onDelta: onDelta)
                } else {
                    response = try options.model.generate(request)
                }
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
            let praxo = error as? PraxoError
            emit("run.failed", session.id, runID, ["error": praxo?.message ?? "\(error)"])
            throw PraxoError(praxo?.code ?? "", praxo?.message ?? "\(error)")
        }
    }

    private func invokeTool(_ call: ToolCall, _ runID: String, _ sessionID: String) throws -> Message {
        let originalName = call.name
        let originalArguments = call.arguments
        if !toolAllowed(originalName) {
            throw PraxoError("AGENT_TOOL_NOT_ALLOWED", "agent: tool \(originalName) is not allowed")
        }
        try authorize(Action(kind: "tool.invoke", sessionID: sessionID,
                             toolName: originalName, arguments: originalArguments))
        guard let tools = options.tools else {
            throw PraxoError("TOOL_NOT_FOUND", "tool is not registered")
        }
        var active = call
        for middleware in options.middleware {
            if let beforeTool = middleware.beforeTool {
                active = try beforeTool(runID, sessionID, active)
            }
        }
        if !toolAllowed(active.name) {
            throw PraxoError("AGENT_TOOL_NOT_ALLOWED", "agent: tool \(active.name) is not allowed")
        }
        if let response = try applyInterrupt(&active, runID, sessionID) {
            return Message.tool(try Json.stringify(response), toolID: active.id)
        }
        if !toolAllowed(active.name) {
            throw PraxoError("AGENT_TOOL_NOT_ALLOWED", "agent: tool \(active.name) is not allowed")
        }
        if active.name != originalName || !Json.equals(originalArguments, active.arguments) {
            try authorize(Action(kind: "tool.invoke", sessionID: sessionID,
                                 toolName: active.name, arguments: active.arguments))
        }
        let tool = try tools.get(active.name)
        emit("tool.call", sessionID, runID, ["name": active.name, "arguments": active.arguments])
        let value = try tool.invoke(active.arguments)
        return Message.tool(try Json.stringify(value), toolID: active.id)
    }

    private func applyInterrupt(_ call: inout ToolCall, _ runID: String, _ sessionID: String) throws -> Any? {
        if !options.interruptOn.contains(call.name) {
            return nil
        }
        guard options.onInterruptDecision != nil || options.onInterrupt != nil else {
            throw PraxoError("AGENT_INTERRUPT_UNHANDLED",
                             "agent: approval handler not configured: \(call.name)")
        }
        emit("tool.interrupt", sessionID, runID, ["name": call.name, "arguments": call.arguments])
        let interrupt = Interrupt(runID: runID, sessionID: sessionID, call: call)
        if let handler = options.onInterruptDecision {
            let decision = try handler(interrupt)
            switch decision.action {
            case INTERRUPT_APPROVE:
                return nil
            case INTERRUPT_EDIT:
                guard let arguments = decision.arguments else {
                    throw PraxoError("AGENT_INTERRUPT_DECISION_INVALID",
                                     "agent: edit requires arguments")
                }
                call.arguments = arguments
                return nil
            case INTERRUPT_REJECT:
                throw PraxoError(
                    "AGENT_APPROVAL_DENIED",
                    "agent: tool call denied by approval: \(call.name): \(decision.reason ?? "")"
                )
            case INTERRUPT_RESPOND:
                return decision.response ?? ""
            default:
                throw PraxoError("AGENT_INTERRUPT_DECISION_INVALID",
                                 "agent: invalid interrupt decision: \(decision.action)")
            }
        }
        if let approval = options.onInterrupt {
            let approved = try approval(interrupt)
            if !approved {
                throw PraxoError("AGENT_APPROVAL_DENIED",
                                 "agent: tool call denied by approval: \(call.name)")
            }
            return nil
        }
        throw PraxoError("AGENT_INTERRUPT_UNHANDLED",
                         "agent: approval handler not configured: \(call.name)")
    }

    private func toolAllowed(_ name: String) -> Bool {
        options.allowedTools.isEmpty || options.allowedTools.contains(name)
    }

    private func authorize(_ action: Action) throws {
        guard let policy = options.policy else { return }
        let decision = policy.authorize(action)
        if !decision.allowed {
            throw PraxoError("AGENT_POLICY_DENIED",
                             "agent: \(action.kind) denied: \(decision.reason)")
        }
    }

    private func emit(_ type: String, _ sessionID: String, _ runID: String, _ data: [String: Any]? = nil) {
        options.events?.emit(Event(type: type, sessionID: sessionID, runID: runID, data: data))
    }
}
