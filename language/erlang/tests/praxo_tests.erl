-module(praxo_tests).
-export([run/0]).

run() ->
    test_json(),
    test_toolcall(),
    test_jsonschema(),
    test_plugin(),
    test_memory(),
    test_checkpoint(),
    test_context(),
    test_pii(),
    test_paths(),
    test_stream(),
    test_event(),
    test_structured(),
    test_agent(),
    test_run_ids(),
    test_agent_tool(),
    test_tool_selection(),
    test_fallback_state(),
    test_custom_model(),
    test_custom_model_error(),
    test_agent_pii(),
    test_agent_structured(),
    test_agent_limits(),
    test_run_state_isolation(),
    test_agent_capacity(),
    test_agent_authorization(),
    test_agent_lifecycle(),
    test_agent_cancellation(),
    test_agent_stream(),
    test_agent_parallel(),
    test_agent_hitl(),
    test_sse(),
    test_openai_compatible(),
    test_anthropic(),
    test_gemini(),
    test_mcp(),
    test_harmovela(),
    io:format("erlang tests passed~n").


test_agent_cancellation() ->
    put(cancel, false),
    Model = fun(_Request) ->
        put(cancel, true),
        {ok, praxo_models:response(praxo_models:message_assistant(<<"done">>)),
            praxo_agent:failing_model()}
    end,
    Options = (praxo_agent:new_agent_options(Model))#{
        cancellation => fun() -> get(cancel) end,
        events => praxo_sink:new()
    },
    {error, <<"AGENT_CANCELLED">>, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"go">>
    ),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"run.failed">>],
        <<"erlang model cancellation events">>
    ),
    erase(cancel),
    put(tool_cancel, false),
    Tool = praxo_agent:new_tool(<<"wait">>, <<"wait">>, fun(_) ->
        put(tool_cancel, true),
        <<"ok">>
    end),
    ToolModel = fun(Request) ->
        case length(maps:get(messages, Request)) of
            1 ->
                {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [
                    praxo_models:tool_call(<<"c1">>, <<"wait">>, #{})
                ])), praxo_agent:failing_model()};
            _ ->
                {ok, praxo_models:response(praxo_models:message_assistant(<<"done">>)),
                    praxo_agent:failing_model()}
        end
    end,
    ToolOptions = (praxo_agent:new_agent_options(ToolModel))#{
        tools => [Tool],
        cancellation => fun() -> get(tool_cancel) end,
        events => praxo_sink:new()
    },
    {error, <<"AGENT_CANCELLED">>, ToolReturned} = praxo_agent:run_agent(
        ToolOptions,
        praxo_models:session(<<"s1">>),
        <<"go">>
    ),
    check(
        praxo_sink:kinds(maps:get(events, ToolReturned)) ==
            [<<"run.started">>, <<"tool.call">>, <<"run.failed">>],
        <<"erlang tool cancellation events">>
    ),
    erase(tool_cancel).

test_agent_stream() ->
    put(streams, []),
    Options = (praxo_agent:new_agent_options(praxo_agent:static_model(<<"done">>)))#{
        on_stream => fun(Part) ->
            Kind = maps:get(kind, Part),
            put(streams, get(streams) ++ [Kind]),
            case Kind of
                <<"messages">> -> throw(stream_failed);
                _ -> ok
            end
        end,
        events => praxo_sink:new()
    },
    {error, <<"STREAM_ERROR">>, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"go">>
    ),
    check(get(streams) == [<<"values">>, <<"messages">>], <<"erlang stream parts">>),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"run.failed">>],
        <<"erlang stream failure events">>
    ),
    erase(streams).

