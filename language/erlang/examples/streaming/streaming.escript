#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    put(streams, []),
    Options = (praxo_agent:new_agent_options(
        praxo_agent:static_model(<<"done">>)))#{
        on_stream => fun(Part) ->
            put(streams, get(streams) ++ [maps:get(kind, Part)])
        end
    },
    {ok, Result, _Options} = praxo_agent:run_agent(
        Options, praxo_models:session(<<"streaming">>), <<"go">>),
    <<"done">> = maps:get(output, Result),
    [<<"values">>, <<"messages">>] = get(streams),
    io:format("Erlang streaming example passed~n").
