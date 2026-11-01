-module(praxo_sse).
-export([parse/1]).

parse(Text) when is_binary(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    case parse_lines(Lines, <<>>, false) of
        {ok, Content, true} -> {ok, Content};
        _ -> {error, <<"MODEL_STREAM">>}
    end;
parse(_) ->
    {error, <<"MODEL_STREAM">>}.

parse_lines([], Content, Done) ->
    {ok, Content, Done};
parse_lines([Raw | Rest], Content, Done) ->
    Line = string:trim(Raw),
    case Line of
        <<"data:", RestLine/binary>> ->
            Chunk = string:trim(RestLine),
            case Chunk of
                <<>> ->
                    parse_lines(Rest, Content, Done);
                <<"[DONE]">> ->
                    {ok, Content, true};
                _ ->
                    case praxo_json:parse(Chunk) of
                        {error, _} ->
                            {error, <<"MODEL_STREAM">>};
                        {ok, Event} ->
                            {Content1, Done1} = collect(Event, Content, Done),
                            case Done1 of
                                true -> {ok, Content1, true};
                                false -> parse_lines(Rest, Content1, false)
                            end
                    end
            end;
        _ ->
            parse_lines(Rest, Content, Done)
    end.

collect(Event, Content, Done) when is_map(Event) ->
    Choices =
        case maps:get(<<"choices">>, Event, []) of
            List when is_list(List) -> List;
            _ -> []
        end,
    lists:foldl(
        fun(Choice, {Acc, DoneAcc}) ->
            Delta =
                case is_map(Choice) of
                    true ->
                        case maps:get(<<"delta">>, Choice, #{}) of
                            Map when is_map(Map) -> Map;
                            _ -> #{}
                        end;
                    false ->
                        #{}
                end,
            Text = maps:get(<<"content">>, Delta, undefined),
            Acc1 =
                case is_binary(Text) of
                    true -> <<Acc/binary, Text/binary>>;
                    false -> Acc
                end,
            Finish =
                case is_map(Choice) of
                    true -> maps:get(<<"finish_reason">>, Choice, undefined);
                    false -> undefined
                end,
            DoneAcc1 =
                DoneAcc orelse
                    (is_map(Choice) andalso
                        maps:is_key(<<"finish_reason">>, Choice) andalso
                        Finish =/= undefined andalso Finish =/= null),
            {Acc1, DoneAcc1}
        end,
        {Content, Done},
        Choices
    );
collect(_, Content, Done) ->
    {Content, Done}.
