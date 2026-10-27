-module(praxo_runtime).
-export([
    normalize_path/1,
    path_checker/1,
    check/3,
    path_allowed/3,
    estimate_tokens/1,
    truncate_to_tokens/2,
    compact_context/2,
    stream_kinds/0
]).

normalize_path(Value) ->
    Path0 = binary:replace(Value, <<"\\">>, <<"/">>, [global]),
    {Prefix, Body, Absolute} =
        case byte_size(Path0) >= 2 andalso binary:at(Path0, 1) == $: of
            true ->
                Body0 = binary:part(Path0, 2, byte_size(Path0) - 2),
                IsAbsolute = starts_with(Body0, <<"/">>),
                Drive = binary:part(Path0, 0, 2),
                Suffix = case IsAbsolute of true -> <<"/">>; false -> <<>> end,
                {<<Drive/binary, Suffix/binary>>, Body0, IsAbsolute};
            false ->
                case starts_with(Path0, <<"/">>) of
                    true -> {<<"/">>, Path0, true};
                    false -> {<<>>, Path0, false}
                end
        end,
    Parts = reduce_parts(binary:split(Body, <<"/">>, [global]), [], Absolute),
    Result = <<Prefix/binary, (praxo_util:join(Parts, <<"/">>))/binary>>,
    case os:type() of
        {win32, _} -> string:lowercase(Result);
        _ -> Result
    end.

reduce_parts([], Acc, _Absolute) -> lists:reverse(Acc);
reduce_parts([<<>> | Tail], Acc, Absolute) -> reduce_parts(Tail, Acc, Absolute);
reduce_parts([<<".">> | Tail], Acc, Absolute) -> reduce_parts(Tail, Acc, Absolute);
reduce_parts([<<"..">> | Tail], [], true) -> reduce_parts(Tail, [], true);
reduce_parts([<<"..">> | Tail], [], false) -> reduce_parts(Tail, [<<"..">>], false);
reduce_parts([<<"..">> | Tail], [<<"..">> | _] = Acc, Absolute) ->
    reduce_parts(Tail, [<<"..">> | Acc], Absolute);
reduce_parts([<<"..">> | Tail], [_ | Rest], Absolute) -> reduce_parts(Tail, Rest, Absolute);
reduce_parts([Part | Tail], Acc, Absolute) -> reduce_parts(Tail, [Part | Acc], Absolute).

path_checker(Grants) ->
    #{grants => [normalize_grant(Grant) || Grant <- Grants]}.

