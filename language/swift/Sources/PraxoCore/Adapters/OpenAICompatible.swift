import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ProviderHTTPRequest {
    public var method: String
    public var url: String
    public var headers: [String: String]
    public var body: String
    public var timeout: TimeInterval

    public init(method: String, url: String, headers: [String: String] = [:],
                body: String = "", timeout: TimeInterval = 60) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct ProviderHTTPResponse {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol ProviderTransport {
    func send(_ request: ProviderHTTPRequest) throws -> ProviderHTTPResponse
}

public struct OpenAICompatibleConfig {
    public var baseURL: String
    public var model: String
    public var apiKey: String?
    public var timeout: TimeInterval

    public init(baseURL: String, model: String, apiKey: String? = nil,
                timeout: TimeInterval = 60) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.timeout = timeout
    }
}

public final class OpenAICompatibleModel: StreamingModel {
    public let config: OpenAICompatibleConfig
    private let transport: ProviderTransport

    public init(_ config: OpenAICompatibleConfig,
                transport: ProviderTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    public func generate(_ request: Request) throws -> Response {
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PraxoError("PROVIDER_HTTP", "provider base URL is required")
        }
        let payload = try buildPayload(request)
        let httpRequest = ProviderHTTPRequest(
            method: "POST",
            url: endpoint(),
            headers: headers(),
            body: try Json.stringify(payload),
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
        var payload: [String: Any] = [
            "model": config.model,
            "messages": try request.messages.map { try messagePayload($0) },
        ]
        if !request.tools.isEmpty {
            payload["tools"] = request.tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.parameters ?? ["type": "object"],
                    ],
                ] as [String: Any]
            }
        }
        if let toolChoice = request.toolChoice {
            payload["tool_choice"] = toolChoice
        }
        if let responseFormat = request.responseFormat {
            payload["response_format"] = responseFormat
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
        let choices = Json.array(root, "choices")
        guard let choice = choices.first else {
            throw PraxoError("PROVIDER_RESPONSE", "provider response has no choices")
        }
        let message = Json.get(choice, "message") ?? [String: Any]()
        var calls: [ToolCall] = []
        for item in Json.array(message, "tool_calls") {
            let function = Json.get(item, "function") ?? [String: Any]()
            let arguments = try parseArguments(Json.get(function, "arguments"))
            calls.append(ToolCall(
                id: Json.string(item, "id") ?? "",
                name: Json.string(function, "name") ?? "",
                arguments: arguments
            ))
        }
        let usage = Json.get(root, "usage") ?? [String: Any]()
        return Response(
            message: Message(role: Roles.assistant,
                             content: Json.string(message, "content"),
                             toolCalls: calls),
            usage: Usage(inputTokens: Json.int(usage, "prompt_tokens"),
                         outputTokens: Json.int(usage, "completion_tokens")),
            finishReason: Json.string(choice, "finish_reason")
        )
    }

    public func generateStream(_ request: Request,
                               onDelta: (String) -> Void) throws -> Response {
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PraxoError("PROVIDER_HTTP", "provider base URL is required")
        }
        var payload = try buildPayload(request)
        payload["stream"] = true
        var headers = headers()
        headers["Accept"] = "text/event-stream"
        let httpRequest = ProviderHTTPRequest(
            method: "POST",
            url: endpoint(),
            headers: headers,
            body: try Json.stringify(payload),
            timeout: config.timeout
        )
        let httpResponse = try transport.send(httpRequest)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PraxoError("PROVIDER_HTTP",
                             "provider returned HTTP \(httpResponse.statusCode): \(bounded(httpResponse.body))")
        }
        return try parseSseResponse(httpResponse.body, onDelta: onDelta)
    }

    public func parseSseResponse(_ text: String,
                                 onDelta: (String) -> Void) throws -> Response {
        var content = ""
        var inputTokens = 0
        var outputTokens = 0
        var finishReason: String?
        var done = false
        var calls: [Int: (id: String, name: String, arguments: String)] = [:]

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("data:") else { continue }
            let chunk = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            if chunk.isEmpty { continue }
            if chunk == "[DONE]" {
                done = true
                break
            }
            let event: Any
            do {
                event = try Json.parse(chunk)
            } catch {
                throw PraxoError("MODEL_STREAM", "invalid SSE packet")
            }
            if let usage = Json.get(event, "usage") as? [String: Any] {
                inputTokens = Json.int(usage, "prompt_tokens", fallback: inputTokens)
                outputTokens = Json.int(usage, "completion_tokens", fallback: outputTokens)
            }
            for choice in Json.array(event, "choices") {
                if let delta = Json.get(choice, "delta") as? [String: Any] {
                    if let piece = Json.string(delta, "content"), !piece.isEmpty {
                        content += piece
                        onDelta(piece)
                    }
                    for item in Json.array(delta, "tool_calls") {
                        let index = Json.int(item, "index", fallback: calls.count)
                        guard index >= 0 && index < 64 else {
                            throw PraxoError("PROVIDER_JSON", "tool call index out of range")
                        }
                        var slot = calls[index] ?? (id: "", name: "", arguments: "")
                        slot.id += Json.string(item, "id") ?? ""
                        if let function = Json.get(item, "function") as? [String: Any] {
                            slot.name += Json.string(function, "name") ?? ""
                            slot.arguments += Json.string(function, "arguments") ?? ""
                        }
                        calls[index] = slot
                    }
                }
                if let reason = Json.string(choice, "finish_reason") {
                    finishReason = reason
                    done = true
                }
            }
        }
        guard done else {
            throw PraxoError("MODEL_STREAM", "stream ended before completion")
        }
        var toolCalls: [ToolCall] = []
        for index in calls.keys.sorted() {
            guard let call = calls[index], !call.name.isEmpty else { continue }
            let arguments = try parseArguments(call.arguments)
            toolCalls.append(ToolCall(id: call.id, name: call.name, arguments: arguments))
        }
        return Response(
            message: Message(role: Roles.assistant, content: content, toolCalls: toolCalls),
            usage: Usage(inputTokens: inputTokens, outputTokens: outputTokens),
            finishReason: finishReason
        )
    }

    private func messagePayload(_ message: Message) throws -> [String: Any] {
        var content = message.content
        if (content == nil || content!.isEmpty) && !message.contentBlocks.isEmpty {
            content = message.contentBlocks
                .filter { $0.type == "text" && $0.text != nil }
                .map { $0.text! }
                .joined()
        }
        var out: [String: Any] = ["role": message.role]
        if let content = content { out["content"] = content }
        if message.role == Roles.assistant && !message.toolCalls.isEmpty {
            out["tool_calls"] = try message.toolCalls.map { call in
                [
                    "id": call.id,
                    "type": "function",
                    "function": [
                        "name": call.name,
                        "arguments": try Json.stringify(call.arguments),
                    ],
                ] as [String: Any]
            }
        }
        if message.role == Roles.tool, let toolID = message.toolID {
            out["tool_call_id"] = toolID
        }
        return out
    }

    private func parseArguments(_ raw: Any?) throws -> [String: Any] {
        if let text = raw as? String, !text.isEmpty {
            let decoded: Any
            do {
                decoded = try Json.parse(text)
            } catch {
                throw PraxoError("PROVIDER_RESPONSE", "tool arguments are not valid JSON")
            }
            guard let object = decoded as? [String: Any] else {
                throw PraxoError("PROVIDER_RESPONSE", "tool arguments must be an object")
            }
            return object
        }
        if let object = raw as? [String: Any] {
            return object
        }
        return [:]
    }

    private func endpoint() -> String {
        var base = config.baseURL
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base + "/chat/completions"
    }

    private func headers() -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
        if let apiKey = config.apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        return headers
    }

    private func bounded(_ body: String) -> String {
        body.count > 512 ? String(body.prefix(512)) : body
    }
}

public final class URLSessionTransport: ProviderTransport {
    public init() {}

    public func send(_ request: ProviderHTTPRequest) throws -> ProviderHTTPResponse {
        guard let url = URL(string: request.url) else {
            throw PraxoError("PROVIDER_HTTP", "invalid provider URL")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = request.timeout
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.httpBody = request.body.data(using: .utf8)

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<ProviderHTTPResponse, Error>?
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            defer { semaphore.signal() }
            if let error = error {
                result = .failure(error)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                result = .failure(PraxoError("PROVIDER_HTTP", "provider response is not HTTP"))
                return
            }
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            result = .success(ProviderHTTPResponse(statusCode: http.statusCode, body: body))
        }
        task.resume()
        semaphore.wait()
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        case nil:
            throw PraxoError("PROVIDER_HTTP", "provider request failed")
        }
    }
}
