-module(praxo_memory).
-export([new/0, put/3, search/4]).

new() ->
    #{records => #{}, sequence => 0}.

put(Store, SessionId, Record) ->
    Sequence = maps:get(sequence, Store),
    {Record1, Sequence1} =
        case maps:get(id, Record) of
            <<>> ->
                Time = integer_to_binary(erlang:system_time(second)),
                Id = <<"mem-", Time/binary, "-", (integer_to_binary(Sequence))/binary>>,
                {Record#{id => Id}, Sequence + 1};
            _ ->
                {Record, Sequence}
        end,
    Record2 =
        case maps:get(created_at, Record1) of
            undefined ->
                Record1#{created_at => integer_to_binary(erlang:system_time(second))};
            _ ->
                Record1
        end,
    Records0 = maps:get(records, Store),
    Existing = maps:get(SessionId, Records0, []),
    Records = Records0#{SessionId => Existing ++ [Record2]},
    {Store#{records => Records, sequence => Sequence1}, Record2}.

search(Store, SessionId, Query, Limit) ->
    Needle = string:lowercase(string:trim(Query)),
    Records = maps:get(SessionId, maps:get(records, Store), []),
    Matches = [
        Record
     || Record <- Records,
        Needle == <<>> orelse
            binary:match(string:lowercase(maps:get(content, Record)), Needle) =/= nomatch
    ],
    Sorted = lists:sort(
        fun(Left, Right) ->
            maps:get(created_at, Left) > maps:get(created_at, Right)
        end,
        Matches
    ),
    case Limit > 0 of
        true -> lists:sublist(Sorted, Limit);
        false -> Sorted
    end.
