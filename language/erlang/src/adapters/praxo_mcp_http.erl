-module(praxo_mcp_http).
-export([transport/1, transport/2]).

-define(DEFAULT_PROTOCOL, <<"2025-03-26">>).
-define(DEFAULT_TIMEOUT, 30000).

transport(Endpoint) ->
    transport(Endpoint, #{}).

transport(Endpoint, Options) ->
    Protocol = maps:get(protocol_version, Options, ?DEFAULT_PROTOCOL),
    Headers = maps:get(headers, Options, []),
    Timeout = maps:get(timeout, Options, ?DEFAULT_TIMEOUT),
    validate(Endpoint),
    Table = ets:new(praxo_mcp_http, [set, public]),
    ets:insert(Table, {state, <<>>, Protocol}),
    #{
        request => fun(Method, Params, RequestTimeout) ->
            request(Endpoint, Table, Headers, Timeout, Method, Params,
                RequestTimeout)
        end,
        notify => fun(Method, Params) ->
            notify(Endpoint, Table, Headers, Timeout, Method, Params)
        end,
        close => fun() ->
            close(Endpoint, Table, Headers, Timeout)
        end
    }.

request(Endpoint, Table, Headers, DefaultTimeout, Method, Params, Timeout) ->
    Id = erlang:unique_integer([positive]),
    Message = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"method">> => Method,
        <<"params">> => Params
    },
    Effective = case Timeout of
        undefined -> DefaultTimeout;
        0 -> DefaultTimeout;
        _ -> Timeout
    end,
    case post(Endpoint, Table, Headers, Effective, Message) of
        {ok, Status, ResponseHeaders, Body} ->
            update_session(Table, ResponseHeaders),
            handle_response(Method, Id, Status, ResponseHeaders, Body, Table);
        {error, Code} ->
            {error, Code}
    end.

notify(Endpoint, Table, Headers, Timeout, Method, Params) ->
    Message = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"method">> => Method,
        <<"params">> => Params
    },
    case post(Endpoint, Table, Headers, Timeout, Message) of
        {ok, _Status, ResponseHeaders, _Body} ->
            update_session(Table, ResponseHeaders),
            ok;
        _ ->
            ok
    end.

close(Endpoint, Table, Headers, Timeout) ->
    case session(Table) of
        <<>> ->
            ets:delete(Table),
            ok;
        Session ->
            Message = #{
                <<"jsonrpc">> => <<"2.0">>,
                <<"method">> => <<"notifications/initialized">>,
                <<"params">> => #{}
            },
            _ = delete(Endpoint, Table, Headers, Timeout, Session, Message),
            ets:delete(Table),
            ok
    end.

