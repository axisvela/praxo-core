#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    Allow0 = praxo_checkpoint:new(),
    Allow = praxo_checkpoint:register(Allow0, <<"order">>),
    {ok, Data} = praxo_checkpoint:marshal(
        Allow, <<"order">>, #{<<"value">> => <<"x">>}),
    {ok, Value} = praxo_checkpoint:unmarshal(Allow, Data),
    case Value of
        #{<<"value">> := <<"x">>} -> ok;
        _ -> erlang:error({unexpected_value, Value})
    end,
    {error, <<"CHECKPOINT_TYPE_NOT_ALLOWED">>} =
        praxo_checkpoint:marshal(Allow, <<"missing">>, #{}),
    io:format("Erlang checkpoint example passed~n").
