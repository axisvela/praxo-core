#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    Schema = #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"name">>],
        <<"properties">> => #{<<"name">> => #{<<"type">> => <<"string">>}}
    },
    Config = praxo_middleware:structured_output(Schema, 0),
    {ok, <<"{\"name\":\"ok\"}">>} =
        praxo_middleware:apply_structured(Config, <<"{\"name\":\"ok\"}">>),
    {error, <<"AGENT_STRUCTURED_OUTPUT">>} =
        praxo_middleware:apply_structured(Config, <<"{}">>),
    io:format("Erlang structured output example passed~n").
