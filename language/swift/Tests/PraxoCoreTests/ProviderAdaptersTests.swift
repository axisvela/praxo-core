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