handle_response(_Method, Id, Status, ResponseHeaders, Body, Table) ->
    case Status of
        202 ->
            {ok, #{}};
        204 ->
            {ok, #{}};
        _ when Status >= 200, Status < 300 ->
            case response_messages(ResponseHeaders, Body) of
                {ok, Messages} ->
                    case select_message(Messages, Id) of
                        {ok, Message} ->
                            Result = maps:get(<<"result">>, Message, #{}),
                            update_protocol(Table, Result),
                            case maps:get(<<"error">>, Message, undefined) of
                                undefined ->
                                    {ok, Result};
                                _ ->
                                    {error, <<"MCP_RPC">>}
                            end;
                        error ->
                            {error, <<"MCP_PROTOCOL">>}
                    end;
                {error, Code} ->
                    {error, Code}
            end;
        _ ->
            {error, <<"MCP_TRANSPORT">>}
    end.

post(Endpoint, Table, Headers, Timeout, Message) ->
    ensure_inets(),
    Session = session(Table),
    Protocol = protocol(Table),
    RequestHeaders = [
        {"content-type", "application/json"},
        {"accept", "application/json, text/event-stream"},
        {"mcp-protocol-version", binary_to_list(Protocol)}
        | session_header(Session) ++ normalize_headers(Headers)
    ],
    Body = praxo_json:encode(Message),
    case httpc:request(post,
        {binary_to_list(Endpoint), RequestHeaders, "application/json",
            binary_to_list(Body)},
        [{timeout, Timeout}, {connect_timeout, Timeout}], []) of
        {ok, {{_, Status, _}, ResponseHeaders, ResponseBody}} ->
            {ok, Status, ResponseHeaders, iolist_to_binary(ResponseBody)};
        _ ->
            {error, <<"MCP_TRANSPORT">>}
    end.

delete(Endpoint, Table, Headers, Timeout, Session, _Message) ->
    ensure_inets(),
    Protocol = protocol(Table),
    RequestHeaders = [
        {"mcp-protocol-version", binary_to_list(Protocol)},
        {"mcp-session-id", binary_to_list(Session)}
        | normalize_headers(Headers)
    ],
    httpc:request(delete,
        {binary_to_list(Endpoint), RequestHeaders, "application/json", ""},
        [{timeout, Timeout}, {connect_timeout, Timeout}], []).

ensure_inets() ->
    _ = application:ensure_all_started(inets),
    ok.

response_messages(ResponseHeaders, Body) ->
    ContentType = header_value(ResponseHeaders, "content-type"),
    case string:find(string:lowercase(ContentType), "text/event-stream") of
        nomatch ->
            case praxo_json:parse(Body) of
                {ok, Value} when is_map(Value) ->
                    {ok, [Value]};
                _ ->
                    {error, <<"MCP_PROTOCOL">>}
            end;
        _ ->
            parse_sse(Body, [])
    end.

parse_sse(Body, Acc) ->
    Normalized = binary:replace(Body, <<"\r\n">>, <<"\n">>, [global]),
    Events = binary:split(Normalized, <<"\n\n">>, [global]),
    case collect_sse(Events, Acc) of
        {ok, Messages} when Messages =/= [] ->
            {ok, Messages};
        {ok, _} ->
            {error, <<"MCP_PROTOCOL">>};
        Error ->
            Error
    end.

collect_sse([], Acc) ->
    {ok, lists:reverse(Acc)};
collect_sse([Event | Rest], Acc) ->
    Data = sse_data(binary:split(Event, <<"\n">>, [global]), []),
    case Data of
        [] ->
            collect_sse(Rest, Acc);
        _ ->
            case praxo_json:parse(iolist_to_binary(Data)) of
                {ok, Value} when is_map(Value) ->
                    collect_sse(Rest, [Value | Acc]);
                _ ->
                    {error, <<"MCP_PROTOCOL">>}
            end
    end.

sse_data([], Acc) ->
    lists:reverse(Acc);
sse_data([Line | Rest], Acc) ->
    case Line of
        <<":", _/binary>> ->
            sse_data(Rest, Acc);
        <<"data:", Value/binary>> ->
            sse_data(Rest, [trim_leading(Value), <<"\n">> | Acc]);
        _ ->
            sse_data(Rest, Acc)
    end.

trim_leading(<<" ", Rest/binary>>) -> Rest;
trim_leading(Value) -> Value.

select_message([], _Id) ->
    error;
select_message([Message | Rest], Id) ->
    case maps:get(<<"id">>, Message, undefined) of
        Id -> {ok, Message};
        _ -> select_message(Rest, Id)
    end.

update_session(_Table, []) ->
    ok;
update_session(Table, Headers) ->
    case header_value(Headers, "mcp-session-id") of
        "" ->
            ok;
        Session ->
            ets:insert(Table, {state, list_to_binary(Session), protocol(Table)})
    end.

update_protocol(Table, Result) ->
    case maps:get(<<"protocolVersion">>, Result, <<>>) of
        <<>> ->
            ok;
        Protocol ->
            ets:insert(Table, {state, session(Table), Protocol})
    end.

session(Table) ->
    case ets:lookup(Table, state) of
        [{state, Session, _Protocol}] -> Session;
        _ -> <<>>
    end.

protocol(Table) ->
    case ets:lookup(Table, state) of
        [{state, _Session, Protocol}] -> Protocol;
        _ -> ?DEFAULT_PROTOCOL
    end.

session_header(<<>>) -> [];
session_header(Session) ->
    [{"mcp-session-id", binary_to_list(Session)}].

normalize_headers(Headers) ->
    [{to_list(Key), to_list(Value)} || {Key, Value} <- Headers].

to_list(Value) when is_binary(Value) -> binary_to_list(Value);
to_list(Value) when is_atom(Value) -> atom_to_list(Value);
to_list(Value) when is_list(Value) -> Value;
to_list(Value) -> lists:flatten(io_lib:format("~p", [Value])).

header_value([], _Name) ->
    "";
header_value([{Key, Value} | Rest], Name) ->
    case string:lowercase(to_list(Key)) of
        Name -> to_list(Value);
        _ -> header_value(Rest, Name)
    end.

validate(Endpoint) ->
    Parsed = uri_string:parse(binary_to_list(Endpoint)),
    Scheme = maps:get(scheme, Parsed, ""),
    Host = maps:get(host, Parsed, ""),
    case Scheme of
        "https" -> ok;
        "http" ->
            case loopback(Host) of
                true -> ok;
                false -> erlang:error({mcp_transport, "mcp: HTTP endpoint must use HTTPS"})
            end;
        _ ->
            erlang:error({mcp_transport, "mcp: invalid HTTP endpoint"})
    end.

loopback(Host) ->
    Value = string:lowercase(Host),
    Value =:= "localhost"
        orelse Value =:= "127.0.0.1"
        orelse Value =:= "::1"
        orelse lists:prefix("127.", Value).
