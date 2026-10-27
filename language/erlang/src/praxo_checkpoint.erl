-module(praxo_checkpoint).
-export([new/0, register/2, marshal/3, unmarshal/2]).

new() ->
    #{registered => []}.

register(Allow, Kind) ->
    case Kind of
        <<>> -> erlang:error({checkpoint_error, <<"CHECKPOINT_ERROR">>});
        _ -> Allow#{registered => lists:usort([Kind | maps:get(registered, Allow)])}
    end.

marshal(Allow, Kind, Value) ->
    case lists:member(Kind, maps:get(registered, Allow)) of
        true ->
            {ok, praxo_json:encode(#{<<"type">> => Kind, <<"data">> => Value})};
        false ->
            {error, <<"CHECKPOINT_TYPE_NOT_ALLOWED">>}
    end.

unmarshal(Allow, Data) ->
    case praxo_json:parse(Data) of
        {ok, Envelope} when is_map(Envelope) ->
            Type = praxo_util:default(praxo_json:get_string(Envelope, <<"type">>), <<>>),
            case lists:member(Type, maps:get(registered, Allow)) of
                true -> {ok, maps:get(<<"data">>, Envelope, null)};
                false -> {error, <<"CHECKPOINT_TYPE_NOT_ALLOWED">>}
            end;
        _ ->
            {error, <<"CHECKPOINT_ERROR">>}
    end.
