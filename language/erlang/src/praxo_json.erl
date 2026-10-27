-module(praxo_json).
-export([
    parse/1,
    encode/1,
    get/2,
    get_string/2,
    get_bool/2,
    get_bool/3,
    get_int/2,
    get_int/3,
    get_array/2,
    get_object/2,
    is_null/1,
    equals/2
]).

parse(Text) when is_binary(Text) ->
    try
        {ok, json:decode(Text)}
    catch
        _:_ -> {error, invalid_json}
    end;
parse(_) ->
    {error, invalid_json}.

encode(Value) ->
    iolist_to_binary(json:encode(normalize(Value))).

normalize(Map) when is_map(Map) ->
    maps:from_list([{Key, normalize(Value)} || {Key, Value} <- maps:to_list(Map)]);
normalize(List) when is_list(List) ->
    [normalize(Value) || Value <- List];
normalize(undefined) ->
    null;
normalize(Value) ->
    Value.

get(Map, Key) when is_map(Map) -> maps:get(Key, Map, undefined);
get(_, _) -> undefined.

get_string(Map, Key) ->
    case get(Map, Key) of
        Value when is_binary(Value) -> Value;
        _ -> undefined
    end.

get_bool(Map, Key) -> get_bool(Map, Key, false).

get_bool(Map, Key, Fallback) ->
    case get(Map, Key) of
        Value when is_boolean(Value) -> Value;
        _ -> Fallback
    end.

get_int(Map, Key) -> get_int(Map, Key, 0).

get_int(Map, Key, Fallback) ->
    case get(Map, Key) of
        Value when is_integer(Value) ->
            Value;
        Value when is_float(Value) ->
            case Value == trunc(Value) of
                true -> trunc(Value);
                false -> Fallback
            end;
        _ ->
            Fallback
    end.

get_array(Map, Key) ->
    case get(Map, Key) of
        Value when is_list(Value) -> Value;
        _ -> []
    end.

get_object(Map, Key) ->
    case get(Map, Key) of
        Value when is_map(Value) -> Value;
        _ -> #{}
    end.

is_null(null) -> true;
is_null(_) -> false.

equals(Left, Right) when is_map(Left), is_map(Right) ->
    maps:size(Left) == maps:size(Right) andalso
        lists:all(
            fun({Key, Value}) ->
                case maps:find(Key, Right) of
                    {ok, Other} -> equals(Value, Other);
                    error -> false
                end
            end,
            maps:to_list(Left)
        );
equals(Left, Right) when is_list(Left), is_list(Right) ->
    length(Left) == length(Right) andalso
        lists:all(fun({A, B}) -> equals(A, B) end, lists:zip(Left, Right));
equals(Left, Right) when is_number(Left), is_number(Right) ->
    Left == Right;
equals(Left, Right) ->
    Left =:= Right.
