#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    Allow0 = praxo_checkpoint:new(),
    Allow = praxo_checkpoint:register(Allow0, <<"session">>),
    Session0 = praxo_models:session(<<"session-1">>, [
        praxo_models:message(<<"user">>, <<"first">>),
        praxo_models:message(<<"assistant">>, <<"ack">>)
    ]),
    Messages = [praxo_models:message_wire(Message)
                || Message <- maps:get(messages, Session0)],
    {ok, Payload} = praxo_checkpoint:marshal(
        Allow, <<"session">>, #{<<"messages">> => Messages}),
    {ok, Stored} = praxo_checkpoint:unmarshal(Allow, Payload),
    Restored = [praxo_models:message(
                    maps:get(<<"role">>, Item),
                    maps:get(<<"content">>, Item, <<>>))
                || Item <- maps:get(<<"messages">>, Stored)],
    Session1 = Session0#{messages => Restored},

    Model = fun Loop(Request) ->
        Turn = integer_to_binary(length(maps:get(messages, Request))),
        {ok, praxo_models:response(
            praxo_models:message_assistant(<<"turn ", Turn/binary>>)),
         Loop}
    end,
    {ok, Result1, _} = praxo_agent:run_agent(
        praxo_agent:new_agent_options(Model), Session1, <<"second">>),
    <<"turn 3">> = maps:get(output, Result1),

    WithTurn = maps:get(messages, Session1) ++ [
        praxo_models:message(<<"user">>, <<"second">>),
        praxo_models:message(<<"assistant">>, maps:get(output, Result1))
    ],
    Messages2 = [praxo_models:message_wire(Message) || Message <- WithTurn],
    {ok, Payload2} = praxo_checkpoint:marshal(
        Allow, <<"session">>, #{<<"messages">> => Messages2}),
    {ok, Stored2} = praxo_checkpoint:unmarshal(Allow, Payload2),
    Restored2 = [praxo_models:message(
                     maps:get(<<"role">>, Item),
                     maps:get(<<"content">>, Item, <<>>))
                 || Item <- maps:get(<<"messages">>, Stored2)],
    Session2 = Session1#{messages => Restored2},

    {ok, Result2, _} = praxo_agent:run_agent(
        praxo_agent:new_agent_options(Model), Session2, <<"third">>),
    <<"turn 5">> = maps:get(output, Result2),
    io:format("restored messages: ~p~n", [length(Restored2)]),
    io:format("output: ~s~n", [maps:get(output, Result2)]).
