#!/usr/bin/env escript
%%! -noshell

main(Args) ->
    code:add_pathz("language/erlang/build/ebin"),
    case lists:member("--test", Args) of
        true -> run_tests();
        false ->
            Service = value_after("--service", Args, "service-100"),
            Clean = lists:member("--clean", Args),
            Failure = lists:member("--simulate-failure", Args),
            {Output, Reads, Drafts, Error} = run_case(list_to_binary(Service), Clean, Failure),
            case Error of
                ok when Output =:= <<"EVENTS_UNAVAILABLE">> ->
                    io:format("~s~n", [Output]), halt(1);
                ok -> io:format("~s~n", [Output]);
                Code ->
                    io:format(standard_error, "soc correlation failed: reads=~p drafts=~p; ~s~n",
                              [Reads, Drafts, Code]),
                    halt(1)
            end
    end.

value_after(Flag, Args, Default) ->
    case lists:splitwith(fun(Argument) -> Argument =/= Flag end, Args) of
        {_, [Flag, Value | _]} -> Value;
        _ -> Default
    end.

run_case(Service, Clean, Failure) ->
    put(reads, 0),
    put(drafts, 0),
    ReadTool = praxo_agent:new_tool(
        <<"read_events">>,
        <<"Correlate fixed EDR and firewall events; no live telemetry or blocking.">>,
        fun(_Arguments) ->
            put(reads, get(reads) + 1),
            case Failure of
                true -> #{<<"error">> => <<"EVENTS_UNAVAILABLE">>};
                false ->
                    Events = case Clean of
                        true -> [#{<<"severity">> => <<"low">>, <<"host">> => <<"edge-2">>, <<"source">> => <<"edr">>}];
                        false -> [
                            #{<<"severity">> => <<"critical">>, <<"host">> => <<"edge-1">>, <<"source">> => <<"edr">>},
                            #{<<"severity">> => <<"high">>, <<"host">> => <<"edge-1">>, <<"source">> => <<"firewall">>},
                            #{<<"severity">> => <<"low">>, <<"host">> => <<"edge-2">>, <<"source">> => <<"edr">>}
                        ]
                    end,
                    Critical = length([E || E <- Events, maps:get(<<"severity">>, E) =:= <<"critical">>]),
                    #{<<"service">> => Service, <<"events">> => Events,
                      <<"critical">> => Critical, <<"suspect">> => <<"edge-1">>,
                      <<"source">> => <<"event_fixture">>}
            end
        end),
    DraftTool = praxo_agent:new_tool(
        <<"draft_review">>,
        <<"Draft a review-only isolation or monitoring action; never blocks a host.">>,
        fun(Arguments) ->
            put(drafts, get(drafts) + 1),
            #{
                <<"review_id">> => <<"soc-review-100">>,
                <<"service">> => maps:get(<<"service">>, Arguments),
                <<"action">> => maps:get(<<"action">>, Arguments),
                <<"status">> => <<"draft_only">>,
                <<"review_required">> => true,
                <<"host_blocks">> => 0
            }
        end),
    Policy = fun(Action) ->
        case maps:get(kind, Action) of
            <<"model.generate">> -> #{allowed => true};
            <<"tool.invoke">> ->
                Arguments = maps:get(arguments, Action, #{}),
                InScope = maps:get(<<"service">>, Arguments, undefined) =:= <<"service-100">>,
                case {InScope, maps:get(tool_name, Action)} of
                    {true, <<"read_events">>} -> #{allowed => true};
                    {true, <<"draft_review">>} ->
                        Choice = maps:get(<<"action">>, Arguments, undefined),
                        Allowed = Choice =:= <<"review_isolation">> orelse Choice =:= <<"review_monitor">>,
                        #{allowed => Allowed};
                    _ -> #{allowed => false}
                end;
            _ -> #{allowed => false}
        end
    end,
    Model = fun F(Request) ->
        Messages = maps:get(messages, Request),
        Tools = [M || M <- Messages, maps:get(role, M) =:= <<"tool">>],
        case Tools of
            [] ->
                Call = praxo_models:tool_call(<<"events-1">>, <<"read_events">>,
                                              #{<<"service">> => Service}),
                {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [Call])), F};
            [First | _] ->
                {ok, Evidence} = praxo_json:parse(maps:get(content, First)),
                case maps:get(<<"error">>, Evidence, undefined) of
                    <<"EVENTS_UNAVAILABLE">> ->
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(<<"EVENTS_UNAVAILABLE">>)), F};
                    _ when length(Tools) =:= 1 ->
                        Critical = maps:get(<<"critical">>, Evidence, 0),
                        Choice = case Critical > 0 of
                            true -> <<"review_isolation">>;
                            false -> <<"review_monitor">>
                        end,
                        Call = praxo_models:tool_call(<<"review-1">>, <<"draft_review">>,
                            #{<<"service">> => Service, <<"action">> => Choice}),
                        {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [Call])), F};
                    _ ->
                        Last = lists:last(Tools),
                        {ok, Review} = praxo_json:parse(maps:get(content, Last)),
                        Report = #{
                            <<"stage">> => <<"soc_review_drafted">>,
                            <<"events">> => Evidence,
                            <<"review">> => Review,
                            <<"host_blocks">> => 0
                        },
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(praxo_json:encode(Report))), F}
                end
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [ReadTool, DraftTool],
        allowed_tools => [<<"read_events">>, <<"draft_review">>],
        max_steps => 4,
        policy => Policy,
        require_policy => true,
        require_tool_scope => true
    },
    case praxo_agent:run_agent(Options, praxo_models:session(<<"soc-correlation">>),
            <<"Correlate fixed events and draft a review-only action.">>) of
        {ok, Result, _} -> {maps:get(output, Result), get(reads), get(drafts), ok};
        {error, Code, _} -> {<<>>, get(reads), get(drafts), Code}
    end.

run_tests() ->
    {Success, 1, 1, ok} = run_case(<<"service-100">>, false, false),
    {ok, Report} = praxo_json:parse(Success),
    <<"soc_review_drafted">> = maps:get(<<"stage">>, Report),
    Evidence = maps:get(<<"events">>, Report),
    1 = maps:get(<<"critical">>, Evidence),
    <<"edge-1">> = maps:get(<<"suspect">>, Evidence),
    Review = maps:get(<<"review">>, Report),
    <<"review_isolation">> = maps:get(<<"action">>, Review),
    0 = maps:get(<<"host_blocks">>, Report),
    io:format("success: service-100 critical=1 suspect=edge-1 status=draft_only blocks=0 reads=1~n"),
    {Clean, 1, 1, ok} = run_case(<<"service-100">>, true, false),
    {ok, CleanReport} = praxo_json:parse(Clean),
    CleanEvidence = maps:get(<<"events">>, CleanReport),
    0 = maps:get(<<"critical">>, CleanEvidence),
    CleanReview = maps:get(<<"review">>, CleanReport),
    <<"review_monitor">> = maps:get(<<"action">>, CleanReview),
    io:format("success: clean critical=0 action=review_monitor reads=1~n"),
    {<<>>, 0, 0, <<"AGENT_POLICY_DENIED">>} = run_case(<<"service-200">>, false, false),
    io:format("deny: AGENT_POLICY_DENIED reads=0~n"),
    {<<"EVENTS_UNAVAILABLE">>, 1, 0, ok} = run_case(<<"service-100">>, false, true),
    io:format("failure: EVENTS_UNAVAILABLE reads=1~n"),
    io:format("Erlang soc-correlation tutorial: all checks passed~n").
