import Foundation

public enum Roles {
    public static let system = "system"
    public static let user = "user"
    public static let assistant = "assistant"
    public static let tool = "tool"
}

public let streamKinds = ["values", "updates", "messages", "tasks", "debug", "checkpoint"]

public struct ContentBlock {
    public var type: String
    public var text: String?
    public var imageURL: String?
    public var data: String?

    public init(type: String = "text", text: String? = nil, imageURL: String? = nil, data: String? = nil) {
        self.type = type
        self.text = text
        self.imageURL = imageURL
        self.data = data
    }

    public func wire() -> [String: Any] {
        var out: [String: Any] = ["type": type]
        if let text = text { out["text"] = text }
        if let imageURL = imageURL { out["image_url"] = imageURL }
        if let data = data { out["data"] = data }
        return out
    }
}

public struct ToolCall {
    public var id: String
    public var name: String
    public var arguments: [String: Any]

    public init(id: String = "", name: String = "", arguments: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    public func wire() -> [String: Any] {
        ["id": id, "name": name, "arguments": arguments]
    }
}

public struct Message {
    public var role: String
    public var content: String?
    public var contentBlocks: [ContentBlock]
    public var toolCalls: [ToolCall]
    public var toolID: String?

    public init(role: String, content: String? = nil, contentBlocks: [ContentBlock] = [],
                toolCalls: [ToolCall] = [], toolID: String? = nil) {
        self.role = role
        self.content = content
        self.contentBlocks = contentBlocks
        self.toolCalls = toolCalls
        self.toolID = toolID
    }

    public static func text(_ role: String, _ content: String) -> Message {
        Message(role: role, content: content)
    }

    public static func assistant(_ content: String, toolCalls: [ToolCall] = []) -> Message {
        Message(role: Roles.assistant, content: content, toolCalls: toolCalls)
    }

    public static func tool(_ content: String, toolID: String) -> Message {
        Message(role: Roles.tool, content: content, toolID: toolID)
    }

    public func wire() -> [String: Any] {
        var out: [String: Any] = ["role": role]
        if let content = content { out["content"] = content }
        if !contentBlocks.isEmpty { out["contentBlocks"] = contentBlocks.map { $0.wire() } }
        if !toolCalls.isEmpty { out["toolCalls"] = toolCalls.map { $0.wire() } }
        if let toolID = toolID { out["toolId"] = toolID }
        return out
    }
}

public struct ToolSpec {
    public var name: String
    public var description: String
    public var parameters: [String: Any]?
    public var risk: String?

    public init(name: String, description: String = "", parameters: [String: Any]? = nil, risk: String? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.risk = risk
    }
}

public struct Usage {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cachedTokens: Int

    public init(inputTokens: Int = 0, outputTokens: Int = 0, cachedTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedTokens = cachedTokens
    }

    public func plus(_ other: Usage) -> Usage {
        Usage(inputTokens: inputTokens + other.inputTokens,
              outputTokens: outputTokens + other.outputTokens,
              cachedTokens: cachedTokens + other.cachedTokens)
    }
}

public struct Request {
    public var messages: [Message]
    public var tools: [ToolSpec]
    public var toolChoice: String?
    public var responseFormat: [String: Any]?
    public var temperature: Double

    public init(messages: [Message] = [], tools: [ToolSpec] = [], toolChoice: String? = nil,
                responseFormat: [String: Any]? = nil, temperature: Double = 0) {
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.responseFormat = responseFormat
        self.temperature = temperature
    }
}

public struct Response {
    public var message: Message
    public var usage: Usage
    public var finishReason: String?

    public init(message: Message, usage: Usage = Usage(), finishReason: String? = nil) {
        self.message = message
        self.usage = usage
        self.finishReason = finishReason
    }
}

public struct Session {
    public var id: String
    public var messages: [Message]

    public init(id: String, messages: [Message] = []) {
        self.id = id
        self.messages = messages
    }
}

public struct RunResult {
    public var runID: String
    public var output: String
    public var steps: Int
    public var usage: Usage

    public init(runID: String = "", output: String = "", steps: Int = 0, usage: Usage = Usage()) {
        self.runID = runID
        self.output = output
        self.steps = steps
        self.usage = usage
    }
}

public final class MemoryRecord {
    public var id: String
    public var frame: String
    public var content: String
    public var createdAt: String?

    public init(id: String = "", frame: String = "", content: String = "", createdAt: String? = nil) {
        self.id = id
        self.frame = frame
        self.content = content
        self.createdAt = createdAt
    }
}

public struct PathGrant {
    public var root: String
    public var access: String

    public init(root: String, access: String = "read") {
        self.root = root
        self.access = access
    }
}

public struct Decision {
    public var allowed: Bool
    public var reason: String

    public init(allowed: Bool, reason: String = "") {
        self.allowed = allowed
        self.reason = reason
    }
}

public struct Action {
    public var kind: String
    public var sessionID: String
    public var toolName: String?
    public var arguments: [String: Any]?

    public init(kind: String, sessionID: String, toolName: String? = nil, arguments: [String: Any]? = nil) {
        self.kind = kind
        self.sessionID = sessionID
        self.toolName = toolName
        self.arguments = arguments
    }
}

public final class Event {
    public var type: String
    public var sessionID: String
    public var runID: String?
    public var data: [String: Any]?

    public init(type: String, sessionID: String, runID: String? = nil, data: [String: Any]? = nil) {
        self.type = type
        self.sessionID = sessionID
        self.runID = runID
        self.data = data
    }
}
