import XCTest
@testable import PraxoCore

private final class RecordingTransport: ProviderTransport {
    var requests: [ProviderHTTPRequest] = []
    var response: ProviderHTTPResponse
    var called = false

    init(_ response: ProviderHTTPResponse) {
        self.response = response
    }

    func send(_ request: ProviderHTTPRequest) throws -> ProviderHTTPResponse {
        called = true
        requests.append(request)
        return response
    }
}

private final class FailingTransport: ProviderTransport {
    var called = false

    func send(_ request: ProviderHTTPRequest) throws -> ProviderHTTPResponse {
        called = true
        throw PraxoError("PROVIDER_HTTP", "unexpected transport call")
    }
}

final class OpenAICompatibleTests: XCTestCase {
    private let responseBody = """
    {"choices":[{"message":{"content":"done","tool_calls":[{"id":"call-1","type":"function","function":{"name":"echo","arguments":"{\\"text\\":\\"hi\\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":3,"completion_tokens":2}}
    """

    func testRequestAndResponseMapping() throws {
        let transport = RecordingTransport(ProviderHTTPResponse(statusCode: 200, body: responseBody))
        let config = OpenAICompatibleConfig(
            baseURL: "https://api.example.com/v1/",
            model: "test-model",
            apiKey: "secret"
        )
        let model = OpenAICompatibleModel(config, transport: transport)
        let request = Request(
            messages: [
                Message.text(Roles.user, "hi"),
                Message(role: Roles.assistant, content: "", toolCalls: [
                    ToolCall(id: "c1", name: "echo", arguments: ["text": "hi"]),
                ]),
                Message.tool("{}", toolID: "c1"),
            ],
            tools: [ToolSpec(name: "echo", description: "Echo", parameters: ["type": "object"])],
            toolChoice: "auto"
        )

        let response = try model.generate(request)

        XCTAssertEqual(response.message.content, "done")
        XCTAssertEqual(response.usage.inputTokens, 3)
        XCTAssertEqual(response.usage.outputTokens, 2)
        XCTAssertEqual(response.finishReason, "tool_calls")
        XCTAssertEqual(response.message.toolCalls.count, 1)
        XCTAssertEqual(response.message.toolCalls[0].id, "call-1")
        XCTAssertEqual(response.message.toolCalls[0].name, "echo")
        XCTAssertEqual(response.message.toolCalls[0].arguments["text"] as? String, "hi")

        XCTAssertEqual(transport.requests.count, 1)
        let http = transport.requests[0]
        XCTAssertEqual(http.method, "POST")
        XCTAssertEqual(http.url, "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(http.headers["Authorization"], "Bearer secret")
        XCTAssertEqual(http.headers["Content-Type"], "application/json")

        let payload = try Json.parse(http.body) as? [String: Any]
        XCTAssertEqual(payload?["model"] as? String, "test-model")
        XCTAssertEqual(payload?["tool_choice"] as? String, "auto")
        let messages = payload?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 3)
        XCTAssertEqual(messages?[1]["tool_calls"] != nil, true)
        XCTAssertEqual(messages?[2]["tool_call_id"] as? String, "c1")
        let tools = payload?["tools"] as? [[String: Any]]
        let function = tools?.first?["function"] as? [String: Any]
        XCTAssertEqual(function?["name"] as? String, "echo")
    }

    func testContentBlocksBecomeText() throws {
        let transport = RecordingTransport(ProviderHTTPResponse(
            statusCode: 200,
            body: "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}"
        ))
        let model = OpenAICompatibleModel(
            OpenAICompatibleConfig(baseURL: "https://example.com/v1", model: "m"),
            transport: transport
        )
        let request = Request(messages: [
            Message(role: Roles.user, content: "", contentBlocks: [
                ContentBlock(type: "text", text: "hello "),
                ContentBlock(type: "text", text: "world"),
            ]),
        ])
        _ = try model.generate(request)
        let payload = try Json.parse(transport.requests[0].body) as? [String: Any]
        let messages = payload?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.first?["content"] as? String, "hello world")
    }

    func testProviderHTTPError() {
        let transport = RecordingTransport(ProviderHTTPResponse(statusCode: 503, body: "down"))
        let model = OpenAICompatibleModel(
            OpenAICompatibleConfig(baseURL: "https://example.com/v1", model: "m"),
            transport: transport
        )
        XCTAssertThrowsError(try model.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "PROVIDER_HTTP")
        }
    }

    func testMissingBaseURLSkipsTransport() {
        let transport = FailingTransport()
        let model = OpenAICompatibleModel(
            OpenAICompatibleConfig(baseURL: "", model: "m"),
            transport: transport
        )
        XCTAssertThrowsError(try model.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "PROVIDER_HTTP")
        }
        XCTAssertFalse(transport.called)
    }

    func testInvalidToolArguments() {
        let body = "{\"choices\":[{\"message\":{\"tool_calls\":[{\"id\":\"c\",\"function\":{\"name\":\"x\",\"arguments\":\"{bad\"}}]}}]}"
        let transport = RecordingTransport(ProviderHTTPResponse(statusCode: 200, body: body))
        let model = OpenAICompatibleModel(
            OpenAICompatibleConfig(baseURL: "https://example.com/v1", model: "m"),
            transport: transport
        )
        XCTAssertThrowsError(try model.generate(Request())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "PROVIDER_RESPONSE")
        }
    }
}
