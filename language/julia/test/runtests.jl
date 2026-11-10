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