normalize_grant(#{root := Root, access := Access}) ->
    case Root of
        <<>> -> erlang:error({policy_error, <<"POLICY_ERROR">>});
        _ -> ok
    end,
    case lists:member(Access, [<<"read">>, <<"write">>, <<"readwrite">>]) of
        true -> ok;
        false -> erlang:error({policy_error, <<"POLICY_ERROR">>})
    end,
    #{root => normalize_path(Root), access => Access}.

check(#{grants := Grants}, Target, Need) ->
    case lists:member(Need, [<<"read">>, <<"write">>, <<"readwrite">>]) of
        true -> ok;
        false -> erlang:error({policy_error, <<"POLICY_ERROR">>})
    end,
    case Grants of
        [] ->
            praxo_models:decision(false, <<"no allowed roots">>);
        _ ->
            Resolved = normalize_path(Target),
            case find_grant(Grants, Resolved, Need) of
                {ok, _} ->
                    praxo_models:decision(true, <<"allowed">>);
                error ->
                    case lists:any(
                        fun(Grant) -> path_within(maps:get(root, Grant), Resolved) end,
                        Grants
                    ) of
                        true -> praxo_models:decision(false, <<"insufficient grant">>);
                        false -> praxo_models:decision(false, <<"outside roots">>)
                    end
            end
    end.

find_grant([], _Resolved, _Need) -> error;
find_grant([Grant | Tail], Resolved, Need) ->
    case path_within(maps:get(root, Grant), Resolved) andalso
        access_allows(maps:get(access, Grant), Need) of
        true -> {ok, Grant};
        false -> find_grant(Tail, Resolved, Need)
    end.

path_allowed(Checker, Target, Need) ->
    try check(Checker, Target, Need) of
        #{allowed := Allowed} -> Allowed
    catch
        error:{policy_error, _} -> false
    end.

path_within(Root, Target) ->
    Root == Target orelse
        (starts_with(Target, <<Root/binary, "/">>) andalso
            byte_size(Target) > byte_size(Root)).

access_allows(<<"readwrite">>, _) -> true;
access_allows(<<"read">>, <<"read">>) -> true;
access_allows(<<"write">>, <<"write">>) -> true;
access_allows(_, _) -> false.

estimate_tokens(Messages) ->
    lists:foldl(
        fun(Message, Total) ->
            Content = maps:get(content, Message),
            ToolId = praxo_util:default(maps:get(tool_id, Message), <<>>),
            Total1 = Total + 4 + (byte_size(Content) div 4) + (byte_size(ToolId) div 4),
            Total2 = lists:foldl(
                fun(Block, Acc) ->
                    Text = praxo_util:default(maps:get(text, Block), <<>>),
                    Acc + 4 + (byte_size(Text) div 4)
                end,
                Total1,
                maps:get(content_blocks, Message)
            ),
            lists:foldl(
                fun(Call, Acc) ->
                    Acc + 4 +
                        (byte_size(maps:get(name, Call)) div 4) +
                        (byte_size(praxo_json:encode(maps:get(arguments, Call))) div 4)
                end,
                Total2,
                maps:get(tool_calls, Message)
            )
        end,
        0,
        Messages
    ).

truncate_to_tokens(Value, Tokens) ->
    case Tokens =< 0 of
        true ->
            <<>>;
        false ->
            Limit = Tokens * 4,
            case byte_size(Value) =< Limit of
                true -> Value;
                false ->
                    case Limit =< 16 of
                        true -> binary:part(Value, 0, Limit);
                        false ->
                            <<(binary:part(Value, 0, Limit - 16))/binary, "\n[truncated]">>
                    end
            end
    end.

compact_context(#{max_tokens := MaxTokens} = Budget, Messages) ->
    case MaxTokens =< 0 orelse estimate_tokens(Messages) =< MaxTokens of
        true ->
            {Messages, true};
        false ->
            {System0, Rest} = lists:partition(
                fun(Message) -> maps:get(role, Message) == <<"system">> end,
                Messages
            ),
            System = [
                Message
             || Message <- System0,
                not starts_with(maps:get(content, Message), <<"[context compacted:">>)
            ],
            case fit_system(System, MaxTokens) of
                {error, _} ->
                    {[], false};
                {ok, FittedSystem} ->
                    KeepRecent = maps:get(keep_recent, Budget),
                    Keep = case KeepRecent > 0 of true -> KeepRecent; false -> 4 end,
                    Start = align_start(Rest, max(length(Rest) - Keep, 0)),
                    Marker = praxo_models:message(
                        <<"system">>,
                        <<"[context compacted: ",
                            (integer_to_binary(Start))/binary,
                            " older messages omitted]">>
                    ),
                    Kept = lists:nthtail(Start, Rest),
                    Output =
                        FittedSystem ++
                            (case Start > 0 of true -> [Marker]; false -> [] end) ++
                            Kept,
                    shrink(Output, Kept, FittedSystem, Marker, Start, MaxTokens)
            end
    end.

fit_system([], _Max) -> {ok, []};
fit_system(System, Max) ->
    case estimate_tokens(System) > Max of
        false ->
            {ok, System};
        true ->
            [First | _] = System,
            Content = truncate_to_tokens(maps:get(content, First), Max - 4),
            Trimmed = [First#{content => Content}],
            case estimate_tokens(Trimmed) > Max of
                true -> {error, too_large};
                false -> {ok, Trimmed}
            end
    end.

align_start(_Rest, 0) -> 0;
align_start(Rest, Start) ->
    case maps:get(role, lists:nth(Start + 1, Rest)) == <<"tool">> of
        true -> align_start(Rest, Start - 1);
        false -> Start
    end.

shrink(Output, Kept, System, Marker, Start, Max) ->
    case estimate_tokens(Output) > Max andalso length(Kept) > 1 of
        true ->
            case maps:get(role, lists:nth(2, Kept)) == <<"tool">> of
                true ->
                    {Output, false};
                false ->
                    Kept2 = tl(Kept),
                    Output2 =
                        System ++
                            (case Start > 0 of true -> [Marker]; false -> [] end) ++
                            Kept2,
                    shrink(Output2, Kept2, System, Marker, Start, Max)
            end;
        false ->
            {Output, estimate_tokens(Output) =< Max}
    end.

stream_kinds() ->
    praxo_models:stream_kinds().

starts_with(Binary, Prefix) ->
    byte_size(Binary) >= byte_size(Prefix) andalso
        binary:part(Binary, 0, byte_size(Prefix)) == Prefix.
