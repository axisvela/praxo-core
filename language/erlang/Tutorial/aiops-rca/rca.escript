#!/usr/bin/env escript
%%! -noshell

main(Args) ->
    code:add_pathz("language/erlang/build/ebin"),
    case lists:member("--test", Args) of
        true ->
            run_tests();
        false ->
            Service = value_after("--service", Args, "service-100"),
            Failure = lists:member("--simulate-failure", Args),
            {Output, Reads, Drafts, Error} =
                run_case(list_to_binary(Service), Failure),
            case Error of
                ok ->
                    case Output of
                        <<"TELEMETRY_UNAVAILABLE">> ->
                            io:format("~s~n", [Output]),
                            halt(1);
                        _ ->
                            io:format("~s~n", [Output])
                    end;
                Code ->
                    io:format(standard_error,
                              "aiops rca failed: reads=~p drafts=~p; ~s~n",
                              [Reads, Drafts, Code]),
                    halt(1)
            end
    end.

value_after(Flag, Args, Default) ->
    case lists:splitwith(fun(Argument) -> Argument =/= Flag end, Args) of
        {_, [Flag, Value | _]} -> Value;
        _ -> Default
    end.

run_case(Service, Failure) ->
    put(reads, 0),
    put(drafts, 0),
    ReadTool = praxo_agent:new_tool(
        <<"read_signals">>,
        <<"Correlate fixed trace, metric and log signals; no live telemetry.">>,
        fun(_Arguments) ->
            put(reads, get(reads) + 1),
            case Failure of
                true ->
                    #{<<"error">> => <<"TELEMETRY_UNAVAILABLE">>};
                false ->
                    #{
                        <<"service">> => Service,
                        <<"error_rate">> => 0.18,
                        <<"latency_ms">> => 940,
                        <<"suspect">> => <<"checkout-api">>,
                        <<"trace">> => <<"trace-100">>,
                        <<"source">> => <<"signal_fixture">>
                    }
            end
        end
    ),
    DraftTool = praxo_agent:new_tool(
        <<"draft_rollback">>,
        <<"Draft a review-only rollback; never executes a remediation.">>,
        fun(Arguments) ->
            put(drafts, get(drafts) + 1),
            #{
                <<"rollback_id">> => <<"rollback-100">>,
                <<"service">> => maps:get(<<"service">>, Arguments),
                <<"action">> => maps:get(<<"action">>, Arguments),
                <<"status">> => <<"draft_only">>,
                <<"review_required">> => true,
                <<"actions">> => 0
            }
        end
    ),
    Policy = fun(Action) ->
        case maps:get(kind, Action) of
            <<"model.generate">> ->
                #{allowed => true};
            <<"tool.invoke">> ->
                Arguments = maps:get(arguments, Action, #{}),
                InScope = maps:get(<<"service">>, Arguments, undefined) =:= <<"service-100">>,
                case {InScope, maps:get(tool_name, Action)} of
                    {true, <<"read_signals">>} ->
                        #{allowed => true};
                    {true, <<"draft_rollback">>} ->
                        case maps:get(<<"action">>, Arguments, undefined) of
                            <<"rollback">> -> #{allowed => true};
                            _ -> #{allowed => false}
                        end;
                    _ ->
                        #{allowed => false}
                end;
            _ ->
                #{allowed => false}
        end
    end,
    Model = fun F(Request) ->
        Messages = maps:get(messages, Request),
        Tools = [M || M <- Messages, maps:get(role, M) =:= <<"tool">>],
        case Tools of
            [] ->
                Call = praxo_models:tool_call(
                    <<"signals-1">>, <<"read_signals">>,
                    #{<<"service">> => Service}),
                {ok, praxo_models:response(
                    praxo_models:message_assistant(<<>>, [Call])), F};
            [First | _] ->
                {ok, FirstValue} = praxo_json:parse(maps:get(content, First)),
                case maps:get(<<"error">>, FirstValue, undefined) of
                    <<"TELEMETRY_UNAVAILABLE">> ->
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(
                                <<"TELEMETRY_UNAVAILABLE">>)), F};
                    _ when length(Tools) =:= 1 ->
                        Call = praxo_models:tool_call(
                            <<"rollback-1">>, <<"draft_rollback">>,
                            #{<<"service">> => Service,
                              <<"action">> => <<"rollback">>}),
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(<<>>, [Call])), F};
                    _ ->
                        Last = lists:last(Tools),
                        {ok, LastValue} = praxo_json:parse(maps:get(content, Last)),
                        Report = #{
                            <<"stage">> => <<"rollback_drafted">>,
                            <<"signals">> => FirstValue,
                            <<"rollback">> => LastValue,
                            <<"actions">> => 0
                        },
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(
                                praxo_json:encode(Report))), F}
                end
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [ReadTool, DraftTool],
        allowed_tools => [<<"read_signals">>, <<"draft_rollback">>],
        max_steps => 4,
        policy => Policy,
        require_policy => true,
        require_tool_scope => true
    },
    case praxo_agent:run_agent(
            Options, praxo_models:session(<<"aiops-rca">>),
            <<"Correlate fixed signals and draft a review-only rollback.">>) of
        {ok, Result, _Options} ->
            {maps:get(output, Result), get(reads), get(drafts), ok};
        {error, Code, _Options} ->
            {<<>>, get(reads), get(drafts), Code}
    end.

run_tests() ->
    {Success, 1, 1, ok} = run_case(<<"service-100">>, false),
    {ok, Report} = praxo_json:parse(Success),
    <<"rollback_drafted">> = maps:get(<<"stage">>, Report),
    Signals = maps:get(<<"signals">>, Report),
    <<"checkout-api">> = maps:get(<<"suspect">>, Signals),
    0 = maps:get(<<"actions">>, Report),
    io:format("success: service-100 suspect=checkout-api status=draft_only actions=0 reads=1~n"),
    {<<>>, 0, 0, <<"AGENT_POLICY_DENIED">>} = run_case(<<"service-200">>, false),
    io:format("deny: AGENT_POLICY_DENIED reads=0~n"),
    {<<"TELEMETRY_UNAVAILABLE">>, 1, 0, ok} = run_case(<<"service-100">>, true),
    io:format("failure: TELEMETRY_UNAVAILABLE reads=1~n").
