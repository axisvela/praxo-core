-module(praxo_toolcall).
-export([parse_input_json/1, parse_tool_call/1, strip_tool_call_markup/1]).

parse_input_json(Raw) ->
    case praxo_json:parse(string:trim(Raw)) of
        {ok, Value} when is_map(Value) -> {ok, Value};
        _ -> error
    end.

parse_tool_call(Content) ->
    case parse_json_call(Content) of
        {ok, Call} -> {ok, Call};
        error ->
            case parse_xml(Content) of
                {ok, Call} -> {ok, Call};
                error ->
                    case parse_tag(Content) of
                        {ok, Call} -> {ok, Call};
                        error -> parse_plain(Content)
                    end
            end
    end.

parse_json_call(Content) ->
    case praxo_json:parse(Content) of
        {ok, Value} when is_map(Value) ->
            case praxo_json:get_string(Value, <<"name">>) of
                undefined -> error;
                <<>> -> error;
                Name ->
                    Input = praxo_json:get_object(Value, <<"input">>),
                    {ok, praxo_models:tool_call(<<>>, Name, Input)}
            end;
        _ ->
            error
    end.

parse_xml(Content) ->
    Pattern = <<"<tool_call\\s+name=\"([^\"]+)\"\\s*>\\s*(.*?)\\s*</tool_call>">>,
    case re:run(Content, Pattern, [unicode, dotall, global, {capture, all_but_first, binary}]) of
        nomatch ->
            error;
        {match, Matches} ->
            [_Name, Body] = lists:last(Matches),
            case parse_input_json(Body) of
                {ok, Input} -> {ok, praxo_models:tool_call(<<>>, _Name, Input)};
                error -> error
            end
    end.

parse_tag(Content) ->
    Pattern = <<"<([A-Za-z][\\w-]*(?:\\.[\\w-]+)+)>\\s*(\\{.*?)\\s*(?:</[A-Za-z][\\w.-]*>|$)">>,
    case re:run(Content, Pattern, [unicode, dotall, global, {capture, all_but_first, binary}]) of
        nomatch ->
            error;
        {match, Matches} ->
            [Name, Body] = lists:last(Matches),
            case parse_input_json(Body) of
                {ok, Input} -> {ok, praxo_models:tool_call(<<>>, Name, Input)};
                error -> error
            end
    end.

parse_plain(Content) ->
    Pattern = <<"^\\s*([A-Za-z][\\w.-]*)\\s+(\\{.*\\})\\s*$">>,
    case re:run(Content, Pattern, [unicode, multiline, global, {capture, all_but_first, binary}]) of
        nomatch ->
            error;
        {match, Matches} ->
            [Name, Body] = lists:last(Matches),
            case binary:match(Name, <<".">>) of
                nomatch ->
                    error;
                _ ->
                    case parse_input_json(Body) of
                        {ok, Input} -> {ok, praxo_models:tool_call(<<>>, Name, Input)};
                        error -> error
                    end
            end
    end.

strip_tool_call_markup(Content0) ->
    Content1 = re:replace(
        Content0,
        <<"<tool_call\\s+name=\"[^\"]+\"\\s*>.*?</tool_call>">>,
        <<>>,
        [unicode, dotall, global, {return, binary}]
    ),
    Content2 = re:replace(
        Content1,
        <<"<tool_call_invoke>.*?</tool_call_invoke>">>,
        <<>>,
        [unicode, dotall, global, {return, binary}]
    ),
    Content3 = re:replace(
        Content2,
        <<"<[A-Za-z][\\w-]*(?:\\.[\\w-]+)+>\\s*\\{.*?(?:</[A-Za-z][\\w.-]*>|$)">>,
        <<>>,
        [unicode, dotall, global, {return, binary}]
    ),
    Content4 = re:replace(
        Content3,
        <<"\\n{3,}">>,
        <<"\n\n">>,
        [unicode, global, {return, binary}]
    ),
    string:trim(Content4).
