import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AnthropicConfig {
    public var baseURL: String
    public var model: String
    public var apiKey: String
    public var version: String
    public var maxTokens: Int
    public var timeout: TimeInterval

    public init(baseURL: String = "https://api.anthropic.com", model: String = "",
                apiKey: String = "", version: String = "2023-06-01",
                maxTokens: Int = 1024, timeout: TimeInterval = 60) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.version = version
        self.maxTokens = maxTokens
        self.timeout = timeout
    }
}

public final class AnthropicModel: Model {
    public let config: AnthropicConfig
    private let transport: ProviderTransport

    public init(_ config: AnthropicConfig,
                transport: ProviderTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    public func generate(_ request: Request) throws -> Response {
        guard !config.apiKey.isEmpty else {
            throw PraxoError("MODEL_CONFIG", "anthropic: API key is required")
        }
        guard !config.model.isEmpty else {
            throw PraxoError("MODEL_CONFIG", "anthropic: model is required")
        }
        let httpRequest = ProviderHTTPRequest(
            method: "POST",
            url: endpoint(),
            headers: headers(),
            body: try Json.stringify(buildPayload(request)),
            timeout: config.timeout
        )
        let httpResponse = try transport.send(httpRequest)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PraxoError("PROVIDER_HTTP",
                             "provider returned HTTP \(httpResponse.statusCode): \(bounded(httpResponse.body))")
        }
        return try parseResponse(httpResponse.body)
    }

    public func buildPayload(_ request: Request) throws -> [String: Any] {
        let (system, messages) = try buildMessages(request.messages)
        var payload: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "messages": messages,
        ]
        if !system.isEmpty {
            payload["system"] = system
        }
        if !request.tools.isEmpty {
            payload["tools"] = request.tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.parameters ?? ["type": "object", "properties": [:]],
                ] as [String: Any]
            }
            if let choice = toolChoice(request.toolChoice) {
                payload["tool_choice"] = choice
            }
        }
        if request.temperature != 0 {
            payload["temperature"] = request.temperature
        }
        return payload
    }

    public func parseResponse(_ text: String) throws -> Response {
        let root: Any
        do {
            root = try Json.parse(text)
        } catch {
            throw PraxoError("PROVIDER_RESPONSE", "provider returned invalid JSON")
        }
        var content = ""
        var calls: [ToolCall] = []
        for block in Json.array(root, "content") {
            let kind = Json.string(block, "type") ?? ""
            if kind == "text" {
                content += Json.string(block, "text") ?? ""
            } else if kind == "tool_use" {
                calls.append(ToolCall(
                    id: Json.string(block, "id") ?? "",
                    name: Json.string(block, "name") ?? "",
                    arguments: Json.get(block, "input") as? [String: Any] ?? [:]
                ))
            }
        }
        let usage = Json.get(root, "usage") ?? [String: Any]()
        return Response(
            message: Message(role: Roles.assistant, content: content, toolCalls: calls),
            usage: Usage(inputTokens: Json.int(usage, "input_tokens"),
                         outputTokens: Json.int(usage, "output_tokens"),
                         cachedTokens: Json.int(usage, "cache_read_input_tokens")),
            finishReason: Json.string(root, "stop_reason")
        )
    }

    private func buildMessages(_ messages: [Message]) throws -> (String, [[String: Any]]) {
        var system: [String] = []
        var out: [[String: Any]] = []
        var results: [[String: Any]] = []
        for message in messages {
            if message.role == Roles.system {
                if let content = message.content, !content.isEmpty {
                    system.append(content)
                }
                continue
            }
            if message.role == Roles.tool {
                results.append([
                    "type": "tool_result",
                    "tool_use_id": message.toolID ?? "",
                    "content": message.content ?? "",
                ])
                continue
            }
            flush(&out, &results)
            let content = messageContent(message)
            if !content.isEmpty {
                out.append(["role": message.role, "content": content])
            }
        }
        flush(&out, &results)
        return (system.joined(separator: "\n\n"), out)
    }

    private func flush(_ out: inout [[String: Any]], _ results: inout [[String: Any]]) {
        if results.isEmpty { return }
        out.append(["role": Roles.user, "content": results])
        results.removeAll()
    }

    private func messageContent(_ message: Message) -> [[String: Any]] {
        var content: [[String: Any]] = []
        if let text = message.content, !text.isEmpty {
            content.append(["type": "text", "text": text])
        }
        for block in message.contentBlocks where block.type == "text" {
            if let text = block.text, !text.isEmpty {
                content.append(["type": "text", "text": text])
            }
        }
        for call in message.toolCalls {
            content.append([
                "type": "tool_use",
                "id": call.id,
                "name": call.name,
                "input": call.arguments,
            ])
        }
        return content
    }

    private func toolChoice(_ choice: String?) -> [String: Any]? {
        switch choice {
        case "auto": return ["type": "auto"]
        case "required": return ["type": "any"]
        case "none": return ["type": "none"]
        default: return nil
        }
    }

    private func endpoint() -> String {
        var base = config.baseURL
        while base.hasSuffix("/") { base.removeLast() }
        return base + "/v1/messages"
    }

    private func headers() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "x-api-key": config.apiKey,
            "anthropic-version": config.version,
        ]
    }

    private func bounded(_ body: String) -> String {
        body.count > 512 ? String(body.prefix(512)) : body
    }
}
