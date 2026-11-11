-module(praxo_openai_compatible).
-export([new/2, new/3, generate/2, model/1]).

new(BaseUrl, Model) ->
    new(BaseUrl, Model, #{}).

new(BaseUrl, Model, Options) ->
    #{
        base_url => strip_slashes(praxo_util:to_bin(BaseUrl)),
        model => praxo_util:to_bin(Model),
        api_key => maps:get(api_key, Options, undefined),
        transport => maps:get(transport, Options, undefined),
        timeout => maps:get(timeout, Options, 60000)
    }.

generate(Adapter, Request) ->
    case maps:get(base_url, Adapter) of
        <<>> ->
            {error, <<"PROVIDER_HTTP">>, Adapter};
        _ ->
            Payload = payload(Adapter, Request),
            Path = <<"/chat/completions">>,
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
                {error, Code} ->
                    {error, Code, Adapter};
                {error, Code, Detail} ->
                    {error, Code, Adapter#{last_error => Detail}}
            end
    end.

model(Adapter) ->
    fun(Request) -> generate(Adapter, Request) end.

payload(Adapter, Request) ->
    Messages = [message_payload(Message) || Message <- maps:get(messages, Request, [])],
    Base = #{
        <<"model">> => maps:get(model, Adapter),
        <<"messages">> => Messages
    },
    WithTools =
        case maps:get(tools, Request, []) of
            [] -> Base;
            Tools -> Base#{<<"tools">> => [tool_payload(Tool) || Tool <- Tools]}
        end,
    case maps:get(tool_choice, Request, undefined) of
        undefined -> WithTools;
        <<>> -> WithTools;
        Choice -> WithTools#{<<"tool_choice">> => Choice}
    end.

message_payload(Message) ->
    Role = maps:get(role, Message),
    Base = #{
        <<"role">> => Role,
        <<"content">> => message_content(Message)
    },
    WithCalls =
        case {Role, maps:get(tool_calls, Message, [])} of
            {<<"assistant">>, []} -> Base;
            {<<"assistant">>, Calls} ->
                Base#{<<"tool_calls">> => [call_payload(Call) || Call <- Calls]};
            _ -> Base
        end,
    case {Role, maps:get(tool_id, Message, undefined)} of
        {<<"tool">>, ToolId} when is_binary(ToolId), ToolId =/= <<>> ->
            WithCalls#{<<"tool_call_id">> => ToolId};
        _ ->
            WithCalls
    end.

message_content(Message) ->
    Content = maps:get(content, Message, <<>>),
    case is_binary(Content) andalso Content =/= <<>> of
        true ->
            Content;
        false ->
            content_blocks_text(maps:get(content_blocks, Message, []))
    end.

content_blocks_text(Blocks) ->
    iolist_to_binary([
        Text
     || Block <- Blocks,
        maps:get(kind, Block, <<>>) =:= <<"text">>,
        Text <- [maps:get(text, Block, <<>>)],
        is_binary(Text)
    ]).

call_payload(Call) ->
    #{
        <<"id">> => maps:get(id, Call, <<>>),
        <<"type">> => <<"function">>,
        <<"function">> => #{
            <<"name">> => maps:get(name, Call, <<>>),
            <<"arguments">> => praxo_json:encode(maps:get(arguments, Call, #{}))
        }
    }.

tool_payload(Tool) ->
    #{
        <<"type">> => <<"function">>,
        <<"function">> => #{
            <<"name">> => maps:get(name, Tool),
            <<"description">> => maps:get(description, Tool, <<>>),
            <<"parameters">> => maps:get(
                parameters, Tool, #{<<"type">> => <<"object">>}
            )
        }
    }.

parse_response(Data) ->
    Choices = praxo_json:get_array(Data, <<"choices">>),
    Choice =
        case Choices of
            [First | _] when is_map(First) -> First;
            _ -> #{}
        end,
    Message = praxo_json:get_object(Choice, <<"message">>),
    case parse_calls(praxo_json:get_array(Message, <<"tool_calls">>)) of
        {ok, Calls} ->
            Content = praxo_json:get_string(Message, <<"content">>),
            Usage = praxo_json:get_object(Data, <<"usage">>),
            Response = praxo_models:response(
                praxo_models:message_assistant(default_bin(Content), Calls),
                praxo_models:usage(
                    praxo_json:get_int(Usage, <<"prompt_tokens">>, 0),
                    praxo_json:get_int(Usage, <<"completion_tokens">>, 0)
                )
            ),
            Finish = praxo_json:get_string(Choice, <<"finish_reason">>),
            case Finish of
                undefined -> {ok, Response};
                _ -> {ok, Response#{finish_reason => Finish}}
            end;
        {error, Code} ->
            {error, Code}
    end.

parse_calls([]) ->
    {ok, []};
parse_calls([Item | Rest]) ->
    case parse_call(Item) of
        {ok, Call} ->
            case parse_calls(Rest) of
                {ok, Calls} -> {ok, [Call | Calls]};
                Error -> Error
            end;
        Error ->
            Error
    end.

parse_call(Item) when is_map(Item) ->
    Function = praxo_json:get_object(Item, <<"function">>),
    Id = default_bin(praxo_json:get_string(Item, <<"id">>)),
    Name = default_bin(praxo_json:get_string(Function, <<"name">>)),
    case parse_arguments(praxo_json:get(Function, <<"arguments">>)) of
        {ok, Arguments} ->
            {ok, praxo_models:tool_call(Id, Name, Arguments)};
        Error ->
            Error
    end;
parse_call(_) ->
    {error, <<"PROVIDER_JSON">>}.

parse_arguments(undefined) ->
    {ok, #{}};
parse_arguments(Raw) when is_binary(Raw) ->
    case Raw of
        <<>> ->
            {ok, #{}};
        _ ->
            case praxo_json:parse(Raw) of
                {ok, Value} when is_map(Value) -> {ok, Value};
                _ -> {error, <<"PROVIDER_JSON">>}
            end
    end;
parse_arguments(Raw) when is_map(Raw) ->
    {ok, Raw};
parse_arguments(_) ->
    {error, <<"PROVIDER_JSON">>}.

post(Adapter, Path, Payload) ->
    _ = application:ensure_all_started(inets),
    Url = binary_to_list(<<(maps:get(base_url, Adapter))/binary, Path/binary>>),
    Headers = request_headers(maps:get(api_key, Adapter)),
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

request_headers(ApiKey) when is_binary(ApiKey), ApiKey =/= <<>> ->
    [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer " ++ binary_to_list(ApiKey)}
    ];
request_headers(_) ->
    [{"Content-Type", "application/json"}].

default_bin(undefined) -> <<>>;
default_bin(Value) -> Value.

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
