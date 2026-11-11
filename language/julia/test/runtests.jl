using Test
using PraxoCore

@testset "PraxoCore wire" begin
    @testset "toolcall" begin
        call = ToolCallParser.parse_toolcall("{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}")
        @test call !== nothing
        @test call.name == "echo"
        @test call.input["text"] == "hi"
        @test ToolCallParser.strip_markup(
            "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world"
        ) == "helloworld"
    end

    @testset "jsonschema" begin
        schema = Json.parse_json(
            "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}"
        )
        errors = JsonSchema.validate(schema, Dict{String,Any}())
        @test length(errors) == 1
        @test errors[1].path == "\$.name"
        @test isempty(JsonSchema.validate(schema, Dict("name" => "ok")))
    end

    @testset "plugin" begin
        manifest = Plugin.parse_manifest(
            "{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}"
        )
        @test manifest.id == "com.example.echo"
    end
end

@testset "PraxoCore OpenAI-compatible adapter" begin
    captured_path = Ref{Any}(nothing)
    captured_payload = Ref{Any}(nothing)
    transport = (path, payload) -> begin
        captured_path[] = path
        captured_payload[] = payload
        Json.parse_json("""
        {"choices":[{"message":{"role":"assistant","content":"hello",
        "tool_calls":[{"id":"call-1","type":"function","function":
        {"name":"echo","arguments":"{\\"text\\":\\"hi\\"}"}}]},
        "finish_reason":"tool_calls"}],
        "usage":{"prompt_tokens":7,"completion_tokens":3}}
        """)
    end
    adapter = openai_compatible(
        "https://example.test/v1/", "test-model";
        api_key = "secret", transport = transport,
    )
    request = Request([
        Message(Roles.SYSTEM, "sys"),
        Message(Roles.USER, "hi"),
        PraxoCore.Models.message_assistant("", [
            ToolCall("call-1", "echo", Dict{String,Any}("text" => "hi")),
        ]),
        PraxoCore.Models.message_tool("{\"ok\":true}", "call-1"),
    ])
    request.tools = [ToolSpec("echo", "Echo")]
    request.tool_choice = "auto"
    result = generate(adapter, request)
    @test captured_path[] == "/chat/completions"
    payload = captured_payload[]
    @test payload["model"] == "test-model"
    @test payload["tool_choice"] == "auto"
    @test length(payload["messages"]) == 4
    assistant = payload["messages"][3]
    @test assistant["tool_calls"][1]["function"]["name"] == "echo"
    @test Json.parse_json(assistant["tool_calls"][1]["function"]["arguments"])["text"] == "hi"
    @test payload["messages"][4]["tool_call_id"] == "call-1"
    @test payload["tools"][1]["function"]["name"] == "echo"
    @test payload["tools"][1]["function"]["parameters"]["type"] == "object"
    @test result.message.content == "hello"
    @test result.message.tool_calls[1].id == "call-1"
    @test result.message.tool_calls[1].name == "echo"
    @test result.message.tool_calls[1].arguments["text"] == "hi"
    @test result.usage.input_tokens == 7
    @test result.usage.output_tokens == 3
    @test result.finish_reason == "tool_calls"

    invalid = (path, payload) -> Json.parse_json("""
        {"choices":[{"message":{"content":"","tool_calls":[{"id":"call-1",
        "function":{"name":"echo","arguments":"not json"}}]}}]}
        """)
    error = try
        generate(openai_compatible("https://example.test/v1", "m"; transport = invalid), request)
        nothing
    catch caught
        caught
    end
    @test error isa PraxoError
    @test error.code == "PROVIDER_JSON"

    error = try
        generate(openai_compatible("", "m"), request)
        nothing
    catch caught
        caught
    end
    @test error isa PraxoError
    @test error.code == "PROVIDER_HTTP"

    http_transport = (path, payload) ->
        throw(PraxoError("PROVIDER_HTTP", "provider returned HTTP 500"))
    error = try
        generate(
            openai_compatible("https://example.test/v1", "m"; transport = http_transport),
            request,
        )
        nothing
    catch caught
        caught
    end
    @test error isa PraxoError
    @test error.code == "PROVIDER_HTTP"
end

