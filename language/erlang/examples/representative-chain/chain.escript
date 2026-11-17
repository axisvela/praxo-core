#!/usr/bin/env escript
main(_) ->
    add_paths(),
    #{output := Output, effects := Effects, child_calls := ChildCalls,
      otel := Otel, harmovela := Harmovela} = run_chain(),
    <<"DONE">> = Output,
    1 = maps:get(<<"parent">>, Effects),
    1 = maps:get(<<"child">>, Effects),
    true = ChildCalls >= 2,
    [<<"praxo.run.started">>, <<"praxo.tool.call">>, <<"praxo.run.completed">>] =
        required(Otel, [
            <<"praxo.run.started">>, <<"praxo.tool.call">>, <<"praxo.run.completed">>
        ]),
    [<<"run.started">>, <<"tool.call">>, <<"run.completed">>] =
        required(Harmovela, [
            <<"run.started">>, <<"tool.call">>, <<"run.completed">>
        ]),
    {Blocked, DeniedCode} = run_denial(),
    0 = Blocked,
    <<"AGENT_POLICY_DENIED">> = DeniedCode,
    io:format("output: ~s~n", [Output]),
    io:format("effects: parent=~p child=~p~n", [
        maps:get(<<"parent">>, Effects), maps:get(<<"child">>, Effects)
    ]),
    io:format("child calls: ~p~n", [ChildCalls]),
    io:format("otel spans: ~p~n", [length(Otel)]),
    io:format("harmovela events: ~p~n", [length(Harmovela)]),
    io:format("denied effects: ~p~n", [Blocked]),
    io:format("erlang representative chain passed~n").

add_paths() ->
    Script = filename:dirname(filename:absname(escript:script_name())),
    Paths = [
        filename:absname(filename:join([Script, "..", "..", "build", "ebin"])),
        filename:absname(filename:join([
            Script, "..", "..", "_build", "default", "lib", "praxo_core", "ebin"
        ])),
        "language/erlang/build/ebin",
        "_build/default/lib/praxo_core/ebin"
    ],
    lists:foreach(fun code:add_pathz/1, Paths),
    ok.

required(Values, Wanted) ->
    Missing = [Item || Item <- Wanted, not lists:member(Item, Values)],
    case Missing of
        [] -> Wanted;
        _ -> erlang:error({missing_events, Missing, Values})
    end.

new_state(Value) ->
    Key = {chain, make_ref()},
    put(Key, Value),
    Key.

state_get(Key) ->
    get(Key).

state_set(Key, Value) ->
    put(Key, Value).

effect_inc(Target, Key) ->
    Effects = state_get(Key),
    state_set(Key, Effects#{Target => maps:get(Target, Effects, 0) + 1}).

append_log(Key, Values) ->
    Existing =
        case get(Key) of
            undefined -> [];
            Current -> Current
        end,
    put(Key, Existing ++ Values).

mcp_client(EffectsKey) ->
    Transport = fun(Method, Params, Timeout) ->
        mcp_request(Method, Params, Timeout, EffectsKey)
    end,
    {ok, Client} = praxo_mcp:start(praxo_mcp:new(#{transport => Transport})),
    Client.

mcp_request(<<"initialize">>, _Params, _Timeout, _EffectsKey) ->
    {ok, #{
        <<"protocolVersion">> => <<"2024-11-05">>,
        <<"capabilities">> => #{<<"tools">> => #{}},
        <<"serverInfo">> => #{
            <<"name">> => <<"fixture-mcp">>, <<"version">> => <<"0.0.1">>
        }
    }};
mcp_request(<<"tools/list">>, _Params, _Timeout, _EffectsKey) ->
    {ok, #{<<"tools">> => [#{
        <<"name">> => <<"record">>,
        <<"description">> => <<"Record a target">>,
        <<"inputSchema">> => #{
            <<"type">> => <<"object">>,
            <<"properties">> => #{<<"target">> => #{<<"type">> => <<"string">>}},
            <<"required">> => [<<"target">>]
        }
    }]}};
