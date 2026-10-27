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
    io:format("erlang tests passed~n").

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
    check(length(praxo_jsonschema:validate(Pattern, <<"b">>)) == 1, <<"schema pattern invalid">>).

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
