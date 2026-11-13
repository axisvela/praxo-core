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

@testset "PraxoCore OpenTelemetry sink" begin
    captured = Ref{Any}(nothing)
    transport = (endpoint, body, headers) -> begin
        captured[] = (
            endpoint = endpoint,
            body = Json.parse_json(body),
            headers = headers,
        )
        (status = 200, body = "")
    end
    sink = otel_sink(
        "https://otel.test/v1/traces";
        service_name = "praxo-test",
        allowed_data_keys = ["name"],
        transport = transport,
        clock = () -> (1700000000, 123456789),
    )
    event = Event(
        "tool.call",
        "s1",
        "run-123",
        Dict{String,Any}("name" => "echo", "secret" => "hidden"),
        nothing,
    )
    emit(sink, event)
    @test captured[].endpoint == "https://otel.test/v1/traces"
    @test captured[].headers["content-type"] == "application/json"
    resource_span = captured[].body["resourceSpans"][1]
    resource = resource_span["resource"]
    @test resource["attributes"][1]["value"]["stringValue"] == "praxo-test"
    span = resource_span["scopeSpans"][1]["spans"][1]
    @test span["name"] == "praxo.tool.call"
    @test length(span["traceId"]) == 32
    @test length(span["spanId"]) == 16
    @test span["startTimeUnixNano"] == span["endTimeUnixNano"]
    attributes = Dict(
        item["key"] => item["value"]["stringValue"]
        for item in span["attributes"]
    )
    @test attributes["praxo.event.type"] == "tool.call"
    @test attributes["praxo.session.id"] == "s1"
    @test attributes["praxo.run.id"] == "run-123"
    @test attributes["praxo.event.data.name"] == "echo"
    @test !haskey(attributes, "praxo.event.data.secret")
    first_span = span
    emit(sink, event)
    second_span = captured[].body["resourceSpans"][1]["scopeSpans"][1]["spans"][1]
    @test first_span["traceId"] == second_span["traceId"]
    @test first_span["spanId"] == second_span["spanId"]

    missing = try
        emit(otel_sink(""), event)
        nothing
    catch caught
        caught
    end
    @test missing isa PraxoError
    @test missing.code == "OTEL_URL"

    failing = otel_sink(
        "https://otel.test/v1/traces";
        transport = (endpoint, body, headers) -> (status = 503, body = "down"),
    )
    failure = try
        emit(failing, event)
        nothing
    catch caught
        caught
    end
    @test failure isa PraxoError
    @test failure.code == "OTEL_HTTP"
    @test occursin("503", failure.message)
    @test occursin("down", failure.message)

    long_failing = otel_sink(
        "https://otel.test/v1/traces";
        transport = (endpoint, body, headers) -> (status = 500, body = repeat("x", 600)),
    )
    long_failure = try
        emit(long_failing, event)
        nothing
    catch caught
        caught
    end
    @test long_failure isa PraxoError
    @test long_failure.code == "OTEL_HTTP"
    @test length(long_failure.message) < 600
end

@testset "PraxoCore retriever" begin
    retriever = func_retriever(
        (query, limit) -> [
            Document(
                "doc-1",
                string(query, ":", limit),
                Dict("source" => "test"),
                0.5,
            ),
        ],
    )
    documents = retrieve_documents(retriever, "hello", 3)
    @test length(documents) == 1
    @test documents[1].id == "doc-1"
    @test documents[1].content == "hello:3"
    @test documents[1].metadata["source"] == "test"
    @test documents[1].score == 0.5
    @test retrieve_documents(retriever.retrieve, "hello", 2)[1].content == "hello:2"
    @test retriever("hello", 1)[1].content == "hello:1"

    failure = try
        retrieve_documents(retriever, "hello", -1)
        nothing
    catch caught
        caught
    end
    @test failure isa PraxoError
    @test failure.code == "RETRIEVER_INVALID"
end

@testset "PraxoCore delegation" begin
    request = subagent_request("parent", "child", "look up", "fork")
    clock = () -> (1700000000, 123456789)
    runner = req -> subagent_result(agent_id = req.agent_id, output = "done")
    task = subagent_run(runner, request; clock = clock)
    @test task.status == "completed"
    @test task.parent_session_id == "parent"
    @test task.agent_id == "child"
    @test task.mode == "fork"
    @test task.output == "done"
    @test isempty(task.error)
    @test task.created_at == "2023-11-14T22:13:20.123456789Z"
    @test task.updated_at == "2023-11-14T22:13:20.123456789Z"

    failing = req -> throw(PraxoError("BOOM", "boom"))
    failed = subagent_run(failing, request; clock = clock)
    @test failed.status == "failed"
    @test isempty(failed.output)
    @test failed.error == "BOOM"

    generic = req -> Base.error("bad")
    generic_task = subagent_run(generic, request; clock = clock)
    @test generic_task.status == "failed"
    @test generic_task.error == "SUBAGENT_ERROR"

    invalid_parent = try
        subagent_run(runner, subagent_request("", "child", "look up"))
        nothing
    catch caught
        caught
    end
    @test invalid_parent isa PraxoError
    @test invalid_parent.code == "SUBAGENT_INVALID"

    invalid_agent = try
        subagent_run(runner, subagent_request("parent", "", "look up"))
        nothing
    catch caught
        caught
    end
    @test invalid_agent isa PraxoError
    @test invalid_agent.code == "SUBAGENT_INVALID"

    invalid_runner = try
        subagent_run(nothing, request)
        nothing
    catch caught
        caught
    end
    @test invalid_runner isa PraxoError
    @test invalid_runner.code == "SUBAGENT_INVALID"
end
