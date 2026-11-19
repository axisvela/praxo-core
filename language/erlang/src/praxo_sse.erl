-module(praxo_sse).
-export([parse/1, parse_response/2]).

parse(Text) when is_binary(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    case parse_lines(Lines, <<>>, false) of
        {ok, Content, true} -> {ok, Content};
        _ -> {error, <<"MODEL_STREAM">>}
    end;
parse(_) ->
    {error, <<"MODEL_STREAM">>}.

parse_response(Text, OnDelta) when is_binary(Text), is_function(OnDelta, 1) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    State = #{
        content => <<>>,
        tool_calls => #{},
        usage => #{input => 0, output => 0},
        finish_reason => undefined
    },
    case parse_response_lines(Lines, State, false, OnDelta) of
        {ok, Final, true} -> finalize_response(Final);
        {ok, Final, false} ->
            case maps:get(finish_reason, Final) of
                undefined -> {error, <<"MODEL_STREAM">>};
                _ -> finalize_response(Final)
            end;
        {error, Code} -> {error, Code}
    end;
parse_response(_, _) ->
    {error, <<"MODEL_STREAM">>}.

parse_response_lines([], State, Done, _OnDelta) ->
    {ok, State, Done};
parse_response_lines([Raw | Rest], State, Done, OnDelta) ->
    Line = string:trim(Raw),
    case Line of
        <<"data:", RestLine/binary>> ->
            Chunk = string:trim(RestLine),
            case Chunk of
                <<>> ->
                    parse_response_lines(Rest, State, Done, OnDelta);
                <<"[DONE]">> ->
                    {ok, State, true};
                _ ->
                    case praxo_json:parse(Chunk) of
                        {error, _} ->
                            {error, <<"MODEL_STREAM">>};
                        {ok, Event} ->
                            case apply_event(Event, State, OnDelta) of
                                {ok, State1, Done1} ->
                                    case Done1 of
                                        true -> {ok, State1, true};
                                        false -> parse_response_lines(Rest, State1, false, OnDelta)
                                    end;
                                {error, Code} ->
                                    {error, Code}
                            end
                    end
            end;
        _ ->
            parse_response_lines(Rest, State, Done, OnDelta)
    end.

apply_event(Event, State, OnDelta) when is_map(Event) ->
    State1 = apply_usage(Event, State),
    Choices =
        case maps:get(<<"choices">>, Event, []) of
            List when is_list(List) -> List;
            _ -> []
        end,
    lists:foldl(
        fun(Choice, {ok, Acc, DoneAcc}) when is_map(Choice) ->
                Delta =
                    case maps:get(<<"delta">>, Choice, #{}) of
                        Map when is_map(Map) -> Map;
                        _ -> #{}
                    end,
                Text = maps:get(<<"content">>, Delta, undefined),
                case apply_delta(Text, OnDelta) of
                    ok ->
                        Acc1 = append_content(Acc, Text),
                        Acc2 = apply_tool_calls(Delta, Acc1),
                        Finish = maps:get(<<"finish_reason">>, Choice, undefined),
                        DoneAcc1 = DoneAcc orelse
                            (Finish =/= undefined andalso Finish =/= null),
                        Acc3 =
                            case Finish of
                                undefined -> Acc2;
                                null -> Acc2;
                                _ -> Acc2#{finish_reason => Finish}
                            end,
                        {ok, Acc3, DoneAcc1};
                    {error, Code} ->
                        {error, Code}
                end;
           (_Choice, {ok, Acc, DoneAcc}) ->
                {ok, Acc, DoneAcc};
           (_Choice, Error) ->
                Error
        end,
        {ok, State1, false},
        Choices
    );
apply_event(_Event, State, _OnDelta) ->
    {ok, State, false}.

apply_usage(Event, State) ->
    case maps:get(<<"usage">>, Event, undefined) of
        Usage when is_map(Usage) ->
            Input = praxo_json:get_int(Usage, <<"prompt_tokens">>, 0),
            Output = praxo_json:get_int(Usage, <<"completion_tokens">>, 0),
            State#{usage => #{input => Input, output => Output}};
        _ ->
            State
    end.

apply_delta(Text, OnDelta) when is_binary(Text) ->
    case OnDelta(Text) of
        {error, Code} -> {error, Code};
        _ -> ok
    end;
apply_delta(_Text, _OnDelta) ->
    ok.

append_content(State, Text) when is_binary(Text) ->
    Content = maps:get(content, State),
    State#{content => <<Content/binary, Text/binary>>};
append_content(State, _Text) ->
    State.

apply_tool_calls(Delta, State) ->
    case maps:get(<<"tool_calls">>, Delta, []) of
        Calls when is_list(Calls) ->
            lists:foldl(fun apply_tool_call/2, State, Calls);
        _ ->
            State
    end.

apply_tool_call(Item, State) when is_map(Item) ->
    Calls = maps:get(tool_calls, State),
    Index = praxo_json:get_int(Item, <<"index">>, maps:size(Calls)),
    Entry = maps:get(Index, Calls, #{id => <<>>, name => <<>>, arguments => <<>>}),
    Function =
        case maps:get(<<"function">>, Item, #{}) of
            Map when is_map(Map) -> Map;
            _ -> #{}
        end,
    Entry1 = Entry#{
        id => <<(maps:get(id, Entry))/binary,
            (default_bin(praxo_json:get_string(Item, <<"id">>)))/binary>>,
        name => <<(maps:get(name, Entry))/binary,
            (default_bin(praxo_json:get_string(Function, <<"name">>)))/binary>>,
        arguments => <<(maps:get(arguments, Entry))/binary,
            (default_bin(praxo_json:get_string(Function, <<"arguments">>)))/binary>>
    },
    State#{tool_calls => Calls#{Index => Entry1}};
apply_tool_call(_Item, State) ->
    State.

finalize_response(State) ->
    CallsMap = maps:get(tool_calls, State),
    Indices = lists:sort(maps:keys(CallsMap)),
    case build_calls(Indices, CallsMap, []) of
        {ok, Calls} -> {ok, State#{tool_calls => Calls}};
        {error, Code} -> {error, Code}
    end.

build_calls([], _CallsMap, Acc) ->
    {ok, lists:reverse(Acc)};
build_calls([Index | Rest], CallsMap, Acc) ->
    Entry = maps:get(Index, CallsMap),
    case maps:get(name, Entry) of
        <<>> ->
            build_calls(Rest, CallsMap, Acc);
        Name ->
            case parse_arguments(maps:get(arguments, Entry)) of
                {ok, Arguments} ->
                    build_calls(Rest, CallsMap, [
                        #{id => maps:get(id, Entry), name => Name, arguments => Arguments}
                        | Acc
                    ]);
                {error, Code} ->
                    {error, Code}
            end
    end.

parse_arguments(<<>>) ->
    {ok, #{}};
parse_arguments(Raw) when is_binary(Raw) ->
    case praxo_json:parse(Raw) of
        {ok, Value} when is_map(Value) -> {ok, Value};
        _ -> {error, <<"PROVIDER_JSON">>}
    end.

default_bin(undefined) -> <<>>;
default_bin(Value) -> Value.

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
