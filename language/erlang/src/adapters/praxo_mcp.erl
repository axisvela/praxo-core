-module(praxo_mcp).
-export([new/1, start/1, list_tools/1, call_tool/3, close/1]).

-define(DEFAULT_PROTOCOL, <<"2024-11-05">>).
-define(DEFAULT_TIMEOUT, 5000).

new(Options) ->
    #{
        command => maps:get(command, Options, undefined),
        args => maps:get(args, Options, []),
        env => maps:get(env, Options, []),
        transport => maps:get(transport, Options, undefined),
        timeout => maps:get(timeout, Options, ?DEFAULT_TIMEOUT),
        client_version => maps:get(client_version, Options, <<"0.5.0">>),
        port => undefined,
        connected => false,
        protocol_version => <<>>,
        server_info => #{}
    }.

start(Client) ->
    case maps:get(connected, Client) of
        true -> {ok, Client};
        false ->
            case ensure_port(Client) of
                {ok, Ready} ->
                    case request(Ready, <<"initialize">>, #{
                        <<"protocolVersion">> => ?DEFAULT_PROTOCOL,
                        <<"capabilities">> => #{},
                        <<"clientInfo">> => #{
                            <<"name">> => <<"praxo-core">>,
                            <<"version">> => maps:get(client_version, Ready)
                        }
                    }, maps:get(timeout, Ready)) of
                        {ok, Result} ->
                            Version = default_bin(maps:get(<<"protocolVersion">>, Result, <<>>)),
                            case Version of
                                <<>> -> {error, <<"MCP_HANDSHAKE">>};
                                _ ->
                                    notify(Ready, <<"notifications/initialized">>, #{}),
                                    {ok, Ready#{
                                        connected => true,
                                        protocol_version => Version,
                                        server_info => maps:get(<<"serverInfo">>, Result, #{})
                                    }}
                            end;
                        {error, Code} -> {error, Code}
                    end;
                {error, Code} -> {error, Code}
            end
    end.

list_tools(Client0) ->
    case ensure_started(Client0) of
        {ok, Client} -> list_tools(Client, undefined, [], #{}, #{});
        {error, Code} -> {error, Code}
    end.

list_tools(Client, Cursor, Tools, Names, Seen) ->
    Params = case Cursor of
        undefined -> #{};
        _ -> #{<<"cursor">> => Cursor}
    end,
    case request(Client, <<"tools/list">>, Params, maps:get(timeout, Client)) of
        {ok, Result} ->
            Batch = maps:get(<<"tools">>, Result, []),
            case collect_tools(Batch, Tools, Names) of
                {ok, Tools2, Names2} ->
                    Next = default_bin(maps:get(<<"nextCursor">>, Result, <<>>)),
                    case Next of
                        <<>> -> {ok, Tools2};
                        _ ->
                            case maps:is_key(Next, Seen) of
                                true -> {error, <<"MCP_PAGINATION">>};
                                false -> list_tools(Client, Next, Tools2, Names2,
                                    Seen#{Next => true})
                            end
                    end;
                {error, Code} -> {error, Code}
            end;
        {error, Code} -> {error, Code}
    end.

collect_tools([], Tools, Names) -> {ok, Tools, Names};
collect_tools([Tool | Rest], Tools, Names) when is_map(Tool) ->
    Name = default_bin(maps:get(<<"name">>, Tool, <<>>)),
    case maps:is_key(Name, Names) of
        true -> {error, <<"MCP_DUPLICATE_TOOL">>};
        false -> collect_tools(Rest, Tools ++ [Tool], Names#{Name => true})
    end;
collect_tools(_, _, _) -> {error, <<"MCP_PROTOCOL">>}.

call_tool(Client0, Name, Arguments) ->
    case ensure_started(Client0) of
        {ok, Client} ->
            case request(Client, <<"tools/call">>, #{
                <<"name">> => Name,
                <<"arguments">> => Arguments
            }, maps:get(timeout, Client)) of
                {ok, Result} ->
                    case maps:get(<<"isError">>, Result, false) of
                        true -> {error, <<"MCP_TOOL_ERROR">>};
                        false ->
                            case maps:find(<<"structuredContent">>, Result) of
                                {ok, Value} -> {ok, Value};
                                error -> {ok, text_content(Result)}
                            end
                    end;
                {error, Code} -> {error, Code}
            end;
        {error, Code} -> {error, Code}
    end.

close(Client) ->
    case maps:get(port, Client) of
        undefined -> ok;
        Port ->
            try port_close(Port) catch _:_ -> ok end,
            ok
    end.

ensure_started(Client) ->
    case maps:get(connected, Client) of
        true -> {ok, Client};
        false -> start(Client)
    end.

ensure_port(Client) ->
    case maps:get(transport, Client) of
        undefined ->
            case maps:get(port, Client) of
                undefined ->
                    Command = case maps:get(command, Client) of
                        undefined -> {error, <<"MCP_TRANSPORT">>};
                        Value -> Value
                    end,
                    case Command of
                        {error, Code} -> {error, Code};
                        _ ->
                            Options = [binary, exit_status, {line, 65536},
                                {args, maps:get(args, Client)},
                                {env, maps:get(env, Client)}],
                            try open_port({spawn_executable, Command}, Options) of
                                Port -> {ok, Client#{port => Port}}
                            catch
                                _:_ -> {error, <<"MCP_TRANSPORT">>}
                            end
                    end;
                _ -> {ok, Client}
            end;
        _ -> {ok, Client}
    end.

request(Client, Method, Params, Timeout) ->
    case maps:get(transport, Client) of
        undefined -> request_port(Client, Method, Params, Timeout);
        Transport -> Transport(Method, Params, Timeout)
    end.

request_port(Client, Method, Params, Timeout) ->
    Port = maps:get(port, Client),
    Id = erlang:unique_integer([positive]),
    Payload = praxo_json:encode(#{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"method">> => Method,
        <<"params">> => Params
    }),
    true = port_command(Port, [Payload, <<"\n">>]),
    wait_response(Client, Port, Id, erlang:monotonic_time(millisecond) + Timeout).

wait_response(Client, Port, Id, Deadline) ->
    Remaining = Deadline - erlang:monotonic_time(millisecond),
    case Remaining =< 0 of
        true ->
            notify(Client, <<"notifications/cancelled">>, #{
                <<"requestId">> => Id,
                <<"reason">> => <<"timeout">>
            }),
            {error, <<"MCP_TIMEOUT">>};
        false ->
            receive
                {Port, {data, {eol, Line}}} ->
                    case praxo_json:parse(Line) of
                        {ok, Message} when is_map(Message) ->
                            case maps:get(<<"id">>, Message, undefined) of
                                Id ->
                                    case maps:get(<<"error">>, Message, undefined) of
                                        undefined ->
                                            {ok, maps:get(<<"result">>, Message, #{})};
                                        _ -> {error, <<"MCP_RPC">>}
                                    end;
                                _ -> wait_response(Client, Port, Id, Deadline)
                            end;
                        _ -> {error, <<"MCP_PROTOCOL">>}
                    end;
                {Port, {exit_status, _}} -> {error, <<"MCP_CLOSED">>}
            after Remaining ->
                notify(Client, <<"notifications/cancelled">>, #{
                    <<"requestId">> => Id,
                    <<"reason">> => <<"timeout">>
                }),
                {error, <<"MCP_TIMEOUT">>}
            end
    end.

notify(Client, Method, Params) ->
    case maps:get(port, Client) of
        undefined -> ok;
        Port ->
            Payload = praxo_json:encode(#{
                <<"jsonrpc">> => <<"2.0">>,
                <<"method">> => Method,
                <<"params">> => Params
            }),
            try port_command(Port, [Payload, <<"\n">>]) catch _:_ -> ok end,
            ok
    end.

text_content(Result) ->
    Texts = [
        maps:get(<<"text">>, Item, <<>>)
     || Item <- maps:get(<<"content">>, Result, []),
        maps:get(<<"type">>, Item, <<>>) =:= <<"text">>
    ],
    case Texts of
        [] -> null;
        [Single] -> Single;
        _ -> Texts
    end.

default_bin(undefined) -> <<>>;
default_bin(Value) -> praxo_util:to_bin(Value).
