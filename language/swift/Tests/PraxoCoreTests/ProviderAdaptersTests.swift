import XCTest
@testable import PraxoCore

private final class ProviderRecordingTransport: ProviderTransport {
    var requests: [ProviderHTTPRequest] = []
    var response: ProviderHTTPResponse

    init(_ response: ProviderHTTPResponse) {
        self.response = response
    }

    func send(_ request: ProviderHTTPRequest) throws -> ProviderHTTPResponse {
        requests.append(request)
        return response
    }
}

final class ProviderAdaptersTests: XCTestCase {
    func testAnthropicRequestAndResponseMapping() throws {
        let body = """
        {"content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],"stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":6}}
        """
        let transport = ProviderRecordingTransport(ProviderHTTPResponse(statusCode: 200, body: body))
        let model = AnthropicModel(
            AnthropicConfig(model: "claude-test", apiKey: "secret"),
            transport: transport
        )
        let request = Request(
            messages: [
                Message.text(Roles.system, "be brief"),
                Message.text(Roles.user, "hi"),
                Message(role: Roles.assistant, content: "", toolCalls: [
                    ToolCall(id: "call-1", name: "echo", arguments: ["text": "hi"]),
                ]),
                Message.tool("{}", toolID: "call-1"),
            ],
            tools: [ToolSpec(name: "echo", description: "Echo")],
            toolChoice: "auto"
        )

        let response = try model.generate(request)

        XCTAssertEqual(response.message.content, "hello")
        XCTAssertEqual(response.usage.inputTokens, 5)
        XCTAssertEqual(response.usage.outputTokens, 6)
        XCTAssertEqual(response.message.toolCalls.first?.id, "tool-1")
        XCTAssertEqual(response.message.toolCalls.first?.name, "echo")

        let http = transport.requests[0]
        XCTAssertEqual(http.url, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(http.headers["x-api-key"], "secret")
        XCTAssertEqual(http.headers["anthropic-version"], "2023-06-01")
        let payload = try Json.parse(http.body) as? [String: Any]
        XCTAssertEqual(payload?["model"] as? String, "claude-test")
        XCTAssertEqual(payload?["system"] as? String, "be brief")
        let messages = payload?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 3)
        XCTAssertEqual(messages?[1]["role"] as? String, Roles.assistant)
        let assistantContent = messages?[1]["content"] as? [[String: Any]]
        XCTAssertEqual(assistantContent?.first?["type"] as? String, "tool_use")
        let toolContent = messages?[2]["content"] as? [[String: Any]]
        XCTAssertEqual(toolContent?.first?["tool_use_id"] as? String, "call-1")
        let tools = payload?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.first?["name"] as? String, "echo")
    }

    func testAnthropicStreamReassembly() throws {
        let body = """
        data: {"type":"message_start","message":{"usage":{"input_tokens":4,"cache_read_input_tokens":1}}}

        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}

        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"llo"}}

        data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call-1","name":"echo","input":{}}}

        data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"text\\":"}}

        data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\\"hi\\"}"}}

        data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":2}}

        data: {"type":"message_stop"}
        """
        let transport = ProviderRecordingTransport(ProviderHTTPResponse(statusCode: 200, body: body))
        let model = AnthropicModel(
            AnthropicConfig(model: "claude-test", apiKey: "secret"),
            transport: transport
        )
        let request = Request(messages: [Message.text(Roles.user, "hi")])
        var deltas: [String] = []
        let response = try model.generateStream(request, onDelta: { deltas.append($0) })

        XCTAssertEqual(deltas, ["he", "llo"])
        XCTAssertEqual(response.message.content, "hello")
        XCTAssertEqual(response.usage.inputTokens, 4)
        XCTAssertEqual(response.usage.outputTokens, 2)
        XCTAssertEqual(response.usage.cachedTokens, 1)
        XCTAssertEqual(response.finishReason, "tool_use")
        XCTAssertEqual(response.message.toolCalls.first?.id, "call-1")
        XCTAssertEqual(response.message.toolCalls.first?.name, "echo")
        XCTAssertEqual(response.message.toolCalls.first?.arguments["text"] as? String, "hi")

        let http = transport.requests[0]
        XCTAssertEqual(http.url, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(http.headers["Accept"], "text/event-stream")
        let payload = try Json.parse(http.body) as? [String: Any]
        XCTAssertEqual(payload?["stream"] as? Bool, true)
    }

    func testGeminiRequestAndResponseMapping() throws {
        let body = """
        {"candidates":[{"content":{"parts":[{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":5,"candidatesTokenCount":6}}
        """
        let transport = ProviderRecordingTransport(ProviderHTTPResponse(statusCode: 200, body: body))
        let model = GeminiModel(
            GeminiConfig(model: "gemini-test", apiKey: "secret"),
            transport: transport
        )
        let request = Request(
            messages: [
                Message.text(Roles.system, "be brief"),
                Message.text(Roles.user, "hi"),
                Message(role: Roles.assistant, content: "", toolCalls: [
                    ToolCall(id: "call-1", name: "echo", arguments: ["text": "hi"]),
                ]),
                Message.tool("{}", toolID: "call-1"),
            ],
            tools: [ToolSpec(name: "echo", description: "Echo")],
            toolChoice: "auto"
        )

        let response = try model.generate(request)

        XCTAssertEqual(response.message.content, "hello")
        XCTAssertEqual(response.usage.inputTokens, 5)
        XCTAssertEqual(response.usage.outputTokens, 6)
        XCTAssertEqual(response.message.toolCalls.first?.id, "call-1")
        XCTAssertEqual(response.message.toolCalls.first?.name, "echo")

        let http = transport.requests[0]
        XCTAssertEqual(http.url,
                       "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent")
        XCTAssertEqual(http.headers["x-goog-api-key"], "secret")
        let payload = try Json.parse(http.body) as? [String: Any]
        let contents = payload?["contents"] as? [[String: Any]]
        XCTAssertEqual(contents?.count, 3)
        XCTAssertEqual(contents?[1]["role"] as? String, "model")
        let parts = contents?[1]["parts"] as? [[String: Any]]
        XCTAssertEqual((parts?.first?["functionCall"] as? [String: Any])?["name"] as? String, "echo")
        let toolParts = contents?[2]["parts"] as? [[String: Any]]
        let functionResponse = toolParts?.first?["functionResponse"] as? [String: Any]
        XCTAssertEqual(functionResponse?["name"] as? String, "echo")
        let system = payload?["system_instruction"] as? [String: Any]
        XCTAssertEqual((system?["parts"] as? [[String: Any]])?.count, 1)
        let tools = payload?["tools"] as? [[String: Any]]
        XCTAssertEqual((tools?.first?["functionDeclarations"] as? [[String: Any]])?.count, 1)
    }

    func testGeminiStreamReassembly() throws {
        let body = """
        data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}

        data: {"candidates":[{"content":{"parts":[{"text":"llo"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":2,"cachedContentTokenCount":1}}
        """
        let transport = ProviderRecordingTransport(ProviderHTTPResponse(statusCode: 200, body: body))
        let model = GeminiModel(
            GeminiConfig(model: "gemini-test", apiKey: "gk"),
            transport: transport
        )
        let request = Request(messages: [Message.text(Roles.user, "hi")])
        var deltas: [String] = []
        let response = try model.generateStream(request, onDelta: { deltas.append($0) })

        XCTAssertEqual(deltas, ["he", "llo"])
        XCTAssertEqual(response.message.content, "hello")
        XCTAssertEqual(response.usage.inputTokens, 4)
        XCTAssertEqual(response.usage.outputTokens, 2)
        XCTAssertEqual(response.usage.cachedTokens, 1)
        XCTAssertEqual(response.finishReason, "STOP")
        XCTAssertEqual(response.message.toolCalls.first?.name, "echo")
        XCTAssertEqual(response.message.toolCalls.first?.arguments["text"] as? String, "hi")

        let http = transport.requests[0]
        XCTAssertTrue(http.url.contains(":streamGenerateContent?alt=sse"))
        XCTAssertEqual(http.headers["Accept"], "text/event-stream")
    }

    func testProcessPluginHost() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures/process_plugin.py")
        let config = PluginProcessConfig(
            pluginId: "com.example.echo",
            path: ProcessInfo.processInfo.environment["PYTHON"] ?? "python",
            args: [fixture.path],
            invokeTimeout: 2
        )
        let host = try PluginProcessHost(config)
        try host.start()
        XCTAssertTrue(host.isActive)
        let echoed = try host.invoke("tool.provider", "echo", payload: "{\"text\":\"hi\"}")
        XCTAssertEqual(echoed, "{\"text\":\"hi\"}")
        XCTAssertThrowsError(try host.invoke("tool.provider", "denied")) { error in
            XCTAssertEqual((error as? PluginProcessError)?.code, "CAPABILITY_DENIED")
        }
        host.stop()
        XCTAssertFalse(host.isActive)
    }

    func testMissingCredentialsFailBeforeTransport() {
        let transport = ProviderRecordingTransport(ProviderHTTPResponse(statusCode: 200, body: "{}"))
        let anthropic = AnthropicModel(AnthropicConfig(model: "m"), transport: transport)
        XCTAssertThrowsError(try anthropic.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "MODEL_CONFIG")
        }
        let gemini = GeminiModel(GeminiConfig(model: "m"), transport: transport)
        XCTAssertThrowsError(try gemini.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "MODEL_CONFIG")
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testProviderHTTPErrors() {
        let transport = ProviderRecordingTransport(ProviderHTTPResponse(statusCode: 503, body: "down"))
        let anthropic = AnthropicModel(AnthropicConfig(model: "m", apiKey: "k"), transport: transport)
        XCTAssertThrowsError(try anthropic.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "PROVIDER_HTTP")
        }
        let gemini = GeminiModel(GeminiConfig(model: "m", apiKey: "k"), transport: transport)
        XCTAssertThrowsError(try gemini.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "PROVIDER_HTTP")
        }
    }
}
