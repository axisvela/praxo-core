#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    Tool0 = praxo_agent:new_tool(
        <<"write_note">>,
        <<"Write a short note with the requested visibility.">>,
        fun(Arguments) ->
            put(write_note, get(write_note) + 1),
            Arguments
        end
    ),
    Tool = Tool0#{parameters => #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"text">>, <<"visibility">>],
        <<"properties">> => #{
            <<"text">> => #{<<"type">> => <<"string">>},
            <<"visibility">> => #{
                <<"type">> => <<"string">>,
                <<"enum">> => [<<"public">>, <<"private">>]
            }
        }
    }},
    Model = praxo_agent:scripted_model([
        praxo_models:response(praxo_models:message_assistant(<<>>, [
            praxo_models:tool_call(<<"write-note-1">>, <<"write_note">>,
                #{<<"text">> => <<"hello">>, <<"visibility">> => <<"public">>})
        ])),
        praxo_models:response(praxo_models:message_assistant(<<"done">>))
    ]),
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => [Tool],
        allowed_tools => [<<"write_note">>],
        policy => fun(Action) ->
            case maps:get(kind, Action) of
                <<"model.generate">> -> praxo_models:decision(true);
                <<"tool.invoke">> ->
                    Arguments = maps:get(arguments, Action),
                    praxo_models:decision(
                        maps:get(tool_name, Action) == <<"write_note">> andalso
                            maps:get(<<"visibility">>, Arguments) == <<"public">>,
                        <<"only public notes are permitted">>
                    )
            end
        end,
        interrupt_on => [<<"write_note">>],
        on_interrupt_decision => fun(_Interrupt) ->
            #{action => <<"approve">>}
        end
    },
    put(write_note, 0),
    {ok, Result, _} = praxo_agent:run_agent(
        Options, praxo_models:session(<<"hitl-approve">>), <<"Write a note.">>),
    <<"done">> = maps:get(output, Result),
    1 = get(write_note),
    io:format("approve: written; effects=1~n"),

    Model2 = praxo_agent:scripted_model([
        praxo_models:response(praxo_models:message_assistant(<<>>, [
            praxo_models:tool_call(<<"write-note-1">>, <<"write_note">>,
                #{<<"text">> => <<"hello">>, <<"visibility">> => <<"public">>})
        ])),
        praxo_models:response(praxo_models:message_assistant(<<"done">>))
    ]),
    Options2 = Options#{model => Model2,
        on_interrupt_decision => fun(_Interrupt) ->
            #{action => <<"edit">>,
              arguments => #{<<"text">> => <<"hello">>, <<"visibility">> => <<"private">>}}
        end},
    put(write_note, 0),
    {error, <<"AGENT_POLICY_DENIED">>, _} = praxo_agent:run_agent(
        Options2, praxo_models:session(<<"hitl-edit">>), <<"Write a note.">>),
    0 = get(write_note),
    io:format("edit: policy rejected; effects=0~n").
