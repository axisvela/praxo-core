#!/usr/bin/env escript
main(_) ->
    {200, #{<<"status">> := <<"ok">>}} = handle(<<"GET">>, <<"/healthz">>, undefined, <<>>),
    {401, _} = handle(<<"POST">>, <<"/run">>, undefined, <<"{\"prompt\":\"hi\"}">>),
    {200, #{<<"output">> := <<"hello from the service">>}} =
        handle(<<"POST">>, <<"/run">>, <<"user-1">>, <<"{\"prompt\":\"hi\"}">>),
    io:format("Erlang service example passed~n").

handle(<<"GET">>, <<"/healthz">>, _Principal, _Body) ->
    {200, #{<<"status">> => <<"ok">>}};
handle(Method, Path, _Principal, _Body) when Method =/= <<"POST">>; Path =/= <<"/run">> ->
    {404, #{<<"error">> => <<"not found">>}};
handle(<<"POST">>, <<"/run">>, undefined, _Body) ->
    {401, #{<<"error">> => <<"missing X-Praxo-Principal">>}};
handle(<<"POST">>, <<"/run">>, <<>>, _Body) ->
    {401, #{<<"error">> => <<"missing X-Praxo-Principal">>}};
handle(<<"POST">>, <<"/run">>, _Principal, Body) ->
    case binary:match(Body, <<"\"prompt\"">>) of
        nomatch -> {400, #{<<"error">> => <<"prompt is required">>}};
        _ -> {200, #{<<"output">> => <<"hello from the service">>}}
    end.