test_agent_parallel() ->
    Parent = self(),
    Release = atomics:new(1, []),
    Tool = fun(Name) ->
        praxo_agent:new_tool(Name, Name, fun(_) ->
            Parent ! {started, Name},
            wait_release(Release),
            Name
        end)
    end,
    Model = fun Loop(Request) ->
        case length(maps:get(messages, Request)) of
            1 ->
                Calls = [
                    praxo_models:tool_call(<<"c1">>, <<"a">>, #{}),
                    praxo_models:tool_call(<<"c2">>, <<"b">>, #{})
                ],
                {ok, praxo_models:response(
                    praxo_models:message_assistant(<<>>, Calls)
                ), Loop};
            _ ->
                Ids = [
                    maps:get(tool_id, Message)
                 || Message <- maps:get(messages, Request),
                    maps:get(role, Message) == <<"tool">>
                ],
                Parent ! {order, Ids},
                {ok, praxo_models:response(praxo_models:message_assistant(<<"done">>)),
                    Loop}
        end
    end,
    Options = (praxo_agent:new_agent_options(Model))#{
        tools => [Tool(<<"a">>), Tool(<<"b">>)],
        max_parallel_tools => 2
    },
    _Pid = spawn(fun() ->
        Result =
            try
                praxo_agent:run_agent(
                    Options,
                    praxo_models:session(<<"s1">>),
                    <<"go">>
                )
            catch
                Class:Reason:Stack -> {crashed, Class, Reason, Stack}
            end,
        Parent ! {agent_result, Result}
    end),
    Started = [receive_started(), receive_started()],
    check(
        lists:sort(Started) == [{started, <<"a">>}, {started, <<"b">>}],
        <<"erlang parallel starts">>
    ),
    atomics:put(Release, 1, 1),
    receive
        {agent_result, {ok, Result, _}} ->
            check(maps:get(output, Result) == <<"done">>, <<"erlang parallel result">>);
        {agent_result, Other} ->
            erlang:error({parallel_agent_failed, Other})
    after
        5000 -> erlang:error(parallel_result_timeout)
    end,
    receive
        {order, Ids} ->
            check(Ids == [<<"c1">>, <<"c2">>], <<"erlang parallel order">>)
    after
        5000 -> erlang:error(parallel_order_timeout)
    end.

receive_started() ->
    receive
        {started, Name} -> {started, Name}
    after
        2000 -> erlang:error(parallel_start_timeout)
    end.

wait_release(Ref) -> wait_release(Ref, 300).

wait_release(_Ref, 0) -> erlang:error(parallel_release_timeout);
wait_release(Ref, Attempts) ->
    case atomics:get(Ref, 1) of
        1 -> ok;
        _ ->
            timer:sleep(10),
            wait_release(Ref, Attempts - 1)
    end.

test_sse() ->
    check(
        praxo_sse:parse(
            <<"data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n"
              "data: [DONE]\n\n">>
        ) == {ok, <<"hi">>},
        <<"erlang sse complete">>
    ),
    check(
        praxo_sse:parse(
            <<"data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n">>
        ) == {error, <<"MODEL_STREAM">>},
        <<"erlang sse truncated">>
    ),
    check(
        praxo_sse:parse(<<"data: {\"choices\"\n\n">>) ==
            {error, <<"MODEL_STREAM">>},
        <<"erlang sse half packet">>
    ).

test_openai_compatible() ->
    Parent = self(),
    {ok, Data} = praxo_json:parse(<<
        "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"hello\","
        "\"tool_calls\":[{\"id\":\"call-1\",\"type\":\"function\",\"function\":"
        "{\"name\":\"echo\",\"arguments\":\"{\\\"text\\\":\\\"hi\\\"}\"}}]},"
        "\"finish_reason\":\"tool_calls\"}],"
        "\"usage\":{\"prompt_tokens\":7,\"completion_tokens\":3}}"
    >>),
    Transport = fun(Path, Payload) ->
        Parent ! {openai_path, Path},
        Parent ! {openai_payload, Payload},
        {ok, Data}
    end,
    Adapter = praxo_openai_compatible:new(
        <<"https://example.test/v1/">>,
        <<"test-model">>,
        #{api_key => <<"secret">>, transport => Transport}
    ),
    Request = (praxo_models:request(
        [
            praxo_models:message(<<"system">>, <<"sys">>),
            praxo_models:message(<<"user">>, <<"hi">>),
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"call-1">>, <<"echo">>, #{<<"text">> => <<"hi">>})
            ]),
            praxo_models:message_tool(<<"{\"ok\":true}">>, <<"call-1">>)
        ],
        [praxo_models:tool_spec(<<"echo">>, <<"Echo">>)]
    ))#{tool_choice => <<"auto">>},
    {ok, Response, _} = praxo_openai_compatible:generate(Adapter, Request),
    receive
        {openai_path, Path} ->
            check(Path == <<"/chat/completions">>, <<"openai path">>)
    after 1000 -> erlang:error(openai_path_timeout)
    end,
    receive
        {openai_payload, Payload} ->
            #{<<"model">> := <<"test-model">>,
              <<"messages">> := [System, User, Assistant, Tool],
              <<"tools">> := [ToolSpec],
              <<"tool_choice">> := <<"auto">>} = Payload,
            check(maps:get(<<"content">>, System) == <<"sys">>, <<"openai system">>),
            check(maps:get(<<"content">>, User) == <<"hi">>, <<"openai user">>),
            [Call] = maps:get(<<"tool_calls">>, Assistant),
            #{<<"id">> := <<"call-1">>,
              <<"type">> := <<"function">>,
              <<"function">> := Function} = Call,
            check(maps:get(<<"name">>, Function) == <<"echo">>, <<"openai call name">>),
            {ok, Arguments} = praxo_json:parse(maps:get(<<"arguments">>, Function)),
            check(
                praxo_json:equals(Arguments, #{<<"text">> => <<"hi">>}),
                <<"openai call arguments">>
            ),
            check(maps:get(<<"tool_call_id">>, Tool) == <<"call-1">>, <<"openai tool id">>),
            #{<<"type">> := <<"function">>, <<"function">> := ToolFunction} = ToolSpec,
            check(maps:get(<<"name">>, ToolFunction) == <<"echo">>, <<"openai tool name">>),
            check(
                maps:get(<<"parameters">>, ToolFunction) == #{<<"type">> => <<"object">>},
                <<"openai tool parameters">>
            )
    after 1000 -> erlang:error(openai_payload_timeout)
    end,
    Message = maps:get(message, Response),
    check(maps:get(content, Message) == <<"hello">>, <<"openai response content">>),
    [ResponseCall] = maps:get(tool_calls, Message),
    check(maps:get(id, ResponseCall) == <<"call-1">>, <<"openai response call id">>),
    check(maps:get(name, ResponseCall) == <<"echo">>, <<"openai response call name">>),
    check(
        maps:get(<<"text">>, maps:get(arguments, ResponseCall)) == <<"hi">>,
        <<"openai response arguments">>
    ),
    check(
        praxo_json:equals(maps:get(usage, Response), praxo_models:usage(7, 3)),
        <<"openai response usage">>
    ),
    check(maps:get(finish_reason, Response) == <<"tool_calls">>, <<"openai finish reason">>),
    Model = praxo_openai_compatible:model(
        praxo_openai_compatible:new(<<"https://example.test/v1">>, <<"test-model">>,
            #{transport => fun(_, _) -> {ok, Data} end})
    ),
    {ok, _, _} = Model(Request),
    {ok, Invalid} = praxo_json:parse(<<
        "{\"choices\":[{\"message\":{\"content\":\"\",\"tool_calls\":[{\"id\":\"call-1\","
        "\"function\":{\"name\":\"echo\",\"arguments\":\"not json\"}}]}}]}"
    >>),
    {error, <<"PROVIDER_JSON">>, _} = praxo_openai_compatible:generate(
        praxo_openai_compatible:new(<<"https://example.test/v1">>, <<"m">>,
            #{transport => fun(_, _) -> {ok, Invalid} end}),
        Request
    ),
    {error, <<"PROVIDER_HTTP">>, _} = praxo_openai_compatible:generate(
        praxo_openai_compatible:new(<<>>, <<"m">>),
        Request
    ),
    {error, <<"PROVIDER_HTTP">>, _} = praxo_openai_compatible:generate(
        praxo_openai_compatible:new(<<"https://example.test/v1">>, <<"m">>,
            #{transport => fun(_, _) -> {error, <<"PROVIDER_HTTP">>} end}),
        Request
    ).

test_anthropic() ->
    Parent = self(),
    {ok, Data} = praxo_json:parse(<<
        "{\"content\":[{\"type\":\"text\",\"text\":\"hello\"},"
        "{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\","
        "\"input\":{\"text\":\"hi\"}}],"
        "\"stop_reason\":\"end_turn\","
        "\"usage\":{\"input_tokens\":3,\"output_tokens\":4,"
        "\"cache_read_input_tokens\":2}}"
    >>),
    Transport = fun(Path, Payload) ->
        Parent ! {anthropic_path, Path},
        Parent ! {anthropic_payload, Payload},
        {ok, Data}
    end,
    Adapter = praxo_anthropic:new(
        <<"https://example.test">>,
        <<"claude-test">>,
        #{api_key => <<"ak">>, transport => Transport}
    ),
    Request = (praxo_models:request(
        [
            praxo_models:message(<<"system">>, <<"be brief">>),
            praxo_models:message(<<"user">>, <<"hi">>)
        ],
        [praxo_models:tool_spec(<<"echo">>, <<"Echo">>)]
    ))#{tool_choice => <<"auto">>},
    {ok, Response, _} = praxo_anthropic:generate(Adapter, Request),
    receive
        {anthropic_path, Path} -> check(Path == <<"/v1/messages">>, <<"anthropic path">>)
    after 1000 -> erlang:error(anthropic_path_timeout)
    end,
    receive
        {anthropic_payload, Payload} ->
            check(maps:get(<<"system">>, Payload) == <<"be brief">>, <<"anthropic system">>),
            [Tool] = maps:get(<<"tools">>, Payload),
            check(maps:get(<<"input_schema">>, Tool) == #{<<"type">> => <<"object">>},
                  <<"anthropic tools">>),
            check(maps:get(<<"tool_choice">>, Payload) == #{<<"type">> => <<"auto">>},
                  <<"anthropic tool choice">>)
    after 1000 -> erlang:error(anthropic_payload_timeout)
    end,
    Message = maps:get(message, Response),
    check(maps:get(content, Message) == <<"hello">>, <<"anthropic content">>),
    [Call] = maps:get(tool_calls, Message),
    check(maps:get(id, Call) == <<"tool-1">>, <<"anthropic call id">>),
    check(maps:get(<<"text">>, maps:get(arguments, Call)) == <<"hi">>,
          <<"anthropic arguments">>).

test_gemini() ->
    Parent = self(),
    {ok, Data} = praxo_json:parse(<<
        "{\"candidates\":[{\"content\":{\"parts\":["
        "{\"text\":\"hello\"},{\"functionCall\":{\"name\":\"echo\","
        "\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],"
        "\"usageMetadata\":{\"promptTokenCount\":3,\"candidatesTokenCount\":4}}"
    >>),
    Transport = fun(Path, Payload) ->
        Parent ! {gemini_path, Path},
        Parent ! {gemini_payload, Payload},
        {ok, Data}
    end,
    Adapter = praxo_gemini:new(
        <<"https://example.test">>,
        <<"gemini-test">>,
        #{api_key => <<"gk">>, transport => Transport}
    ),
    Request = (praxo_models:request(
        [
            praxo_models:message(<<"system">>, <<"be brief">>),
            praxo_models:message(<<"user">>, <<"hi">>)
        ],
        [praxo_models:tool_spec(<<"echo">>, <<"Echo">>)]
    ))#{tool_choice => <<"auto">>},
    {ok, Response, _} = praxo_gemini:generate(Adapter, Request),
    receive
        {gemini_path, Path} ->
            check(binary:match(Path, <<":generateContent">>) =/= nomatch, <<"gemini path">>)
    after 1000 -> erlang:error(gemini_path_timeout)
    end,
    receive
        {gemini_payload, Payload} ->
            System = maps:get(<<"system_instruction">>, Payload),
            [Part] = maps:get(<<"parts">>, System),
            check(maps:get(<<"text">>, Part) == <<"be brief">>, <<"gemini system">>),
            Config = maps:get(<<"toolConfig">>, Payload),
            Calling = maps:get(<<"functionCallingConfig">>, Config),
            check(maps:get(<<"mode">>, Calling) == <<"AUTO">>, <<"gemini tool mode">>)
    after 1000 -> erlang:error(gemini_payload_timeout)
    end,
    Message = maps:get(message, Response),
    check(maps:get(content, Message) == <<"hello">>, <<"gemini content">>),
    [Call] = maps:get(tool_calls, Message),
    check(maps:get(name, Call) == <<"echo">>, <<"gemini call name">>),
    check(maps:get(<<"text">>, maps:get(arguments, Call)) == <<"hi">>,
          <<"gemini arguments">>).

test_mcp() ->
    Transport = fun(Method, Params, _Timeout) ->
        case Method of
            <<"initialize">> ->
                {ok, #{<<"protocolVersion">> => <<"2024-11-05">>,
                       <<"serverInfo">> => #{<<"name">> => <<"fake">>}}};
            <<"tools/list">> ->
                case maps:get(<<"cursor">>, Params, undefined) of
                    undefined ->
                        {ok, #{<<"tools">> => [#{<<"name">> => <<"add">>}],
                               <<"nextCursor">> => <<"next">>}};
                    _ ->
                        {ok, #{<<"tools">> => [#{<<"name">> => <<"echo">>}]}}
                end;
            <<"tools/call">> ->
                case maps:get(<<"name">>, Params) of
                    <<"echo">> -> {ok, #{<<"structuredContent">> => #{<<"ok">> => true}}};
                    <<"text">> -> {ok, #{<<"content">> => [
                        #{<<"type">> => <<"text">>, <<"text">> => <<"hello">>}]}};
                    <<"fail">> -> {ok, #{<<"isError">> => true}};
                    _ -> {error, <<"MCP_TIMEOUT">>}
                end
        end
    end,
    Client = praxo_mcp:new(#{transport => Transport}),
    {ok, Started} = praxo_mcp:start(Client),
    check(maps:get(protocol_version, Started) == <<"2024-11-05">>,
          <<"mcp protocol version">>),
    {ok, Tools} = praxo_mcp:list_tools(Started),
    check([maps:get(<<"name">>, Tool) || Tool <- Tools] == [<<"add">>, <<"echo">>],
          <<"mcp paginated tools">>),
    {ok, Structured} = praxo_mcp:call_tool(Started, <<"echo">>, #{}),
    check(maps:get(<<"ok">>, Structured) == true, <<"mcp structured tool">>),
    {ok, Text} = praxo_mcp:call_tool(Started, <<"text">>, #{}),
    check(Text == <<"hello">>, <<"mcp text tool">>),
    {error, <<"MCP_TOOL_ERROR">>} = praxo_mcp:call_tool(Started, <<"fail">>, #{}),
    {error, <<"MCP_TIMEOUT">>} = praxo_mcp:call_tool(Started, <<"hang">>, #{}),
    ok.

test_harmovela() ->
    Parent = self(),
    Transport = fun(Path, Body, Headers) ->
        Parent ! {harmovela_path, Path},
        Parent ! {harmovela_body, Body},
        Parent ! {harmovela_headers, Headers},
        {ok, 200, <<>>}
    end,
    Sink = praxo_harmovela:new(
        <<"http://example.test/aep/api/">>,
        #{transport => Transport, clock => fun() -> {1700000000, 123456789} end}
    ),
    Event = praxo_models:event(
        <<"tool.call">>, <<"s1">>, <<"run-123">>, #{<<"name">> => <<"echo">>}
    ),
    ok = praxo_harmovela:emit(Sink, Event),
    receive
        {harmovela_path, Path} ->
            check(Path == <<"/events">>, <<"harmovela path">>)
    after 1000 -> erlang:error(harmovela_path_timeout)
    end,
    receive
        {harmovela_headers, Headers} ->
            check(
                lists:member({"content-type", "application/json"}, Headers),
                <<"harmovela content type">>
            )
    after 1000 -> erlang:error(harmovela_headers_timeout)
    end,
    receive
        {harmovela_body, Body} ->
            {ok, Envelope} = praxo_json:parse(Body),
            check(
                praxo_json:get_string(Envelope, <<"spec_version">>) == <<"0.2">>,
                <<"harmovela spec version">>
            ),
            check(
                praxo_json:get_string(Envelope, <<"id">>) ==
                    <<"run-123-1700000000123456789">>,
                <<"harmovela id">>
            ),
            check(
                praxo_json:get_string(Envelope, <<"type">>) == <<"tool.call">>,
                <<"harmovela type">>
            ),
            check(
                praxo_json:get_string(Envelope, <<"source">>) == <<"praxo-core">>,
                <<"harmovela source">>
            ),
            check(
                praxo_json:get_string(Envelope, <<"created_at">>) ==
                    <<"2023-11-14T22:13:20.123456789Z">>,
                <<"harmovela created at">>
            ),
            check(
                praxo_json:equals(
                    praxo_json:get_object(Envelope, <<"payload">>),
                    #{
                        <<"name">> => <<"echo">>,
                        <<"session_id">> => <<"s1">>,
                        <<"run_id">> => <<"run-123">>
                    }
                ),
                <<"harmovela payload">>
            )
    after 1000 -> erlang:error(harmovela_body_timeout)
    end,
    Failed = praxo_harmovela:new(
        <<"http://example.test/aep/api">>,
        #{
            transport => fun(_, _, _) -> {ok, 500, <<"boom">>} end,
            clock => fun() -> {1700000000, 123456789} end
        }
    ),
    check(
        praxo_harmovela:emit(Failed, Event) ==
            {error, {http_status, 500, <<"boom">>}},
        <<"harmovela non-2xx">>
    ),
    AgentSink = praxo_harmovela:new(
        <<"http://example.test/aep/api">>,
        #{transport => fun(_, _, _) -> {ok, 204, <<>>} end}
    ),
    Emitted = praxo_sink:emit(AgentSink, Event),
    check(
        praxo_sink:kinds(Emitted) == [<<"tool.call">>],
        <<"harmovela sink seam">>
    ).

tool_model() ->
    praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>, #{<<"text">> => <<"hi">>})
            ]),
            praxo_models:usage(0, 0)
        ),
        praxo_models:response(
            praxo_models:message_assistant(<<"done">>),
            praxo_models:usage(0, 0)
        )
    ]).

test_agent_hitl() ->
    Model = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>,
                                       #{<<"value">> => <<"original">>})
            ]),
            praxo_models:usage(0, 0)
        ),
        praxo_models:response(
            praxo_models:message_assistant(<<"done">>),
            praxo_models:usage(0, 0)
        )
    ]),
    Tool = praxo_agent:new_tool(<<"echo">>, <<"Echo">>),
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Tool],
        interrupt_on => [<<"echo">>],
        on_interrupt_decision => fun(_Interrupt) ->
            #{action => <<"approve">>}
        end
    },
    {ok, Result, Returned} = praxo_agent:run_agent(
        Options, praxo_models:session(<<"s1">>), <<"go">>
    ),
    check(maps:get(output, Result) == <<"done">>, <<"hitl approve output">>),
    check(maps:get(calls, hd(maps:get(tools, Returned))) == 1,
          <<"hitl approve calls">>),

    Parent = self(),
    Model2 = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>,
                                       #{<<"value">> => <<"original">>})
            ]),
            praxo_models:usage(0, 0)
        ),
        praxo_models:response(
            praxo_models:message_assistant(<<"done">>),
            praxo_models:usage(0, 0)
        )
    ]),
    Options2 = (praxo_agent:new_agent_options(Model2))#{
        tools => [Tool],
        policy => fun(Action) ->
            case maps:get(kind, Action) of
                <<"tool.invoke">> -> Parent ! hitl_auth;
                _ -> ok
            end,
            #{allowed => true, reason => <<>>}
        end,
        interrupt_on => [<<"echo">>],
        on_interrupt_decision => fun(_Interrupt) ->
            #{action => <<"edit">>,
              arguments => #{<<"value">> => <<"edited">>}}
        end
    },
    {ok, _, _} = praxo_agent:run_agent(
        Options2, praxo_models:session(<<"s1">>), <<"go">>
    ),
    receive hitl_auth -> ok after 0 -> error(missing_hitl_auth) end,
    receive hitl_auth -> ok after 0 -> error(missing_hitl_reauth) end,

    Model3 = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>,
                                       #{<<"value">> => <<"original">>})
            ]),
            praxo_models:usage(0, 0)
        )
    ]),
    Options3 = (praxo_agent:new_agent_options(Model3))#{
        tools => [Tool],
        interrupt_on => [<<"echo">>],
        on_interrupt_decision => fun(_Interrupt) ->
            #{action => <<"reject">>}
        end
    },
    {error, <<"AGENT_APPROVAL_DENIED">>, _} = praxo_agent:run_agent(
        Options3, praxo_models:session(<<"s1">>), <<"go">>
    ),

    Model4 = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>,
                                       #{<<"value">> => <<"original">>})
            ]),
            praxo_models:usage(0, 0)
        )
    ]),
    Options4 = (praxo_agent:new_agent_options(Model4))#{
        tools => [Tool],
        interrupt_on => [<<"echo">>]
    },
    {error, <<"AGENT_INTERRUPT_UNHANDLED">>, _} = praxo_agent:run_agent(
        Options4, praxo_models:session(<<"s1">>), <<"go">>
    ),

    Model5 = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>,
                                       #{<<"value">> => <<"original">>})
            ]),
            praxo_models:usage(0, 0)
        ),
        praxo_models:response(
            praxo_models:message_assistant(<<"done">>),
            praxo_models:usage(0, 0)
        )
    ]),
    Options5 = (praxo_agent:new_agent_options(Model5))#{
        tools => [Tool],
        events => praxo_sink:new(),
        interrupt_on => [<<"echo">>],
        on_interrupt_decision => fun(_Interrupt) ->
            #{action => <<"approve">>}
        end
    },
    {ok, _, Returned5} = praxo_agent:run_agent(
        Options5, praxo_models:session(<<"s1">>), <<"go">>
    ),
    check(
        length([K || K <- praxo_sink:kinds(maps:get(events, Returned5)),
                     K == <<"tool.interrupt">>]) == 1,
        <<"hitl event">>
    ).