@testset "PraxoCore Anthropic adapter" begin
    captured_path = Ref{Any}(nothing)
    captured_payload = Ref{Any}(nothing)
    transport = (path, payload) -> begin
        captured_path[] = path
        captured_payload[] = payload
        Json.parse_json("""
        {"content":[{"type":"text","text":"hello"},
        {"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],
        "stop_reason":"end_turn",
        "usage":{"input_tokens":3,"output_tokens":4,"cache_read_input_tokens":2}}
        """)
    end
    adapter = anthropic("https://example.test/", "claude-test";
        api_key = "ak", transport = transport)
    request = Request([Message(Roles.SYSTEM, "be brief"), Message(Roles.USER, "hi")])
    request.tools = [ToolSpec("echo", "Echo")]
    request.tool_choice = "auto"
    result = generate(adapter, request)
    @test captured_path[] == "/v1/messages"
    @test captured_payload[]["system"] == "be brief"
    @test captured_payload[]["tools"][1]["input_schema"]["type"] == "object"
    @test result.message.content == "hello"
    @test result.message.tool_calls[1].id == "tool-1"
    @test result.message.tool_calls[1].arguments["text"] == "hi"
    @test result.usage.cached_tokens == 2
    @test result.finish_reason == "end_turn"
end

@testset "PraxoCore Gemini adapter" begin
    captured_path = Ref{Any}(nothing)
    captured_payload = Ref{Any}(nothing)
    transport = (path, payload) -> begin
        captured_path[] = path
        captured_payload[] = payload
        Json.parse_json("""
        {"candidates":[{"content":{"parts":[{"text":"hello"},
        {"functionCall":{"name":"echo","args":{"text":"hi"}}}]},
        "finishReason":"STOP"}],
        "usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":4}}
        """)
    end
    adapter = gemini("https://example.test/", "gemini-test";
        api_key = "gk", transport = transport)
    request = Request([Message(Roles.SYSTEM, "be brief"), Message(Roles.USER, "hi")])
    request.tools = [ToolSpec("echo", "Echo")]
    request.tool_choice = "auto"
    result = generate(adapter, request)
    @test occursin(":generateContent", captured_path[])
    @test captured_payload[]["system_instruction"]["parts"][1]["text"] == "be brief"
    @test captured_payload[]["toolConfig"]["functionCallingConfig"]["mode"] == "AUTO"
    @test result.message.content == "hello"
    @test result.message.tool_calls[1].name == "echo"
    @test result.usage.input_tokens == 3
    @test result.finish_reason == "STOP"
end

@testset "PraxoCore Harmovela sink" begin
    captured = Ref{Any}(nothing)
    transport = (path, body, headers) -> begin
        captured[] = (
            path = path,
            body = Json.parse_json(body),
            headers = headers,
        )
        (status = 204, body = "")
    end
    sink = harmovela_sink(
        "http://127.0.0.1:8790/aep/api/";
        transport = transport,
        clock = () -> (1700000000, 123456789),
    )
    event = Event(
        "tool.call",
        "s1",
        "run-123",
        Dict{String,Any}("name" => "echo"),
        nothing,
    )
    emit(sink, event)
    @test captured[].path == "/events"
    @test captured[].headers["content-type"] == "application/json"
    envelope = captured[].body
    @test envelope["spec_version"] == "0.2"
    @test envelope["id"] == "run-123-1700000000123456789"
    @test envelope["type"] == "tool.call"
    @test envelope["source"] == "praxo-core"
    @test envelope["created_at"] == "2023-11-14T22:13:20.123456789Z"
    @test envelope["payload"]["name"] == "echo"
    @test envelope["payload"]["session_id"] == "s1"
    @test envelope["payload"]["run_id"] == "run-123"

    custom_transport = (path, body, headers) -> begin
        captured[] = (
            path = path,
            body = Json.parse_json(body),
            headers = headers,
        )
        (status = 200, body = "")
    end
    custom = harmovela_sink(
        "http://127.0.0.1:8790/aep/api";
        source = "custom",
        spec_version = "0.3",
        transport = custom_transport,
        clock = () -> (1700000000, 0),
    )
    emit(custom, Event("run.started", "s2", nothing, nothing, nothing))
    envelope = captured[].body
    @test envelope["source"] == "custom"
    @test envelope["spec_version"] == "0.3"
    @test !haskey(envelope["payload"], "run_id")

    missing = try
        emit(harmovela_sink(""), Event("run.started", "s1", nothing, nothing, nothing))
        nothing
    catch caught
        caught
    end
    @test missing isa PraxoError
    @test missing.code == "HARMOVELA_URL"

    failing = harmovela_sink(
        "http://127.0.0.1:8790/aep/api";
        transport = (path, body, headers) -> (status = 500, body = "boom"),
        clock = () -> (1700000000, 0),
    )
    error = try
        emit(failing, Event("run.failed", "s1", nothing, nothing, nothing))
        nothing
    catch caught
        caught
    end
    @test error isa PraxoError
    @test error.code == "HARMOVELA_HTTP"
    @test occursin("500", error.message)
    @test occursin("boom", error.message)
end