mcp_request(<<"tools/call">>, Params, _Timeout, EffectsKey) ->
    Name = maps:get(<<"name">>, Params, <<>>),
    Arguments = maps:get(<<"arguments">>, Params, #{}),
    case Name of
        <<"record">> ->
            Target = maps:get(<<"target">>, Arguments, <<>>),
            effect_inc(Target, EffectsKey),
            {ok, #{
                <<"isError">> => false,
                <<"structuredContent">> => #{<<"recorded">> => Target}
            }};
        _ ->
            {ok, #{<<"isError">> => true, <<"content">> => []}}
    end;
mcp_request(_Method, _Params, _Timeout, _EffectsKey) ->
    {error, <<"MCP_RPC">>}.

record_tool(Client) ->
    praxo_agent:new_tool(
        <<"record">>,
        <<"Record a target">>,
        fun(Arguments) ->
            case praxo_mcp:call_tool(Client, <<"record">>, Arguments) of
                {ok, Value} -> Value;
                {error, Code} -> #{<<"error">> => Code}
            end
        end
    ).

counting_model(Steps, CounterKey) ->
    fun(_Request) ->
        Count = state_get(CounterKey),
        state_set(CounterKey, Count + 1),
        case Count < length(Steps) of
            true ->
                {ok, lists:nth(Count + 1, Steps), counting_model(Steps, CounterKey)};
            false ->
                {error, <<"MODEL_ERROR">>, counting_model(Steps, CounterKey)}
        end
    end.

tool_response(CallId, Name, Arguments) ->
    praxo_models:response(
        praxo_models:message_assistant(<<>>, [
            praxo_models:tool_call(CallId, Name, Arguments)
        ])
    ).

final_response(Content) ->
    praxo_models:response(praxo_models:message_assistant(Content)).

parent_policy(Action) ->
    case maps:get(kind, Action) of
        <<"tool.invoke">> ->
            case maps:get(tool_name, Action) of
                <<"record">> ->
                    Arguments = maps:get(arguments, Action, #{}),
                    case maps:get(<<"target">>, Arguments, <<>>) of
                        <<"blocked">> ->
                            praxo_models:decision(false, <<"blocked target">>);
                        _ ->
                            praxo_models:decision(true, <<"record allowed">>)
                    end;
                <<"delegate">> ->
                    praxo_models:decision(true, <<"delegate allowed">>);
                _ ->
                    praxo_models:decision(false, <<"parent tool is not allowed">>)
            end;
        _ ->
            praxo_models:decision(true, <<"non-tool action">>)
    end.

child_policy(Action) ->
    case maps:get(kind, Action) of
        <<"tool.invoke">> ->
            case maps:get(tool_name, Action) of
                <<"record">> -> praxo_models:decision(true, <<"record allowed">>);
                _ -> praxo_models:decision(false, <<"child may only record">>)
            end;
        _ ->
            praxo_models:decision(true, <<"non-tool action">>)
    end.

compose_policy(Parent, Child) ->
    fun(Action) ->
        case Parent(Action) of
            #{allowed := true} -> Child(Action);
            Decision -> Decision
        end
    end.

delegate_tool(Record, ChildModel, Events) ->
    praxo_agent:new_tool(
        <<"delegate">>,
        <<"Run a governed child agent with the narrowed record scope">>,
        fun(_Arguments) ->
            Options0 = praxo_agent:new_agent_options(ChildModel),
            Options = Options0#{
                tools => [Record],
                allowed_tools => [<<"record">>],
                max_steps => 3,
                policy => compose_policy(fun parent_policy/1, fun child_policy/1),
                require_policy => true,
                require_tool_scope => true,
                events => Events,
                session_id => <<"chain-child">>
            },
            case praxo_agent:run_agent(
                Options,
                praxo_models:session(<<"chain-child">>),
                <<"record child">>
            ) of
                {ok, Result, _} -> #{<<"output">> => maps:get(output, Result)};
                {error, Code, _} -> #{<<"error">> => Code}
            end
        end
    ).

otel_transport(_Url, Body, _Headers) ->
    {ok, Payload} = praxo_json:parse(Body),
    Names = [
        maps:get(<<"name">>, Span)
     || Resource <- maps:get(<<"resourceSpans">>, Payload, []),
        Scope <- maps:get(<<"scopeSpans">>, Resource, []),
        Span <- maps:get(<<"spans">>, Scope, [])
    ],
    append_log(otel_log, Names),
    {ok, 200, <<>>}.

harmovela_transport(_Path, Body, _Headers) ->
    {ok, Envelope} = praxo_json:parse(Body),
    append_log(harmovela_log, [maps:get(<<"type">>, Envelope, <<>>)]),
    {ok, 202, <<>>}.

new_events() ->
    Otel = praxo_otel:new(<<"http://otel.local/v1/traces">>, #{
        transport => fun otel_transport/3,
        clock => fun() -> 1700000000000000000 end
    }),
    Harmovela = praxo_harmovela:new(<<"http://harmovela.local">>, #{
        transport => fun harmovela_transport/3,
        clock => fun() -> {1700000000, 0} end
    }),
    OtelSink = #{
        kinds => [],
        handler => fun(Event) -> ok = praxo_otel:emit(Otel, Event) end
    },
    praxo_sink:multi([OtelSink, Harmovela]).

