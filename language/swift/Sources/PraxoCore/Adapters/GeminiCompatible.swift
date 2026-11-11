import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct GeminiConfig {
    public var baseURL: String
    public var model: String
    public var apiKey: String
    public var maxOutputTokens: Int
    public var timeout: TimeInterval

    public init(baseURL: String = "https://generativelanguage.googleapis.com",
                model: String = "", apiKey: String = "",
                maxOutputTokens: Int = 0, timeout: TimeInterval = 60) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.maxOutputTokens = maxOutputTokens
        self.timeout = timeout
    }
}

public final class GeminiModel: Model {
    public let config: GeminiConfig
    private let transport: ProviderTransport

    public init(_ config: GeminiConfig,
                transport: ProviderTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    public func generate(_ request: Request) throws -> Response {
        guard !config.apiKey.isEmpty else {
            throw PraxoError("MODEL_CONFIG", "gemini: API key is required")
        }
        guard !config.model.isEmpty else {
            throw PraxoError("MODEL_CONFIG", "gemini: model is required")
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
        let (system, contents) = buildContents(request.messages)
        var payload: [String: Any] = ["contents": contents]
        if let system = system {
            payload["system_instruction"] = system
        }
        if !request.tools.isEmpty {
            let declarations = request.tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters ?? ["type": "object", "properties": [:]],
                ] as [String: Any]
            }
            payload["tools"] = [["functionDeclarations": declarations]]
            payload["toolConfig"] = [
                "functionCallingConfig": ["mode": toolMode(request.toolChoice)],
            ]
        }
        if request.temperature != 0 || config.maxOutputTokens > 0 {
            payload["generationConfig"] = [
                "temperature": request.temperature,
                "maxOutputTokens": config.maxOutputTokens,
            ]
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
        let candidates = Json.array(root, "candidates")
        guard let candidate = candidates.first else {
            throw PraxoError("PROVIDER_RESPONSE", "gemini: empty response")
        }
        let content = Json.get(candidate, "content") ?? [String: Any]()
        var resultText = ""
        var calls: [ToolCall] = []
        for part in Json.array(content, "parts") {
            resultText += Json.string(part, "text") ?? ""
            if let callValue = Json.get(part, "functionCall") as? [String: Any] {
                calls.append(ToolCall(
                    id: "call-\(calls.count + 1)",
                    name: Json.string(callValue, "name") ?? "",
                    arguments: Json.get(callValue, "args") as? [String: Any] ?? [:]
                ))
            }
        }
        let usage = Json.get(root, "usageMetadata") ?? [String: Any]()
        return Response(
            message: Message(role: Roles.assistant, content: resultText, toolCalls: calls),
            usage: Usage(inputTokens: Json.int(usage, "promptTokenCount"),
                         outputTokens: Json.int(usage, "candidatesTokenCount"),
                         cachedTokens: Json.int(usage, "cachedContentTokenCount")),
            finishReason: Json.string(candidate, "finishReason")
        )
    }

    private func buildContents(_ messages: [Message]) -> ([String: Any]?, [[String: Any]]) {
        var systemParts: [[String: Any]] = []
        var contents: [[String: Any]] = []
        var toolParts: [[String: Any]] = []
        var names: [String: String] = [:]
        for message in messages {
            if message.role == Roles.system {
                if let content = message.content, !content.isEmpty {
                    systemParts.append(["text": content])
                }
                continue
            }
            if message.role == Roles.tool {
                let name = message.toolID.flatMap { names[$0] } ?? message.toolID ?? "tool"
                toolParts.append([
                    "functionResponse": [
                        "name": name.isEmpty ? "tool" : name,
                        "response": ["result": message.content ?? ""],
                    ],
                ])
                continue
            }
            flush(&contents, &toolParts)
            let parts = messageParts(message)
            if !parts.isEmpty {
                contents.append([
                    "role": message.role == Roles.assistant ? "model" : "user",
                    "parts": parts,
                ])
            }
            for call in message.toolCalls where !call.id.isEmpty && !call.name.isEmpty {
                names[call.id] = call.name
            }
        }
        flush(&contents, &toolParts)
        let system = systemParts.isEmpty ? nil : ["parts": systemParts]
        return (system, contents)
    }

    private func flush(_ contents: inout [[String: Any]], _ parts: inout [[String: Any]]) {
        if parts.isEmpty { return }
        contents.append(["role": Roles.user, "parts": parts])
        parts.removeAll()
    }

    private func messageParts(_ message: Message) -> [[String: Any]] {
        var parts: [[String: Any]] = []
        if let text = message.content, !text.isEmpty {
            parts.append(["text": text])
        }
        for block in message.contentBlocks where block.type == "text" {
            if let text = block.text, !text.isEmpty {
                parts.append(["text": text])
            }
        }
        for call in message.toolCalls {
            parts.append(["functionCall": ["name": call.name, "args": call.arguments]])
        }
        return parts
    }

    private func toolMode(_ choice: String?) -> String {
        switch choice {
        case "required": return "ANY"
        case "none": return "NONE"
        default: return "AUTO"
        }
    }

    private func endpoint() -> String {
        var base = config.baseURL
        while base.hasSuffix("/") { base.removeLast() }
        let encoded = config.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? config.model
        return base + "/v1beta/models/\(encoded):generateContent"
    }

    private func headers() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "x-goog-api-key": config.apiKey,
        ]
    }

    private func bounded(_ body: String) -> String {
        body.count > 512 ? String(body.prefix(512)) : body
    }
}