test_agent_authorization() ->
    Parent = self(),
    put(actions, []),
    Options0 = praxo_agent:new_agent_options(tool_model()),
    Options = Options0#{
        tools => [praxo_agent:new_tool(<<"echo">>, <<"Echo">>,
            fun(Arguments) -> Parent ! {tool, Arguments}, Arguments end)],
        policy => fun(Action) -> put(actions, get(actions) ++ [Action]), #{allowed => true} end,
        middleware => [#{before_tool => fun(Call) ->
            Call#{arguments => #{<<"text">> => <<"mutated">>}}
        end}]
    },
    {ok, Result, _} = praxo_agent:run_agent(Options, praxo_models:session(<<"s1">>), <<"go">>),
    check(maps:get(output, Result) == <<"done">>, <<"erlang final arguments output">>),
    Actions = [Action || Action <- get(actions), maps:get(kind, Action) == <<"tool.invoke">>],
    check(length(Actions) == 2, <<"erlang final arguments reauthorized">>),
    receive {tool, Arguments} -> check(maps:get(<<"text">>, Arguments) == <<"mutated">>,
        <<"erlang final arguments effect">>)
    after 1000 -> erlang:error(<<"erlang final arguments effect missing">>) end,

    Options1 = praxo_agent:new_agent_options(tool_model()),
    Options2 = Options1#{
        tools => [
            praxo_agent:new_tool(<<"echo">>, <<"Echo">>),
            praxo_agent:new_tool(<<"other">>, <<"Other">>,
                fun(Arguments) -> Parent ! {other, Arguments}, Arguments end)
        ],
        allowed_tools => [<<"echo">>, <<"other">>],
        middleware => [#{before_tool => fun(Call) -> Call#{name => <<"other">>} end}]
    },
    {ok, _, _} = praxo_agent:run_agent(Options2, praxo_models:session(<<"s1">>), <<"go">>),
    receive {other, _} -> ok
    after 1000 -> erlang:error(<<"erlang final name effect missing">>) end,

    Options3 = praxo_agent:new_agent_options(tool_model()),
    Options4 = Options3#{
        tools => [praxo_agent:new_tool(<<"echo">>, <<"Echo">>)],
        allowed_tools => [<<"echo">>],
        middleware => [#{before_tool => fun(Call) -> Call#{name => <<"other">>} end}]
    },
    {error, <<"AGENT_TOOL_NOT_ALLOWED">>, _} =
        praxo_agent:run_agent(Options4, praxo_models:session(<<"s1">>), <<"go">>),

    put(actions, []),
    Options5 = praxo_agent:new_agent_options(tool_model()),
    Options6 = Options5#{
        tools => [praxo_agent:new_tool(<<"echo">>, <<"Echo">>)],
        policy => fun(Action) -> put(actions, get(actions) ++ [Action]), #{allowed => true} end,
        middleware => [#{}]
    },
    {ok, _, _} = praxo_agent:run_agent(Options6, praxo_models:session(<<"s1">>), <<"go">>),
    Unchanged = [Action || Action <- get(actions), maps:get(kind, Action) == <<"tool.invoke">>],
    check(length(Unchanged) == 1, <<"erlang unchanged single authorization">>),

    Parent2 = self(),
    Options7 = praxo_agent:new_agent_options(tool_model()),
    Options8 = Options7#{
        tools => [praxo_agent:new_tool(<<"echo">>, <<"Echo">>)],
        policy => fun(Action) ->
            case maps:get(kind, Action) of
                <<"tool.invoke">> -> #{allowed => false};
                _ -> #{allowed => true}
            end
        end,
        middleware => [#{before_tool => fun(Call) -> Parent2 ! middleware, Call end}]
    },
    {error, <<"AGENT_POLICY_DENIED">>, _} =
        praxo_agent:run_agent(Options8, praxo_models:session(<<"s1">>), <<"go">>),
    receive middleware -> erlang:error(<<"erlang initial denial ran middleware">>)
    after 100 -> ok end.

