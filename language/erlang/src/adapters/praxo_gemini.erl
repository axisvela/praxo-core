-module(praxo_gemini).
-export([new/2, new/3, generate/2, model/1]).

new(Model, ApiKey) ->
    new(<<"https://generativelanguage.googleapis.com">>, Model, #{api_key => ApiKey}).

new(BaseUrl, Model, Options) ->
    #{
        base_url => strip_slashes(praxo_util:to_bin(BaseUrl)),
        model => praxo_util:to_bin(Model),
        api_key => maps:get(api_key, Options, undefined),
        max_output_tokens => maps:get(max_output_tokens, Options, 0),
        transport => maps:get(transport, Options, undefined),
        timeout => maps:get(timeout, Options, 60000)
    }.

generate(Adapter, Request) ->
    case maps:get(api_key, Adapter) of
        undefined -> {error, <<"MODEL_CONFIG">>, Adapter};
        <<>> -> {error, <<"MODEL_CONFIG">>, Adapter};
        _ ->
            case maps:get(model, Adapter) of
                <<>> -> {error, <<"MODEL_CONFIG">>, Adapter};
                _ ->
                    Payload = payload(Adapter, Request),
                    Path = <<"/v1beta/models/",
                             (maps:get(model, Adapter))/binary,
                             ":generateContent">>,
                    Result =
                        case maps:get(transport, Adapter) of
                            undefined -> post(Adapter, Path, Payload);
                            Transport -> Transport(Path, Payload)
                        end,
                    case Result of
                        {ok, Data} ->
                            case parse_response(Data) of
                                {ok, Response} -> {ok, Response, Adapter};
                                {error, Code} -> {error, Code, Adapter}
                            end;
                        {error, Code} -> {error, Code, Adapter};
                        {error, Code, Detail} -> {error, Code, Adapter#{last_error => Detail}}
                    end
            end
    end.

model(Adapter) ->
    fun(Request) -> generate(Adapter, Request) end.

payload(Adapter, Request) ->
    {System, Contents} = build_contents(maps:get(messages, Request, [])),
    Base0 = #{<<"contents">> => Contents},
    Base =
        case System of
            [] -> Base0;
            _ -> Base0#{<<"system_instruction">> => #{<<"parts">> => System}}
        end,
    WithTools =
        case maps:get(tools, Request, []) of
            [] -> Base;
            Tools ->
                Base#{
                    <<"tools">> => [#{
                        <<"functionDeclarations">> => [tool_payload(Tool) || Tool <- Tools]
                    }],
                    <<"toolConfig">> => #{
                        <<"functionCallingConfig">> => #{
                            <<"mode">> => tool_mode(maps:get(tool_choice, Request, undefined))
                        }
                    }
                }
        end,
    case maps:get(max_output_tokens, Adapter) of
        0 -> WithTools;
        Max -> WithTools#{<<"generationConfig">> => #{<<"maxOutputTokens">> => Max}}
    end.

build_contents(Messages) ->
    {System, Out, Pending, _Names} = build_contents(Messages, [], [], [], #{}),
    {System, Out ++ flush(Pending)}.

build_contents([], System, Out, Pending, Names) ->
    {System, Out, Pending, Names};
build_contents([Message | Rest], System, Out, Pending, Names) ->
    Role = maps:get(role, Message),
    case Role of
        <<"system">> ->
            Content = maps:get(content, Message, <<>>),
            System2 = case Content of
                <<>> -> System;
                _ -> System ++ [#{<<"text">> => Content}]
            end,
            build_contents(Rest, System2, Out, Pending, Names);
        <<"tool">> ->
            ToolId = default_bin(maps:get(tool_id, Message, <<>>)),
            Name = maps:get(ToolId, Names, case ToolId of
                <<>> -> <<"tool">>;
                _ -> ToolId
            end),
            Result = #{
                <<"functionResponse">> => #{
                    <<"name">> => Name,
                    <<"response">> => #{<<"result">> => default_bin(maps:get(content, Message, <<>>))}
                }
            },
            build_contents(Rest, System, Out, Pending ++ [Result], Names);
        _ ->
            Out2 = Out ++ flush(Pending),
            Parts = message_parts(Message),
            Out3 = case Parts of
                [] -> Out2;
                _ -> Out2 ++ [#{
                    <<"role">> => case Role of
                        <<"assistant">> -> <<"model">>;
                        _ -> <<"user">>
                    end,
                    <<"parts">> => Parts
                }]
            end,
            Names2 = lists:foldl(
                fun(Call, Acc) ->
                    Id = default_bin(maps:get(id, Call, <<>>)),
                    Name = default_bin(maps:get(name, Call, <<>>)),
                    case {Id, Name} of
                        {<<>>, _} -> Acc;
                        {_, <<>>} -> Acc;
                        _ -> Acc#{Id => Name}
                    end
                end,
                Names,
                maps:get(tool_calls, Message, [])
            ),
            build_contents(Rest, System, Out3, [], Names2)
    end.

