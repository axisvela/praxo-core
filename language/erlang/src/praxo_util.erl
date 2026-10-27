-module(praxo_util).
-export([to_bin/1, default/2, index_of/2, join/2]).

to_bin(B) when is_binary(B) -> B;
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(I) when is_integer(I) -> integer_to_binary(I);
to_bin(L) when is_list(L) -> unicode:characters_to_binary(L).

default(undefined, Value) -> Value;
default(Value, _) -> Value.

index_of(Pred, List) -> index_of(Pred, List, 0).

index_of(_, [], _) -> undefined;
index_of(Pred, [Head | Tail], Index) ->
    case Pred(Head) of
        true -> Index;
        false -> index_of(Pred, Tail, Index + 1)
    end.

join([], _Separator) -> <<>>;
join([Head | Tail], Separator) ->
    lists:foldl(
        fun(Item, Acc) -> <<Acc/binary, Separator/binary, Item/binary>> end,
        Head,
        Tail
    ).