test_agent_lifecycle() ->
    Parent = self(),
    Options0 = praxo_agent:new_agent_options(praxo_agent:static_model(<<"done">>)),
    Options = Options0#{
        middleware => [
            #{before_run => fun(_) -> Parent ! first_before end,
              after_run => fun(_, _) -> Parent ! first_after end},
            #{before_run => fun(_) -> erlang:error(<<"STARTUP_FAILED">>) end,
              after_run => fun(_, _) -> Parent ! second_after end}
        ]
    },
    {error, <<"STARTUP_FAILED">>, _} =
        praxo_agent:run_agent(Options, praxo_models:session(<<"s1">>), <<"go">>),
    check(receive_messages() == [first_before, first_after, second_after],
        <<"erlang startup cleanup">>),

    Parent2 = self(),
    Options1 = praxo_agent:new_agent_options(praxo_agent:failing_model()),
    Options2 = Options1#{
        middleware => [
            #{after_run => fun(_, _) -> Parent2 ! first_after, erlang:error(<<"CLEANUP_FAILED">>) end},
            #{after_run => fun(_, _) -> Parent2 ! second_after end}
        ]
    },
    {error, <<"MODEL_ERROR">>, _} =
        praxo_agent:run_agent(Options2, praxo_models:session(<<"s1">>), <<"go">>),
    check(receive_messages() == [first_after, second_after], <<"erlang after-run continues">>),

    Parent3 = self(),
    Options3 = praxo_agent:new_agent_options(praxo_agent:static_model(<<"done">>)),
    Options4 = Options3#{
        middleware => [
            #{after_run => fun(_, _) -> Parent3 ! first_after, erlang:error(<<"CLEANUP_FAILED">>) end},
            #{after_run => fun(_, _) -> Parent3 ! second_after end}
        ]
    },
    {error, <<"CLEANUP_FAILED">>, _} =
        praxo_agent:run_agent(Options4, praxo_models:session(<<"s1">>), <<"go">>),
    check(receive_messages() == [first_after, second_after], <<"erlang cleanup continues">>).