flush([]) -> [];
flush(Pending) -> [#{<<"role">> => <<"user">>, <<"parts">> => Pending}].

message_parts(Message) ->
    Base = case default_bin(maps:get(content, Message, <<>>)) of
        <<>> -> [];
        Text -> [#{<<"text">> => Text}]
    end,
    Blocks = [
        #{<<"text">> => Text}
     || Block <- maps:get(content_blocks, Message, []),
        maps:get(kind, Block, <<>>) =:= <<"text">>,
        Text <- [maps:get(text, Block, <<>>)],
        is_binary(Text), Text =/= <<>>
    ],
    Calls = [
        #{<<"functionCall">> => #{
            <<"name">> => maps:get(name, Call, <<>>),
            <<"args">> => maps:get(arguments, Call, #{})
        }}
     || Call <- maps:get(tool_calls, Message, [])
    ],
    Base ++ Blocks ++ Calls.

tool_payload(Tool) ->
    #{
        <<"name">> => maps:get(name, Tool),
        <<"description">> => maps:get(description, Tool, <<>>),
        <<"parameters">> => maps:get(parameters, Tool, #{<<"type">> => <<"object">>})
    }.

tool_mode(<<"required">>) -> <<"ANY">>;
tool_mode(<<"none">>) -> <<"NONE">>;
tool_mode(_) -> <<"AUTO">>.

parse_response(Data) ->
    case praxo_json:get(Data, <<"error">>) of
        undefined ->
            case praxo_json:get_array(Data, <<"candidates">>) of
                [Candidate | _] when is_map(Candidate) ->
                    Content = praxo_json:get_object(Candidate, <<"content">>),
                    Parts = praxo_json:get_array(Content, <<"parts">>),
                    {Text, Calls} = parse_parts(Parts, [], []),
                    Usage = praxo_json:get_object(Data, <<"usageMetadata">>),
                    Response = praxo_models:response(
                        praxo_models:message_assistant(iolist_to_binary(Text), Calls),
                        praxo_models:usage(
                            praxo_json:get_int(Usage, <<"promptTokenCount">>, 0),
                            praxo_json:get_int(Usage, <<"candidatesTokenCount">>, 0)
                        )
                    ),
                    Finish = praxo_json:get_string(Candidate, <<"finishReason">>),
                    case Finish of
                        undefined -> {ok, Response};
                        _ -> {ok, Response#{finish_reason => Finish}}
                    end;
                _ ->
                    {error, <<"PROVIDER_HTTP">>}
            end;
        _ ->
            {error, <<"PROVIDER_HTTP">>}
    end.

parse_parts([], Text, Calls) ->
    {lists:reverse(Text), lists:reverse(Calls)};
parse_parts([Part | Rest], Text, Calls) ->
    Value = default_bin(praxo_json:get_string(Part, <<"text">>)),
    Text2 = case Value of
        <<>> -> Text;
        _ -> [Value | Text]
    end,
    case praxo_json:get(Part, <<"functionCall">>) of
        Call when is_map(Call) ->
            Tool = praxo_models:tool_call(
                <<"call-", (integer_to_binary(length(Calls) + 1))/binary>>,
                default_bin(praxo_json:get_string(Call, <<"name">>)),
                case praxo_json:get(Call, <<"args">>) of
                    Args when is_map(Args) -> Args;
                    _ -> #{}
                end
            ),
            parse_parts(Rest, Text2, [Tool | Calls]);
        _ ->
            parse_parts(Rest, Text2, Calls)
    end.

post(Adapter, Path, Payload) ->
    _ = application:ensure_all_started(inets),
    Url = binary_to_list(<<(maps:get(base_url, Adapter))/binary, Path/binary>>),
    Headers = [
        {"Content-Type", "application/json"},
        {"x-goog-api-key", binary_to_list(default_bin(maps:get(api_key, Adapter)))}
    ],
    Body = binary_to_list(praxo_json:encode(Payload)),
    HttpOptions = [{timeout, maps:get(timeout, Adapter)}],
    Options = [{body_format, binary}],
    case httpc:request(post, {Url, Headers, "application/json", Body}, HttpOptions, Options) of
        {ok, {{_, Status, _}, _ResponseHeaders, ResponseBody}}
                when Status >= 200, Status < 300 ->
            case praxo_json:parse(ResponseBody) of
                {ok, Data} -> {ok, Data};
                {error, _} -> {error, <<"PROVIDER_JSON">>}
            end;
        {ok, {{_, Status, _}, _ResponseHeaders, ResponseBody}} ->
            {error, <<"PROVIDER_HTTP">>, #{status => Status, body => bounded(ResponseBody)}};
        {error, _Reason} ->
            {error, <<"PROVIDER_HTTP">>}
    end.

default_bin(undefined) -> <<>>;
default_bin(Value) -> praxo_util:to_bin(Value).

bounded(Bin) when is_binary(Bin), byte_size(Bin) > 512 ->
    binary:part(Bin, 0, 512);
bounded(Bin) ->
    Bin.

strip_slashes(Bin) when byte_size(Bin) > 0 ->
    case binary:last(Bin) of
        $/ -> strip_slashes(binary:part(Bin, 0, byte_size(Bin) - 1));
        _ -> Bin
    end;
strip_slashes(Bin) ->
    Bin.
