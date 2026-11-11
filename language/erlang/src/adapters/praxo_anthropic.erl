-module(praxo_anthropic).
-export([new/2, new/3, generate/2, model/1]).

new(Model, ApiKey) ->
    new(<<"https://api.anthropic.com">>, Model, #{api_key => ApiKey}).

new(BaseUrl, Model, Options) ->
    #{
        base_url => strip_slashes(praxo_util:to_bin(BaseUrl)),
        model => praxo_util:to_bin(Model),
        api_key => maps:get(api_key, Options, undefined),
        version => maps:get(version, Options, <<"2023-06-01">>),
        max_tokens => maps:get(max_tokens, Options, 1024),
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
                    Path = <<"/v1/messages">>,
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
    {System, Messages} = build_messages(maps:get(messages, Request, [])),
    Base0 = #{
        <<"model">> => maps:get(model, Adapter),
        <<"max_tokens">> => maps:get(max_tokens, Adapter),
        <<"messages">> => Messages
    },
    Base =
        case System of
            <<>> -> Base0;
            _ -> Base0#{<<"system">> => System}
        end,
    case maps:get(tools, Request, []) of
        [] -> Base;
        Tools ->
            Base#{
                <<"tools">> => [tool_payload(Tool) || Tool <- Tools],
                <<"tool_choice">> => tool_choice(maps:get(tool_choice, Request, undefined))
            }
    end.

build_messages(Messages) ->
    {System, Out, Pending} = build_messages(Messages, [], [], []),
    {iolist_to_binary(lists:join(<<"\n\n">>, System)), Out ++ flush(Pending)}.

build_messages([], System, Out, Pending) ->
    {System, Out, Pending};
build_messages([Message | Rest], System, Out, Pending) ->
    Role = maps:get(role, Message),
    case Role of
        <<"system">> ->
            Content = maps:get(content, Message, <<>>),
            System2 = case Content of
                <<>> -> System;
                _ -> System ++ [Content]
            end,
            build_messages(Rest, System2, Out, Pending);
        <<"tool">> ->
            Result = #{
                <<"type">> => <<"tool_result">>,
                <<"tool_use_id">> => default_bin(maps:get(tool_id, Message, <<>>)),
                <<"content">> => default_bin(maps:get(content, Message, <<>>))
            },
            build_messages(Rest, System, Out, Pending ++ [Result]);
        _ ->
            Out2 = Out ++ flush(Pending),
            Content = message_content(Message),
            Out3 = case Content of
                [] -> Out2;
                _ -> Out2 ++ [#{<<"role">> => Role, <<"content">> => Content}]
            end,
            build_messages(Rest, System, Out3, [])
    end.

flush([]) -> [];
flush(Pending) -> [#{<<"role">> => <<"user">>, <<"content">> => Pending}].

message_content(Message) ->
    Base = case default_bin(maps:get(content, Message, <<>>)) of
        <<>> -> [];
        Text -> [#{<<"type">> => <<"text">>, <<"text">> => Text}]
    end,
    Blocks = [
        #{<<"type">> => <<"text">>, <<"text">> => Text}
     || Block <- maps:get(content_blocks, Message, []),
        maps:get(kind, Block, <<>>) =:= <<"text">>,
        Text <- [maps:get(text, Block, <<>>)],
        is_binary(Text), Text =/= <<>>
    ],
    Calls = [
        #{
            <<"type">> => <<"tool_use">>,
            <<"id">> => maps:get(id, Call, <<>>),
            <<"name">> => maps:get(name, Call, <<>>),
            <<"input">> => maps:get(arguments, Call, #{})
        }
     || Call <- maps:get(tool_calls, Message, [])
    ],
    Base ++ Blocks ++ Calls.

tool_payload(Tool) ->
    #{
        <<"name">> => maps:get(name, Tool),
        <<"description">> => maps:get(description, Tool, <<>>),
        <<"input_schema">> => maps:get(parameters, Tool, #{<<"type">> => <<"object">>})
    }.

tool_choice(undefined) -> #{<<"type">> => <<"auto">>};
tool_choice(<<"auto">>) -> #{<<"type">> => <<"auto">>};
tool_choice(<<"required">>) -> #{<<"type">> => <<"any">>};
tool_choice(<<"none">>) -> #{<<"type">> => <<"none">>};
tool_choice(_) -> #{<<"type">> => <<"auto">>}.

parse_response(Data) ->
    case praxo_json:get(Data, <<"error">>) of
        undefined ->
            Blocks = praxo_json:get_array(Data, <<"content">>),
            {Text, Calls} = parse_blocks(Blocks, [], []),
            Usage = praxo_json:get_object(Data, <<"usage">>),
            Response = praxo_models:response(
                praxo_models:message_assistant(iolist_to_binary(Text), Calls),
                praxo_models:usage(
                    praxo_json:get_int(Usage, <<"input_tokens">>, 0),
                    praxo_json:get_int(Usage, <<"output_tokens">>, 0)
                )
            ),
            Finish = praxo_json:get_string(Data, <<"stop_reason">>),
            case Finish of
                undefined -> {ok, Response};
                _ -> {ok, Response#{finish_reason => Finish}}
            end;
        _ ->
            {error, <<"PROVIDER_HTTP">>}
    end.

parse_blocks([], Text, Calls) ->
    {lists:reverse(Text), lists:reverse(Calls)};
parse_blocks([Block | Rest], Text, Calls) ->
    Type = praxo_json:get_string(Block, <<"type">>),
    case Type of
        <<"text">> ->
            Value = default_bin(praxo_json:get_string(Block, <<"text">>)),
            parse_blocks(Rest, [Value | Text], Calls);
        <<"tool_use">> ->
            Call = praxo_models:tool_call(
                default_bin(praxo_json:get_string(Block, <<"id">>)),
                default_bin(praxo_json:get_string(Block, <<"name">>)),
                case praxo_json:get(Block, <<"input">>) of
                    Value when is_map(Value) -> Value;
                    _ -> #{}
                end
            ),
            parse_blocks(Rest, Text, [Call | Calls]);
        _ ->
            parse_blocks(Rest, Text, Calls)
    end.

post(Adapter, Path, Payload) ->
    _ = application:ensure_all_started(inets),
    Url = binary_to_list(<<(maps:get(base_url, Adapter))/binary, Path/binary>>),
    Headers = [
        {"Content-Type", "application/json"},
        {"x-api-key", binary_to_list(default_bin(maps:get(api_key, Adapter)))},
        {"anthropic-version", binary_to_list(maps:get(version, Adapter))}
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