receive_messages() -> receive_messages([]).
receive_messages(Acc) ->
    receive Message -> receive_messages(Acc ++ [Message])
    after 100 -> Acc end.


check(true, _Message) -> ok;
check(false, Message) -> erlang:error(Message).

test_json() ->
    Value = praxo_json:parse(<<"{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}">>),
    {ok, Parsed} = Value,
    check(praxo_json:get_string(Parsed, <<"name">>) == <<"echo">>, <<"json name">>),
    {ok, Other} = praxo_json:parse(<<"{\"input\":{\"text\":\"hi\"},\"name\":\"echo\"}">>),
    check(praxo_json:equals(Parsed, Other), <<"json object equality">>),
    {ok, RoundTrip} = praxo_json:parse(praxo_json:encode(Parsed)),
    check(praxo_json:equals(Parsed, RoundTrip), <<"json roundtrip">>).

test_toolcall() ->
    {ok, Call} = praxo_toolcall:parse_tool_call(
        <<"{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}">>
    ),
    check(maps:get(name, Call) == <<"echo">>, <<"json tool call">>),
    check(praxo_toolcall:parse_tool_call(<<"plain text">>) == error, <<"plain text">>),
    {ok, Xml} = praxo_toolcall:parse_tool_call(
        <<"<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>">>
    ),
    check(maps:get(name, Xml) == <<"echo">>, <<"xml tool call">>),
    {ok, Tag} = praxo_toolcall:parse_tool_call(
        <<"<echo.echo>{\"text\":\"hi\"}</echo.echo>">>
    ),
    check(maps:get(name, Tag) == <<"echo.echo">>, <<"tag tool call">>),
    {ok, Plain} = praxo_toolcall:parse_tool_call(<<"echo.run {\"text\":\"hi\"}">>),
    check(maps:get(name, Plain) == <<"echo.run">>, <<"plain tool call">>),
    Stripped = praxo_toolcall:strip_tool_call_markup(
        <<"hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world">>
    ),
    check(Stripped == <<"helloworld">>, <<"strip markup">>).

