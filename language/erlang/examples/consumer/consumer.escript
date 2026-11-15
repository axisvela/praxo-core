#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    run(<<"public">>, 1, <<"allow: recorded; effects=1">>),
    run(<<"private">>, 0, <<"deny: policy rejected; effects=0">>).

run(Target, ExpectedEffects, Line) ->
    put(record_effects, 0),
    Tool0 = praxo_agent:new_tool(
        <<"record">>,
        <<"Record a target in an in-memory counter.">>,
        fun(Arguments) ->
            put(record_effects, get(record_effects) + 1),
            Arguments
        end
    ),
    Tool = Tool0#{parameters => #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"target">>],
        <<"properties">> => #{<<"target">> => #{<<"type">> => <<"string">>}}
    }},
    Model = praxo_agent:scripted_model([
        praxo_models:response(praxo_models:message_assistant(<<>>, [
            praxo_models:tool_call(<<"record-1">>, <<"record">>,
                #{<<"target">> => Target})
        ])),
        praxo_models:response(praxo_models:message_assistant(<<"recorded">>))
    ]),
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Tool],
        allowed_tools => [<<"record">>],
        max_steps => 3,
        policy => fun(Action) ->
            case maps:get(kind, Action) of
                <<"model.generate">> ->
                    praxo_models:decision(true);
                <<"tool.invoke">> ->
                    Arguments = maps:get(arguments, Action),
                    praxo_models:decision(
                        maps:get(tool_name, Action) == <<"record">> andalso
                            maps:get(<<"target">>, Arguments, undefined) ==
                                <<"public">>,
                        <<"only the public target is permitted">>
                    )
            end
        end
    },
    case ExpectedEffects of
        1 ->
            {ok, Result, _} = praxo_agent:run_agent(
                Options, praxo_models:session(<<"consumer-public">>),
                <<"Record the requested target.">>),
            <<"recorded">> = maps:get(output, Result),
            1 = get(record_effects);
        0 ->
            {error, <<"AGENT_POLICY_DENIED">>, _} = praxo_agent:run_agent(
                Options, praxo_models:session(<<"consumer-private">>),
                <<"Record the requested target.">>),
            0 = get(record_effects)
    end,
    io:format("~s~n", [Line]).
