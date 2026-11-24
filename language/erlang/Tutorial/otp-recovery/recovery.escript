#!/usr/bin/env escript
%%! -noshell

main(Args) ->
    code:add_pathz("language/erlang/build/ebin"),
    case lists:member("--test", Args) of
        true -> run_tests();
        false ->
            Service = value_after("--service", Args, "service-100"),
            Failure = lists:member("--simulate-failure", Args),
            {Output, Reads, Drafts, Error} = run_case(list_to_binary(Service), Failure),
            case Error of
                ok when Output =:= <<"SUPERVISION_UNAVAILABLE">> ->
                    io:format("~s~n", [Output]), halt(1);
                ok -> io:format("~s~n", [Output]);
                Code ->
                    io:format(standard_error, "otp recovery failed: reads=~p drafts=~p; ~s~n",
                              [Reads, Drafts, Code]),
                    halt(1)
            end
    end.

value_after(Flag, Args, Default) ->
    case lists:splitwith(fun(Argument) -> Argument =/= Flag end, Args) of
        {_, [Flag, Value | _]} -> Value;
        _ -> Default
    end.

exercise_recovery(Failure) ->
    case Failure of
        true -> {error, <<"SUPERVISION_UNAVAILABLE">>};
        false ->
            Table = ets:new(praxo_worker_starts, [set, public]),
            ets:insert(Table, {starts, 0}),
            {ok, Sup} = praxo_sup:start_link(Table),
            unlink(Sup),
            timer:sleep(50),
            [{worker, Pid1, _, _}] = supervisor:which_children(praxo_sup),
            Pid1 ! crash,
            timer:sleep(120),
            [{worker, Pid2, _, _}] = supervisor:which_children(praxo_sup),
            Starts = ets:lookup_element(Table, starts, 2),
            exit(Sup, shutdown),
            timer:sleep(20),
            try unregister(praxo_sup) catch _:_ -> ok end,
            ets:delete(Table),
            Recovered = is_pid(Pid2) andalso Pid2 =/= Pid1 andalso Starts >= 2,
            {ok, #{
                <<"service">> => <<"service-100">>,
                <<"first_pid">> => list_to_binary(pid_to_list(Pid1)),
                <<"second_pid">> => list_to_binary(pid_to_list(Pid2)),
                <<"worker_starts">> => Starts,
                <<"recovered">> => Recovered,
                <<"source">> => <<"otp_supervisor">>
            }}
    end.

run_case(Service, Failure) ->
    put(reads, 0),
    put(drafts, 0),
    ReadTool = praxo_agent:new_tool(
        <<"read_supervision">>,
        <<"Start a real OTP supervisor, crash a child and observe recovery.">>,
        fun(_Arguments) ->
            put(reads, get(reads) + 1),
            case exercise_recovery(Failure) of
                {error, Code} -> #{<<"error">> => Code};
                {ok, Evidence} -> Evidence
            end
        end),
    DraftTool = praxo_agent:new_tool(
        <<"draft_review">>,
        <<"Draft a review-only recovery action; never changes a cluster.">>,
        fun(Arguments) ->
            put(drafts, get(drafts) + 1),
            #{
                <<"review_id">> => <<"otp-review-100">>,
                <<"service">> => maps:get(<<"service">>, Arguments),
                <<"action">> => maps:get(<<"action">>, Arguments),
                <<"status">> => <<"draft_only">>,
                <<"review_required">> => true,
                <<"cluster_actions">> => 0
            }
        end),
    Policy = fun(Action) ->
        case maps:get(kind, Action) of
            <<"model.generate">> -> #{allowed => true};
            <<"tool.invoke">> ->
                Arguments = maps:get(arguments, Action, #{}),
                InScope = maps:get(<<"service">>, Arguments, undefined) =:= <<"service-100">>,
                case {InScope, maps:get(tool_name, Action)} of
                    {true, <<"read_supervision">>} -> #{allowed => true};
                    {true, <<"draft_review">>} ->
                        case maps:get(<<"action">>, Arguments, undefined) of
                            <<"review_recovered">> -> #{allowed => true};
                            <<"review_failed">> -> #{allowed => true};
                            _ -> #{allowed => false}
                        end;
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
                Call = praxo_models:tool_call(<<"supervision-1">>, <<"read_supervision">>,
                                              #{<<"service">> => Service}),
                {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [Call])), F};
            [First | _] ->
                {ok, Evidence} = praxo_json:parse(maps:get(content, First)),
                case maps:get(<<"error">>, Evidence, undefined) of
                    <<"SUPERVISION_UNAVAILABLE">> ->
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(<<"SUPERVISION_UNAVAILABLE">>)), F};
                    _ when length(Tools) =:= 1 ->
                        Action = case maps:get(<<"recovered">>, Evidence, false) of
                            true -> <<"review_recovered">>;
                            false -> <<"review_failed">>
                        end,
                        Call = praxo_models:tool_call(<<"review-1">>, <<"draft_review">>,
                            #{<<"service">> => Service, <<"action">> => Action}),
                        {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [Call])), F};
                    _ ->
                        Last = lists:last(Tools),
                        {ok, Review} = praxo_json:parse(maps:get(content, Last)),
                        Report = #{
                            <<"stage">> => <<"otp_review_drafted">>,
                            <<"supervision">> => Evidence,
                            <<"review">> => Review,
                            <<"cluster_actions">> => 0
                        },
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(praxo_json:encode(Report))), F}
                end
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [ReadTool, DraftTool],
        allowed_tools => [<<"read_supervision">>, <<"draft_review">>],
        max_steps => 4,
        policy => Policy,
        require_policy => true,
        require_tool_scope => true
    },
    case praxo_agent:run_agent(Options, praxo_models:session(<<"otp-recovery">>),
            <<"Exercise supervised recovery and draft a review-only action.">>) of
        {ok, Result, _} -> {maps:get(output, Result), get(reads), get(drafts), ok};
        {error, Code, _} -> {<<>>, get(reads), get(drafts), Code}
    end.

run_tests() ->
    {Success, 1, 1, ok} = run_case(<<"service-100">>, false),
    {ok, Report} = praxo_json:parse(Success),
    <<"otp_review_drafted">> = maps:get(<<"stage">>, Report),
    Supervision = maps:get(<<"supervision">>, Report),
    true = maps:get(<<"recovered">>, Supervision),
    Starts = maps:get(<<"worker_starts">>, Supervision),
    true = Starts >= 2,
    Review = maps:get(<<"review">>, Report),
    <<"review_recovered">> = maps:get(<<"action">>, Review),
    0 = maps:get(<<"cluster_actions">>, Report),
    io:format("success: service-100 recovered=true worker_starts=~p status=draft_only reads=1~n",
              [Starts]),
    {<<>>, 0, 0, <<"AGENT_POLICY_DENIED">>} = run_case(<<"service-200">>, false),
    io:format("deny: AGENT_POLICY_DENIED reads=0~n"),
    {<<"SUPERVISION_UNAVAILABLE">>, 1, 0, ok} = run_case(<<"service-100">>, true),
    io:format("failure: SUPERVISION_UNAVAILABLE reads=1~n"),
    io:format("Erlang otp-recovery tutorial: all checks passed~n").