test_jsonschema() ->
    {ok, Schema} = praxo_json:parse(
        <<"{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}">>
    ),
    check(praxo_jsonschema:validate(Schema, #{<<"name">> => <<"ok">>}) == [], <<"schema valid">>),
    Errors = praxo_jsonschema:validate(Schema, #{}),
    check(length(Errors) == 1 andalso maps:get(path, hd(Errors)) == <<"$.name">>, <<"schema required">>),
    {ok, Pattern} = praxo_json:parse(<<"{\"type\":\"string\",\"pattern\":\"^a+$\"}">>),
    check(praxo_jsonschema:validate(Pattern, <<"aaa">>) == [], <<"schema pattern valid">>),
    check(length(praxo_jsonschema:validate(Pattern, <<"b">>)) == 1, <<"schema pattern invalid">>),
    {ok, Unicode} = praxo_json:parse(<<"{\"type\":\"string\",\"minLength\":2,\"maxLength\":2}">>),
    check(praxo_jsonschema:validate(Unicode, <<"你好"/utf8>>) == [], <<"schema unicode two">>),
    check(length(praxo_jsonschema:validate(Unicode, <<"你"/utf8>>)) == 1, <<"schema unicode one">>),
    {ok, Integer} = praxo_json:parse(<<"{\"type\":\"integer\"}">>),
    check(praxo_jsonschema:validate(Integer, 2) == [], <<"schema integer">>),
    check(length(praxo_jsonschema:validate(Integer, 2.5)) == 1, <<"schema integer fraction">>).

test_plugin() ->
    Raw = <<"{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[\"echo\"],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}">>,
    {ok, Manifest} = praxo_plugin:parse_manifest(Raw),
    check(maps:get(id, Manifest) == <<"com.example.echo">>, <<"plugin id">>),
    check(
        praxo_plugin:parse_manifest(<<Raw/binary, "{}">>) == {error, <<"PLUGIN_INVALID">>},
        <<"plugin trailing data">>
    ).

test_memory() ->
    Store0 = praxo_memory:new(),
    {Store1, _} = praxo_memory:put(
        Store0,
        <<"s1">>,
        praxo_models:memory_record(<<"m1">>, <<"event">>, <<"Alpha">>, <<"2026-01-01T00:00:00Z">>)
    ),
    {Store2, _} = praxo_memory:put(
        Store1,
        <<"s1">>,
        praxo_models:memory_record(<<"m2">>, <<"event">>, <<"beta">>, <<"2026-01-02T00:00:00Z">>)
    ),
    {Store3, _} = praxo_memory:put(
        Store2,
        <<"s1">>,
        praxo_models:memory_record(<<"m3">>, <<"decision">>, <<"ALPHABET">>, <<"2026-01-03T00:00:00Z">>)
    ),
    Records = praxo_memory:search(Store3, <<"s1">>, <<"alpha">>, 10),
    check([maps:get(id, R) || R <- Records] == [<<"m3">>, <<"m1">>], <<"memory ordering">>),
    check(
        [maps:get(id, R) || R <- praxo_memory:search(Store3, <<"s1">>, <<"alpha">>, 1)] ==
            [<<"m3">>],
        <<"memory limit">>
    ),
    check(praxo_memory:search(Store3, <<"s2">>, <<"alpha">>, 10) == [], <<"memory isolation">>).

test_checkpoint() ->
    Allow = praxo_checkpoint:register(praxo_checkpoint:new(), <<"spec.payload">>),
    {ok, Value} = praxo_json:parse(<<"{\"value\":\"x\"}">>),
    {ok, Data} = praxo_checkpoint:marshal(Allow, <<"spec.payload">>, Value),
    {ok, Decoded} = praxo_checkpoint:unmarshal(Allow, Data),
    check(praxo_json:equals(Decoded, Value), <<"checkpoint roundtrip">>),
    check(
        praxo_checkpoint:marshal(Allow, <<"spec.missing">>, null) ==
            {error, <<"CHECKPOINT_TYPE_NOT_ALLOWED">>},
        <<"checkpoint allowlist">>
    ).

test_context() ->
    Messages = [
        praxo_models:message(<<"system">>, <<"sys">>),
        praxo_models:message(<<"user">>, <<"message 0">>),
        praxo_models:message(<<"user">>, <<"message 1">>)
    ],
    check(praxo_runtime:estimate_tokens(Messages) == 16, <<"context estimate">>),
    {Output, Ok} = praxo_runtime:compact_context(praxo_models:context_budget(0, 0), Messages),
    check(Ok andalso length(Output) == 3, <<"context disabled">>).

test_pii() ->
    check(
        praxo_middleware:pii_redact(<<"email a@b.com">>) == <<"email [REDACTED:email]">>,
        <<"pii email">>
    ),
    check(
        praxo_middleware:pii_redact(<<"ssn 123-45-6789">>) == <<"ssn [REDACTED:ssn]">>,
        <<"pii ssn">>
    ),
    check(
        praxo_middleware:pii_redact(<<"call 415-555-2671">>) == <<"call [REDACTED:phone]">>,
        <<"pii phone">>
    ),
    check(
        praxo_middleware:pii_redact(<<"version 1.2.3">>) == <<"version 1.2.3">>,
        <<"pii phone boundary">>
    ).

test_paths() ->
    Checker = praxo_runtime:path_checker([praxo_models:path_grant(<<"allowed">>, <<"read">>)]),
    lists:foreach(
        fun(Path) ->
            check(
                not praxo_runtime:path_allowed(Checker, Path, <<"read">>),
                <<"relative traversal: ", Path/binary>>
            )
        end,
        [
            <<"../allowed/secret">>,
            <<"../../allowed/secret">>,
            <<"x/../../allowed/secret">>,
            <<"..\\allowed\\secret">>
        ]
    ),
    check(
        praxo_runtime:path_allowed(Checker, <<"allowed/sub/../secret">>, <<"read">>),
        <<"relative path within grant">>
    ),
    check(
        praxo_runtime:normalize_path(<<"../../a/../b">>) == <<"../../b">>,
        <<"leading parent segments">>
    ),
    check(
        praxo_runtime:normalize_path(<<"/../../allowed">>) == <<"/allowed">>,
        <<"absolute root traversal">>
    ),
    check(
        praxo_runtime:normalize_path(<<"C:../allowed">>) =/=
            praxo_runtime:normalize_path(<<"C:/allowed">>),
        <<"drive relative traversal">>
    ),
    Parent = praxo_runtime:path_checker([praxo_models:path_grant(<<"../allowed">>, <<"read">>)]),
    check(
        praxo_runtime:path_allowed(Parent, <<"../allowed/secret">>, <<"read">>),
        <<"relative parent grant">>
    ),
    check(
        not praxo_runtime:path_allowed(Parent, <<"allowed/secret">>, <<"read">>),
        <<"relative parent grant isolation">>
    ).

test_stream() ->
    check(
        praxo_runtime:stream_kinds() ==
            [<<"values">>, <<"updates">>, <<"messages">>, <<"tasks">>, <<"debug">>, <<"checkpoint">>],
        <<"stream kinds">>
    ).

test_event() ->
    Sink0 = praxo_sink:new(),
    Sink1 = praxo_sink:emit(Sink0, praxo_models:event(<<"a">>, <<"s1">>)),
    Sink2 = praxo_sink:emit(Sink1, praxo_models:event(<<"b">>, <<"s1">>)),
    check(praxo_sink:kinds(Sink2) == [<<"a">>, <<"b">>], <<"sink record">>),
    Filtered0 = praxo_sink:filter(praxo_sink:new(), [<<"b">>]),
    Filtered1 = praxo_sink:emit(Filtered0, praxo_models:event(<<"a">>, <<"s1">>)),
    Filtered2 = praxo_sink:emit(Filtered1, praxo_models:event(<<"b">>, <<"s1">>)),
    check(praxo_sink:kinds(Filtered2) == [<<"b">>], <<"sink filter">>),
    Multi = praxo_sink:multi([praxo_sink:new(), praxo_sink:new()]),
    Multi1 = praxo_sink:emit(Multi, praxo_models:event(<<"a">>, <<"s1">>)),
    check(praxo_sink:kinds(Multi1) == [[<<"a">>], [<<"a">>]], <<"sink multi">>).

test_structured() ->
    Schema = #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"name">>],
        <<"properties">> => #{<<"name">> => #{<<"type">> => <<"string">>}}
    },
    Config = praxo_middleware:structured_output(
        Schema,
        1,
        fun(_) -> {ok, <<"{\"name\":\"fixed\"}">>} end
    ),
    check(
        praxo_middleware:apply_structured(Config, <<"bad">>) ==
            {ok, <<"{\"name\":\"fixed\"}">>},
        <<"structured repair">>
    ),
    NoRepair = praxo_middleware:structured_output(Schema, 0),
    check(
        praxo_middleware:apply_structured(NoRepair, <<"bad">>) ==
            {error, <<"AGENT_STRUCTURED_OUTPUT">>},
        <<"structured failure">>
    ).

test_agent() ->
    Model = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<"hello">>),
            praxo_models:usage(0, 0)
        )
    ]),
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{events => praxo_sink:new()},
    {ok, Result, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"hello">>
    ),
    check(maps:get(output, Result) == <<"hello">>, <<"agent output">>),
    check(maps:get(steps, Result) == 1, <<"agent steps">>),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"run.completed">>],
        <<"agent events">>
    ).