run_chain() ->
    put(otel_log, []),
    put(harmovela_log, []),
    EffectsKey = new_state(#{}),
    ChildCallsKey = new_state(0),
    Client0 = mcp_client(EffectsKey),
    {ok, _Tools} = praxo_mcp:list_tools(Client0),
    Record = record_tool(Client0),
    Events = new_events(),
    ChildModel = counting_model([
        tool_response(<<"child-record">>, <<"record">>, #{<<"target">> => <<"child">>}),
        final_response(<<"CHILD-DONE">>)
    ], ChildCallsKey),
    Delegate = delegate_tool(Record, ChildModel, Events),
    ParentModel = counting_model([
        tool_response(<<"parent-record">>, <<"record">>, #{<<"target">> => <<"parent">>}),
        tool_response(<<"parent-delegate">>, <<"delegate">>, #{<<"task">> => <<"child">>}),
        final_response(<<"DONE">>)
    ], new_state(0)),
    Options0 = praxo_agent:new_agent_options(ParentModel),
    Options = Options0#{
        tools => [Record, Delegate],
        allowed_tools => [<<"record">>, <<"delegate">>],
        max_steps => 6,
        policy => fun parent_policy/1,
        require_policy => true,
        require_tool_scope => true,
        events => Events,
        session_id => <<"chain-parent">>
    },
    Result = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"chain-parent">>),
        <<"run the representative chain">>
    ),
    ok = praxo_mcp:close(Client0),
    case Result of
        {ok, RunResult, _} ->
            #{
                output => maps:get(output, RunResult),
                effects => state_get(EffectsKey),
                child_calls => state_get(ChildCallsKey),
                otel => get(otel_log),
                harmovela => get(harmovela_log)
            };
        {error, Code, _} ->
            erlang:error({chain_failed, Code})
    end.

run_denial() ->
    EffectsKey = new_state(#{}),
    Client0 = mcp_client(EffectsKey),
    {ok, _Tools} = praxo_mcp:list_tools(Client0),
    Record = record_tool(Client0),
    Model = counting_model([
        tool_response(<<"denied-record">>, <<"record">>, #{<<"target">> => <<"safe">>}),
        final_response(<<"UNEXPECTED">>)
    ], new_state(0)),
    Middleware = [#{
        before_tool => fun(Call) ->
            Call#{arguments => #{<<"target">> => <<"blocked">>}}
        end
    }],
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Record],
        allowed_tools => [<<"record">>],
        max_steps => 2,
        policy => fun parent_policy/1,
        require_policy => true,
        require_tool_scope => true,
        middleware => Middleware,
        session_id => <<"chain-denial">>
    },
    Result = praxo_agent:run_agent(
        Options,
        praxo_models:session(<<"chain-denial">>),
        <<"call record">>
    ),
    ok = praxo_mcp:close(Client0),
    Blocked = maps:get(<<"blocked">>, state_get(EffectsKey), 0),
    case Result of
        {error, <<"AGENT_POLICY_DENIED">>, _} ->
            {Blocked, <<"AGENT_POLICY_DENIED">>};
        _ ->
            erlang:error({denial_path_unexpected, Result})
    end.
