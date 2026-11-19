-module(praxo_plugin_process).
-export([start/1, invoke/4, invoke/5, stop/1]).

-define(PROTOCOL_VERSION, 1).
-define(CONTROL_SERVICE, <<"host.control">>).
-define(DEFAULT_TOKEN_ENV, <<"PRAXOVELA_PLUGIN_TOKEN">>).

start(Config) ->
    PluginId = maps:get(plugin_id, Config),
    Path0 = maps:get(path, Config),
    Path = case os:find_executable(binary_to_list(Path0)) of
        false -> binary_to_list(Path0);
        Found -> Found
    end,
    Args = [binary_to_list(Arg) || Arg <- maps:get(args, Config, [])],
    Token = case maps:get(token, Config, <<>>) of
        <<>> -> hex(32);
        Value -> Value
    end,
    TokenEnv = maps:get(token_env_var, Config, ?DEFAULT_TOKEN_ENV),
    Port = open_port({spawn_executable, Path}, [
        binary,
        {line, 8 * 1024 * 1024},
        {args, Args},
        {env, [{binary_to_list(TokenEnv), binary_to_list(Token)}]}
    ]),
    State = #{port => Port, plugin_id => PluginId, token => Token, seq => 0},
    case call(State, ?CONTROL_SERVICE, <<"health">>, <<>>,
              maps:get(start_timeout, Config, 10000)) of
        {ok, _Payload} -> {ok, State#{active => true}};
        {error, Error} -> catch port_close(Port), {error, Error}
    end.

invoke(#{active := true} = State, Service, Method, Payload) ->
    call(State, Service, Method, Payload, 30000);
invoke(_State, _Service, _Method, _Payload) ->
    {error, {call_error, <<"NOT_ACTIVE">>, <<"plugin: host is not active">>}}.

invoke(#{active := true} = State, Service, Method, Payload, Timeout) ->
    call(State, Service, Method, Payload, Timeout);
invoke(_State, _Service, _Method, _Payload, _Timeout) ->
    {error, {call_error, <<"NOT_ACTIVE">>, <<"plugin: host is not active">>}}.

stop(State) ->
    _ = case maps:get(active, State, false) of
        true -> call(State, ?CONTROL_SERVICE, <<"shutdown">>, <<>>, 5000);
        false -> ok
    end,
    catch port_close(maps:get(port, State)),
    ok.

call(State, Service, Method, Payload, Timeout) ->
    Port = maps:get(port, State),
    Seq = maps:get(seq, State) + 1,
    Id = iolist_to_binary(["req-", integer_to_binary(Seq)]),
    Frame = #{
        <<"id">> => Id,
        <<"version">> => ?PROTOCOL_VERSION,
        <<"plugin_id">> => maps:get(plugin_id, State),
        <<"service">> => to_bin(Service),
        <<"method">> => to_bin(Method),
        <<"token">> => maps:get(token, State),
        <<"payload">> => base64:encode(to_bin(Payload))
    },
    Port ! {self(), {command, [praxo_json:encode(Frame), <<"\n">>]}},
    await(Port, Id, Timeout).

await(Port, Id, Timeout) ->
    receive
        {Port, {data, {eol, Line}}} ->
            case praxo_json:parse(Line) of
                {ok, Response} when is_map(Response) ->
                    case maps:get(<<"id">>, Response, undefined) of
                        Id ->
                            case maps:get(<<"ok">>, Response, false) of
                                true ->
                                    case base64:decode(maps:get(<<"payload">>, Response, <<>>)) of
                                        Payload -> {ok, Payload}
                                    end;
                                _ ->
                                    Code = normalize(maps:get(<<"code">>, Response, <<"INTERNAL">>)),
                                    Message = maps:get(<<"message">>, Response, <<>>),
                                    {error, {call_error, Code, Message}}
                            end;
                        _ -> await(Port, Id, Timeout)
                    end;
                _ -> await(Port, Id, Timeout)
            end;
        {Port, {exit_status, Status}} ->
            {error, {call_error, <<"INTERNAL">>,
                iolist_to_binary(io_lib:format("plugin: process exited ~p", [Status]))}}
    after Timeout ->
        cancel(#{port => Port}, Id),
        catch port_close(Port),
        {error, {call_error, <<"TIMEOUT">>, <<"plugin: invocation timed out">>}}
    end.

cancel(#{port := Port}, Id) ->
    Frame = #{
        <<"id">> => Id,
        <<"version">> => ?PROTOCOL_VERSION,
        <<"service">> => ?CONTROL_SERVICE,
        <<"method">> => <<"cancel">>
    },
    catch Port ! {self(), {command, [praxo_json:encode(Frame), <<"\n">>]}},
    ok.

normalize(Code) ->
    Known = [<<"CAPABILITY_DENIED">>, <<"NOT_ACTIVE">>, <<"NOT_FOUND">>,
        <<"INVALID_REQUEST">>, <<"TIMEOUT">>, <<"INTERNAL">>, <<"CANCELED">>],
    case lists:member(Code, Known) of
        true -> Code;
        false -> <<"INTERNAL">>
    end.

to_bin(Value) when is_binary(Value) -> Value;
to_bin(Value) when is_list(Value) -> list_to_binary(Value);
to_bin(Value) -> iolist_to_binary(io_lib:format("~p", [Value])).

hex(Bytes) ->
    binary:encode_hex(crypto:strong_rand_bytes(Bytes), lowercase).