test_run_ids() ->
    Model = praxo_agent:static_model(<<"ok">>),
    {ok, First, _} = praxo_agent:run_agent(
        praxo_agent:new_agent_options(Model),
        praxo_models:session(<<"s1">>),
        <<"hi">>
    ),
    {ok, Second, _} = praxo_agent:run_agent(
        praxo_agent:new_agent_options(Model),
        praxo_models:session(<<"s1">>),
        <<"hi">>
    ),
    check(maps:get(run_id, First) =/= maps:get(run_id, Second), <<"run ids distinct">>).

test_agent_tool() ->
    Model = praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>, #{<<"text">> => <<"hi">>})
            ]),
            praxo_models:usage(0, 0)
        ),
        praxo_models:response(
            praxo_models:message_assistant(<<"done">>),
            praxo_models:usage(0, 0)
        )
    ]),
    Tool = praxo_agent:new_tool(<<"echo">>, <<"Echo">>),
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{tools => [Tool], events => praxo_sink:new()},
    {ok, Result, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"use">>
    ),
    check(maps:get(output, Result) == <<"done">>, <<"agent tool output">>),
    check(maps:get(calls, hd(maps:get(tools, Returned))) == 1, <<"agent tool calls">>),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"tool.call">>, <<"run.completed">>],
        <<"agent tool events">>
    ).

test_tool_selection() ->
    Parent = self(),
    Secret = praxo_agent:new_tool(<<"secret">>, <<"Secret">>, fun(_) -> Parent ! invoked, null end),
    Echo = praxo_agent:new_tool(<<"echo">>, <<"Echo">>),
    Model = fun Loop(Request) ->
        Parent ! {specs, [maps:get(name, Tool) || Tool <- maps:get(tools, Request)]},
        case length(maps:get(messages, Request)) of
            1 ->
                {ok, praxo_models:response(
                    praxo_models:message_assistant(<<>>, [
                        praxo_models:tool_call(<<"c1">>, <<"echo">>, #{})
                    ])
                ), Loop};
            _ ->
                {ok, praxo_models:response(praxo_models:message_assistant(<<"done">>)), Loop}
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Echo, Secret],
        tool_selection => praxo_middleware:tool_selection([<<"echo">>])
    },
    {ok, Result, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"use">>
    ),
    check(maps:get(output, Result) == <<"done">>, <<"selected tool output">>),
    check(maps:get(calls, hd(maps:get(tools, Returned))) == 1, <<"selected tool called">>),
    receive {specs, Names1} -> check(Names1 == [<<"echo">>], <<"selected specs">>) end,
    receive {specs, Names2} -> check(Names2 == [<<"echo">>], <<"selected specs step 2">>) end.

test_fallback_state() ->
    Steps = [
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(<<"c1">>, <<"echo">>, #{})
            ])
        ),
        praxo_models:response(praxo_models:message_assistant(<<"done">>))
    ],
    Models = [
        praxo_agent:fallback_model(
            praxo_agent:scripted_model(Steps),
            praxo_agent:failing_model()
        ),
        praxo_agent:fallback_model(
            praxo_agent:failing_model(),
            praxo_agent:scripted_model(Steps)
        )
    ],
    lists:foreach(
        fun(Model) ->
            Options0 = praxo_agent:new_agent_options(Model),
            Options = Options0#{tools => [praxo_agent:new_tool(<<"echo">>, <<"Echo">>)]},
            {ok, Result, Returned} = praxo_agent:run_agent(
                Options,
                praxo_models:session(<<"s1">>),
                <<"use">>
            ),
            check(maps:get(output, Result) == <<"done">>, <<"fallback output">>),
            check(maps:get(steps, Result) == 2, <<"fallback steps">>),
            Child =
                case maps:get(mode, Model) of
                    fallback ->
                        case maps:get(mode, maps:get(primary, Model)) of
                            scripted -> maps:get(primary, maps:get(model, Returned));
                            _ -> maps:get(fallback, maps:get(model, Returned))
                        end
                end,
            check(maps:get(index, Child) == 2, <<"fallback child state">>)
        end,
        Models
    ),
    Nested = praxo_agent:fallback_model(
        praxo_agent:scripted_model([]),
        praxo_agent:scripted_model([])
    ),
    Model = praxo_agent:fallback_model(Nested, undefined),
    {error, <<"MODEL_ERROR">>, Updated} = praxo_agent:generate(
        Model,
        praxo_models:request([])
    ),
    check(maps:get(primary, Updated) == Nested, <<"nested failure state">>).

test_custom_model() ->
    Model = fun Loop(Request) ->
        check(
            [maps:get(name, Tool) || Tool <- maps:get(tools, Request)] == [<<"echo">>],
            <<"custom model tool specs">>
        ),
        case maps:get(messages, Request) of
            [
                #{role := <<"system">>, content := <<"system">>},
                #{role := <<"user">>, content := <<"use">>}
            ] ->
                {ok, praxo_models:response(
                    praxo_models:message_assistant(<<>>, [
                        praxo_models:tool_call(<<"c1">>, <<"echo">>, #{<<"text">> => <<"hi">>})
                    ]),
                    praxo_models:usage(1, 2)
                ), Loop};
            [
                #{role := <<"system">>},
                #{role := <<"user">>},
                #{role := <<"assistant">>},
                #{role := <<"tool">>, tool_id := <<"c1">>, content := Content}
            ] ->
                {ok, Parsed} = praxo_json:parse(Content),
                check(praxo_json:equals(Parsed, #{<<"text">> => <<"hi">>}), <<"tool result">>),
                {ok, praxo_models:response(
                    praxo_models:message_assistant(<<"done">>),
                    praxo_models:usage(3, 4)
                ), Loop}
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [praxo_agent:new_tool(<<"echo">>, <<"Echo">>)],
        system_prompt => <<"system">>,
        events => praxo_sink:new()
    },
    {ok, Result, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"use">>
    ),
    check(maps:get(output, Result) == <<"done">>, <<"custom model output">>),
    check(maps:get(steps, Result) == 2, <<"custom model steps">>),
    check(
        praxo_json:equals(maps:get(usage, Result), praxo_models:usage(4, 6)),
        <<"custom model usage">>
    ),
    check(maps:get(calls, hd(maps:get(tools, Returned))) == 1, <<"custom tool call">>),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"tool.call">>, <<"run.completed">>],
        <<"custom model events">>
    ).

