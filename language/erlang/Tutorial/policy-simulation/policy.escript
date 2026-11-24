#!/usr/bin/env escript
%%! -noshell

main(Args) ->
    code:add_pathz("language/erlang/build/ebin"),
    case lists:member("--test", Args) of
        true -> run_tests();
        false ->
            Scenario = value_after("--scenario", Args, "scenario-100"),
            Failure = lists:member("--simulate-failure", Args),
            {Output, Reads, Drafts, Error} = run_case(list_to_binary(Scenario), Failure),
            case Error of
                ok when Output =:= <<"POPULATION_UNAVAILABLE">> ->
                    io:format("~s~n", [Output]), halt(1);
                ok -> io:format("~s~n", [Output]);
                Code ->
                    io:format(standard_error, "policy simulation failed: reads=~p drafts=~p; ~s~n",
                              [Reads, Drafts, Code]),
                    halt(1)
            end
    end.

value_after(Flag, Args, Default) ->
    case lists:splitwith(fun(Argument) -> Argument =/= Flag end, Args) of
        {_, [Flag, Value | _]} -> Value;
        _ -> Default
    end.

household(Parent, Subsidy) ->
    Parent ! {household, Subsidy},
    ok.

sum_policy(Households, Subsidy) ->
    Parent = self(),
    [spawn(fun() -> household(Parent, Subsidy) end) || _ <- lists:seq(1, Households)],
    lists:sum([receive {household, Value} -> Value end || _ <- lists:seq(1, Households)]).

run_case(Scenario, Failure) ->
    put(reads, 0),
    put(drafts, 0),
    ReadTool = praxo_agent:new_tool(
        <<"read_simulation">>,
        <<"Run a bounded concurrent household simulation; no real population data.">>,
        fun(_Arguments) ->
            put(reads, get(reads) + 1),
            case Failure of
                true -> #{<<"error">> => <<"POPULATION_UNAVAILABLE">>};
                false ->
                    Base = sum_policy(12, 100),
                    Alternate = sum_policy(12, 150),
                    #{<<"scenario">> => Scenario, <<"households">> => 12,
                      <<"base_total">> => Base, <<"alternate_total">> => Alternate,
                      <<"delta">> => Alternate - Base, <<"source">> => <<"population_fixture">>}
            end
        end),
    DraftTool = praxo_agent:new_tool(
        <<"draft_report">>,
        <<"Draft a review-only sensitivity report; never predicts real policy outcomes.">>,
        fun(Arguments) ->
            put(drafts, get(drafts) + 1),
            #{<<"report_id">> => <<"policy-100">>,
              <<"scenario">> => maps:get(<<"scenario">>, Arguments),
              <<"action">> => maps:get(<<"action">>, Arguments),
              <<"status">> => <<"draft_only">>, <<"review_required">> => true,
              <<"policy_predictions">> => 0}
        end),
    Policy = fun(Action) ->
        case maps:get(kind, Action) of
            <<"model.generate">> -> #{allowed => true};
            <<"tool.invoke">> ->
                Arguments = maps:get(arguments, Action, #{}),
                InScope = maps:get(<<"scenario">>, Arguments, undefined) =:= <<"scenario-100">>,
                case {InScope, maps:get(tool_name, Action)} of
                    {true, <<"read_simulation">>} -> #{allowed => true};
                    {true, <<"draft_report">>} ->
                        #{allowed => maps:get(<<"action">>, Arguments, undefined) =:= <<"review_sensitivity">>};
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
                Call = praxo_models:tool_call(<<"simulation-1">>, <<"read_simulation">>,
                                              #{<<"scenario">> => Scenario}),
                {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [Call])), F};
            [First | _] ->
                {ok, Evidence} = praxo_json:parse(maps:get(content, First)),
                case maps:get(<<"error">>, Evidence, undefined) of
                    <<"POPULATION_UNAVAILABLE">> ->
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(<<"POPULATION_UNAVAILABLE">>)), F};
                    _ when length(Tools) =:= 1 ->
                        Call = praxo_models:tool_call(<<"report-1">>, <<"draft_report">>,
                            #{<<"scenario">> => Scenario, <<"action">> => <<"review_sensitivity">>}),
                        {ok, praxo_models:response(praxo_models:message_assistant(<<>>, [Call])), F};
                    _ ->
                        Last = lists:last(Tools),
                        {ok, Report} = praxo_json:parse(maps:get(content, Last)),
                        Summary = #{<<"stage">> => <<"policy_simulation_drafted">>,
                                    <<"simulation">> => Evidence, <<"report">> => Report,
                                    <<"policy_predictions">> => 0},
                        {ok, praxo_models:response(
                            praxo_models:message_assistant(praxo_json:encode(Summary))), F}
                end
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [ReadTool, DraftTool],
        allowed_tools => [<<"read_simulation">>, <<"draft_report">>],
        max_steps => 4, policy => Policy,
        require_policy => true, require_tool_scope => true
    },
    case praxo_agent:run_agent(Options, praxo_models:session(<<"policy-simulation">>),
            <<"Simulate fixed households and draft a review-only sensitivity report.">>) of
        {ok, Result, _} -> {maps:get(output, Result), get(reads), get(drafts), ok};
        {error, Code, _} -> {<<>>, get(reads), get(drafts), Code}
    end.

run_tests() ->
    {Success, 1, 1, ok} = run_case(<<"scenario-100">>, false),
    {ok, Report} = praxo_json:parse(Success),
    <<"policy_simulation_drafted">> = maps:get(<<"stage">>, Report),
    Evidence = maps:get(<<"simulation">>, Report),
    12 = maps:get(<<"households">>, Evidence),
    1200 = maps:get(<<"base_total">>, Evidence),
    1800 = maps:get(<<"alternate_total">>, Evidence),
    600 = maps:get(<<"delta">>, Evidence),
    0 = maps:get(<<"policy_predictions">>, Report),
    io:format("success: scenario-100 households=12 base=1200 alt=1800 status=draft_only reads=1~n"),
    {<<>>, 0, 0, <<"AGENT_POLICY_DENIED">>} = run_case(<<"scenario-200">>, false),
    io:format("deny: AGENT_POLICY_DENIED reads=0~n"),
    {<<"POPULATION_UNAVAILABLE">>, 1, 0, ok} = run_case(<<"scenario-100">>, true),
    io:format("failure: POPULATION_UNAVAILABLE reads=1~n"),
    io:format("Erlang policy-simulation tutorial: all checks passed~n").
