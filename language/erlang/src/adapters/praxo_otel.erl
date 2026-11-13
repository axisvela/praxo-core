-module(praxo_otel).
-export([new/1, new/2, emit/2]).

new(Endpoint) ->
    new(Endpoint, #{}).

new(Endpoint, Options) ->
    #{
        endpoint => praxo_util:to_bin(Endpoint),
        service_name => maps:get(service_name, Options, <<"praxo-core">>),
        allowed_data_keys => maps:get(allowed_data_keys, Options, []),
        transport => maps:get(transport, Options, undefined),
        clock => maps:get(clock, Options, undefined),
        timeout => maps:get(timeout, Options, 10000)
    }.

emit(Sink, Event) ->
    case maps:get(endpoint, Sink) of
        <<>> ->
            {error, <<"OTEL_URL">>};
        _ ->
            Nanos = timestamp(Sink),
            Body = praxo_json:encode(payload(Sink, Event, Nanos)),
            Headers = [{"content-type", "application/json"}],
            Result =
                case maps:get(transport, Sink) of
                    undefined -> post(Sink, Body, Headers);
                    Transport -> Transport(maps:get(endpoint, Sink), Body, Headers)
                end,
            case Result of
                {ok, Status, _} when Status >= 200, Status < 300 ->
                    ok;
                {ok, Status, ResponseBody} ->
                    {error, {http_status, Status, bounded(ResponseBody)}};
                {error, Reason} ->
                    {error, Reason}
            end
    end.

payload(Sink, Event, Nanos) ->
    Stamp = integer_to_binary(Nanos),
    Data = maps:get(data, Event, #{}),
    SafeData = case is_map(Data) of true -> Data; false -> #{} end,
    Key = iolist_to_binary([
        maps:get(session_id, Event, <<>>), $|,
        praxo_util:default(maps:get(run_id, Event, undefined), <<>>), $|,
        maps:get(kind, Event, <<>>), $|,
        Stamp, $|,
        praxo_json:encode(SafeData)
    ]),
    TraceId = <<
        (stable_id(<<"trace-a:">>, Key))/binary,
        (stable_id(<<"trace-b:">>, Key))/binary,
        (stable_id(<<"trace-c:">>, Key))/binary,
        (stable_id(<<"trace-d:">>, Key))/binary
    >>,
    SpanId = <<
        (stable_id(<<"span-a:">>, Key))/binary,
        (stable_id(<<"span-b:">>, Key))/binary
    >>,
    Attributes0 = [attribute(<<"praxo.event.type">>, maps:get(kind, Event, <<>>))],
    Attributes1 =
        case maps:get(session_id, Event, <<>>) of
            Session when is_binary(Session), Session =/= <<>> ->
                Attributes0 ++ [attribute(<<"praxo.session.id">>, Session)];
            _ ->
                Attributes0
        end,
    Attributes2 =
        case maps:get(run_id, Event, undefined) of
            Run when is_binary(Run), Run =/= <<>> ->
                Attributes1 ++ [attribute(<<"praxo.run.id">>, Run)];
            _ ->
                Attributes1
        end,
    Attributes3 = Attributes2 ++ [attribute(<<"praxo.event.at">>, Stamp)],
    Attributes = Attributes3 ++ [
        attribute(<<"praxo.event.data.", Name/binary>>, text(maps:get(Name, SafeData)))
        || Name <- maps:get(allowed_data_keys, Sink), maps:is_key(Name, SafeData)
    ],
    Service = case maps:get(service_name, Sink) of
        <<>> -> <<"praxo-core">>;
        Value -> Value
    end,
    #{
        <<"resourceSpans">> => [
            #{
                <<"resource">> => #{
                    <<"attributes">> => [attribute(<<"service.name">>, Service)]
                },
                <<"scopeSpans">> => [
                    #{
                        <<"scope">> => #{<<"name">> => <<"praxo-core">>},
                        <<"spans">> => [
                            #{
                                <<"traceId">> => TraceId,
                                <<"spanId">> => SpanId,
                                <<"name">> => <<"praxo.", (maps:get(kind, Event, <<>>))/binary>>,
                                <<"kind">> => 1,
                                <<"startTimeUnixNano">> => Stamp,
                                <<"endTimeUnixNano">> => Stamp,
                                <<"attributes">> => Attributes
                            }
                        ]
                    }
                ]
            }
        ]
    }.

attribute(Key, Value) ->
    #{<<"key">> => Key, <<"value">> => #{<<"stringValue">> => text(Value)}}.

text(Value) when is_binary(Value) -> Value;
text(Value) when is_integer(Value) -> integer_to_binary(Value);
text(Value) when is_float(Value) -> float_to_binary(Value);
text(Value) when is_boolean(Value) -> atom_to_binary(Value, utf8);
text(null) -> <<>>;
text(undefined) -> <<>>;
text(Value) -> praxo_json:encode(Value).

stable_id(Prefix, Key) ->
    Hash = lists:foldl(
        fun(Byte, Acc) ->
            (Acc bxor Byte) * 16#01000193 band 16#FFFFFFFF
        end,
        16#811c9dc5,
        binary_to_list(<<Prefix/binary, Key/binary>>)
    ),
    iolist_to_binary(io_lib:format("~8.16.0b", [Hash])).

timestamp(Sink) ->
    case maps:get(clock, Sink) of
        undefined -> erlang:system_time(nanosecond);
        Clock -> Clock()
    end.

post(Sink, Body, Headers) ->
    _ = application:ensure_all_started(inets),
    Url = binary_to_list(maps:get(endpoint, Sink)),
    Request = {Url, Headers, "application/json", binary_to_list(Body)},
    HttpOptions = [{timeout, maps:get(timeout, Sink)}],
    Options = [{body_format, binary}],
    case httpc:request(post, Request, HttpOptions, Options) of
        {ok, {{_, Status, _}, _, ResponseBody}} ->
            {ok, Status, ResponseBody};
        {error, Reason} ->
            {error, Reason}
    end.

bounded(Bin) when is_binary(Bin), byte_size(Bin) > 512 ->
    binary:part(Bin, 0, 512);
bounded(Bin) ->
    Bin.