test_custom_model_error() ->
    Model = fun(_) -> {error, <<"PROVIDER_ERROR">>, failed_model} end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{events => praxo_sink:new()},
    {error, <<"PROVIDER_ERROR">>, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"use">>
    ),
    check(maps:get(model, Returned) == failed_model, <<"custom model retained">>),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"run.failed">>],
        <<"custom model failure event">>
    ),
    Fallback = praxo_agent:fallback_model(Model, praxo_agent:static_model(<<"recovered">>)),
    {ok, Result, _} = praxo_agent:run_agent(
        praxo_agent:new_agent_options(Fallback),
        praxo_models:session(<<"s1">>),
        <<"use">>
    ),
    check(maps:get(output, Result) == <<"recovered">>, <<"custom model fallback">>).

test_agent_pii() ->
    Parent = self(),
    Tool = praxo_agent:new_tool(<<"echo">>, <<"Echo">>, fun(Arguments) ->
        Parent ! {arguments, Arguments},
        #{<<"nested">> => [<<"a@b.com">>, #{<<"ssn">> => <<"123-45-6789">>}]}
    end),
    Model = fun Loop(Request) ->
        Parent ! {request, Request},
        case length(maps:get(messages, Request)) of
            3 ->
                {ok, praxo_models:response(
                    praxo_models:message_assistant(<<"a@b.com">>, [
                        praxo_models:tool_call(<<"c">>, <<"echo">>, #{<<"email">> => <<"a@b.com">>})
                    ])
                ), Loop};
            _ ->
                {ok, praxo_models:response(praxo_models:message_assistant(<<"a@b.com">>)), Loop}
        end
    end,
    History = (praxo_models:message(<<"user">>, <<"a@b.com">>))#{
        content_blocks => [praxo_models:content_block(<<"text">>, <<"123-45-6789">>)]
    },
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Tool],
        system_prompt => <<"a@b.com">>,
        pii => true
    },
    {ok, Result, _} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>, [History]),
        <<"a@b.com">>
    ),
    check(maps:get(output, Result) == <<"a@b.com">>, <<"pii final output">>),
    receive
        {request, FirstRequest} ->
            [System, Past, Prompt] = maps:get(messages, FirstRequest),
            check(maps:get(content, System) == <<"[REDACTED:email]">>, <<"pii system">>),
            check(maps:get(content, Past) == <<"[REDACTED:email]">>, <<"pii history">>),
            check(maps:get(content, Prompt) == <<"[REDACTED:email]">>, <<"pii prompt">>),
            [Block] = maps:get(content_blocks, Past),
            check(maps:get(text, Block) == <<"[REDACTED:ssn]">>, <<"pii block">>)
    after 0 -> erlang:error(<<"missing pii request">>) end,
    receive
        {arguments, Arguments} ->
            check(maps:get(<<"email">>, Arguments) == <<"a@b.com">>, <<"pii tool arguments">>)
    after 0 -> erlang:error(<<"missing tool arguments">>) end,
    receive
        {request, SecondRequest} ->
            Messages = maps:get(messages, SecondRequest),
            Assistant = lists:nth(4, Messages),
            check(maps:get(content, Assistant) == <<"[REDACTED:email]">>, <<"pii assistant">>),
            [AssistantCall] = maps:get(tool_calls, Assistant),
            check(
                maps:get(<<"email">>, maps:get(arguments, AssistantCall)) == <<"[REDACTED:email]">>,
                <<"pii assistant tool call">>
            ),
            {ok, Value} = praxo_json:parse(maps:get(content, lists:last(Messages))),
            check(
                praxo_json:equals(
                    Value,
                    #{<<"nested">> => [<<"[REDACTED:email]">>, #{<<"ssn">> => <<"[REDACTED:ssn]">>}]}
                ),
                <<"pii tool result">>
            )
    after 0 -> erlang:error(<<"missing second pii request">>) end,
    check(maps:get(content, History) == <<"a@b.com">>, <<"pii session unchanged">>).

test_agent_structured() ->
    Schema = #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"name">>],
        <<"properties">> => #{<<"name">> => #{<<"type">> => <<"string">>}}
    },
    Config = praxo_middleware:structured_output(
        Schema,
        1,
        fun(_) -> {ok, <<"{\"name\":\"fixed\"}">>} end
    ),
    Options0 = praxo_agent:new_agent_options(praxo_agent:static_model(<<"bad">>)),
    {ok, Result, _} = praxo_agent:run_agent(
        Options0#{structured_output => Config},
        praxo_models:session(<<"s1">>),
        <<"x">>
    ),
    check(maps:get(output, Result) == <<"{\"name\":\"fixed\"}">>, <<"structured repair">>),
    NoRepair = praxo_middleware:structured_output(Schema, 0),
    {error, <<"AGENT_STRUCTURED_OUTPUT">>, _} = praxo_agent:run_agent(
        Options0#{structured_output => NoRepair},
        praxo_models:session(<<"s1">>),
        <<"x">>
    ).

test_agent_limits() ->
    put(tool_invocations, 0),
    put(model_invocations, 0),
    Tool = praxo_agent:new_tool(<<"echo">>, <<"Echo">>, fun(_) ->
        put(tool_invocations, get(tool_invocations) + 1),
        <<"ok">>
    end),
    Calls = [
        praxo_models:tool_call(<<"1">>, <<"echo">>, #{}),
        praxo_models:tool_call(<<"2">>, <<"echo">>, #{})
    ],
    Model = fun(_) ->
        put(model_invocations, get(model_invocations) + 1),
        {ok, praxo_models:response(praxo_models:message_assistant(<<>>, Calls)), praxo_agent:failing_model()}
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Tool],
        call_limit => praxo_middleware:call_limit(0, 1),
        events => praxo_sink:new()
    },
    {error, <<"AGENT_TOOL_CALL_LIMIT">>, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"x">>
    ),
    check(maps:get(calls, hd(maps:get(tools, Returned))) == 1, <<"tool budget">>),
    check(get(tool_invocations) == 1, <<"tool invocation count">>),
    check(get(model_invocations) == 1, <<"model invocation count">>),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"tool.call">>, <<"run.failed">>],
        <<"limit events">>
    ),
    erase(tool_invocations),
    erase(model_invocations).

test_run_state_isolation() ->
    First = praxo_middleware:call_limit(1, 0),
    Second = praxo_middleware:call_limit(1, 0),
    {ok, FirstUsed} = praxo_middleware:model_call(First),
    {ok, SecondUsed} = praxo_middleware:model_call(Second),
    {error, <<"AGENT_MODEL_CALL_LIMIT">>, _} =
        praxo_middleware:model_call(FirstUsed),
    check(maps:get(models, SecondUsed) == 1, <<"run state isolation">>).

test_agent_capacity() ->
    Options0 = praxo_agent:new_agent_options(praxo_agent:static_model(<<"done">>)),
    Options = Options0#{
        system_prompt => binary:copy(<<"x">>, 1000),
        context => praxo_models:context_budget(10, 0),
        events => praxo_sink:new()
    },
    {error, <<"AGENT_CONTEXT_BUDGET">>, Returned} = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"s1">>),
        <<"go">>
    ),
    check(
        praxo_sink:kinds(maps:get(events, Returned)) ==
            [<<"run.started">>, <<"run.failed">>],
        <<"capacity fail-closed events">>
    ).
