-module(praxo_jsonschema).
-export([validate/2]).

validate(Schema, Data) ->
    visit(Schema, Data, <<"$">>, []).

visit(Schema, Data, Path, Errors) when is_map(Schema) ->
    Kind = praxo_util:default(praxo_json:get_string(Schema, <<"type">>), <<>>),
    case praxo_json:is_null(Data) of
        true ->
            case Kind of
                <<>> -> Errors;
                _ -> add(Errors, Path, <<"expected ", Kind/binary, ", got null">>)
            end;
        false ->
            case Kind of
                <<"object">> -> visit_object(Schema, Data, Path, Errors);
                <<"array">> -> visit_array(Schema, Data, Path, Errors);
                <<"string">> -> visit_string(Schema, Data, Path, Errors);
                <<"number">> -> visit_number(Schema, Kind, Data, Path, Errors);
                <<"integer">> -> visit_number(Schema, Kind, Data, Path, Errors);
                <<"boolean">> -> visit_boolean(Schema, Data, Path, Errors);
                _ -> Errors
            end
    end;
visit(_, _, _, Errors) ->
    Errors.

visit_object(Schema, Data, Path, Errors) ->
    case is_map(Data) of
        false ->
            add(Errors, Path, <<"expected object">>);
        true ->
            Errors1 = lists:foldl(
                fun(Name, Acc) ->
                    case is_binary(Name) andalso not maps:is_key(Name, Data) of
                        true -> add(Acc, <<Path/binary, ".", Name/binary>>, <<"required field missing">>);
                        false -> Acc
                    end
                end,
                Errors,
                praxo_json:get_array(Schema, <<"required">>)
            ),
            Properties = praxo_json:get_object(Schema, <<"properties">>),
            maps:fold(
                fun(Name, Child, Acc) ->
                    case maps:is_key(Name, Data) andalso is_map(Child) of
                        true ->
                            visit(Child, maps:get(Name, Data), <<Path/binary, ".", Name/binary>>, Acc);
                        false ->
                            Acc
                    end
                end,
                Errors1,
                Properties
            )
    end.

visit_array(Schema, Data, Path, Errors) ->
    case is_list(Data) of
        false ->
            add(Errors, Path, <<"expected array">>);
        true ->
            case praxo_json:get(Schema, <<"items">>) of
                Items when is_map(Items) ->
                    {_, Result} = lists:foldl(
                        fun(Value, {Index, Acc}) ->
                            {
                                Index + 1,
                                visit(
                                    Items,
                                    Value,
                                    <<Path/binary, "[", (integer_to_binary(Index))/binary, "]">>,
                                    Acc
                                )
                            }
                        end,
                        {0, Errors},
                        Data
                    ),
                    Result;
                _ ->
                    Errors
            end
    end.

visit_string(Schema, Data, Path, Errors) ->
    case is_binary(Data) of
        false ->
            add(Errors, Path, <<"expected string">>);
        true ->
            Length = codepoint_length(Data),
            Minimum = praxo_json:get_int(Schema, <<"minLength">>, 0),
            Maximum = praxo_json:get_int(Schema, <<"maxLength">>, 0),
            Errors1 =
                case Minimum > 0 andalso Length < Minimum of
                    true ->
                        add(
                            Errors,
                            Path,
                            <<"min length ",
                                (integer_to_binary(Minimum))/binary,
                                ", got ",
                                (integer_to_binary(Length))/binary>>
                        );
                    false ->
                        Errors
                end,
            Errors2 =
                case Maximum > 0 andalso Length > Maximum of
                    true ->
                        add(
                            Errors1,
                            Path,
                            <<"max length ",
                                (integer_to_binary(Maximum))/binary,
                                ", got ",
                                (integer_to_binary(Length))/binary>>
                        );
                    false ->
                        Errors1
                end,
            Errors3 =
                case praxo_json:get_string(Schema, <<"pattern">>) of
                    undefined ->
                        Errors2;
                    Pattern ->
                        case re:compile(Pattern, [unicode]) of
                            {ok, Expression} ->
                                case re:run(Data, Expression, [{capture, none}]) of
                                    match -> Errors2;
                                    nomatch -> add(Errors2, Path, <<"pattern '", Pattern/binary, "' not matched">>)
                                end;
                            {error, _} ->
                                add(Errors2, Path, <<"invalid pattern '", Pattern/binary, "'">>)
                        end
                end,
            check_enum(Schema, Data, Path, Errors3)
    end.

visit_number(Schema, Kind, Data, Path, Errors) ->
    case is_integer(Data) orelse is_float(Data) of
        false ->
            add(Errors, Path, <<"expected number">>);
        true ->
            case Kind == <<"integer">> andalso is_float(Data) andalso Data /= trunc(Data) of
                true ->
                    add(
                        Errors,
                        Path,
                        <<"expected integer, got ", (float_to_binary(Data))/binary>>
                    );
                false ->
                    Errors1 = check_enum(Schema, Data, Path, Errors),
                    Errors2 =
                        case praxo_json:get(Schema, <<"minimum">>) of
                            Minimum when is_integer(Minimum); is_float(Minimum) ->
                                case Minimum /= 0 andalso Data < Minimum of
                                    true -> add(Errors1, Path, <<"value below minimum">>);
                                    false -> Errors1
                                end;
                            _ ->
                                Errors1
                        end,
                    case praxo_json:get(Schema, <<"maximum">>) of
                        Maximum when is_integer(Maximum); is_float(Maximum) ->
                            case Maximum /= 0 andalso Data > Maximum of
                                true -> add(Errors2, Path, <<"value above maximum">>);
                                false -> Errors2
                            end;
                        _ ->
                            Errors2
                    end
            end
    end.

visit_boolean(Schema, Data, Path, Errors) ->
    case is_boolean(Data) of
        false -> add(Errors, Path, <<"expected boolean">>);
        true -> check_enum(Schema, Data, Path, Errors)
    end.

check_enum(Schema, Data, Path, Errors) ->
    Values = praxo_json:get_array(Schema, <<"enum">>),
    case Values of
        [] ->
            Errors;
        _ ->
            case lists:any(fun(Value) -> praxo_json:equals(Value, Data) end, Values) of
                true -> Errors;
                false -> add(Errors, Path, <<"value not in enum">>)
            end
    end.

add(Errors, Path, Message) ->
    Errors ++ [#{path => Path, message => Message}].

codepoint_length(Value) ->
    case unicode:characters_to_list(Value) of
        List when is_list(List) -> length(List);
        _ -> byte_size(Value)
    end.
