-module(praxo_harmovela).
-export([new/1, new/2, emit/2]).

new(BaseUrl) ->
    new(BaseUrl, #{}).

new(BaseUrl, Options) ->
    Config = #{
        base_url => strip_slashes(praxo_util:to_bin(BaseUrl)),
        source => maps:get(source, Options, <<"praxo-core">>),
        spec_version => maps:get(spec_version, Options, <<"0.2">>),
        transport => maps:get(transport, Options, undefined),
        clock => maps:get(clock, Options, undefined),
        timeout => maps:get(timeout, Options, 10000)
    },
    Config#{
        kinds => [],
        handler => fun(Event) ->
            case emit(Config, Event) of
                ok -> ok;
                {error, Reason} -> erlang:error({harmovela, Reason})
            end
        end
    }.

emit(Sink, Event) ->
    case maps:get(base_url, Sink) of
        <<>> ->
            {error, missing_base_url};
        _ ->
            {Seconds, Nanos} = timestamp(Sink),
            Envelope = #{
                <<"spec_version">> => maps:get(spec_version, Sink),
                <<"id">> => event_id(Event, Seconds, Nanos),
                <<"type">> => maps:get(kind, Event, <<>>),
                <<"source">> => maps:get(source, Sink),
                <<"created_at">> => rfc3339(Seconds, Nanos),
                <<"payload">> => payload(Event)
            },
            Body = praxo_json:encode(Envelope),
            Path = <<"/events">>,
            Headers = [{"content-type", "application/json"}],
            Result =
                case maps:get(transport, Sink) of
                    undefined -> post(Sink, Path, Body, Headers);
                    Transport -> Transport(Path, Body, Headers)
                end,
            case Result of
                {ok, Status, _ResponseBody} when Status >= 200, Status < 300 ->
                    ok;
                {ok, Status, ResponseBody} ->
                    {error, {http_status, Status, bounded(ResponseBody)}};
                {error, Reason} ->
                    {error, Reason}
            end
    end.

payload(Event) ->
    Data = maps:get(data, Event, null),
    Base =
        case is_map(Data) of
            true -> Data;
            false -> #{}
        end,
    WithSession =
        case maps:get(session_id, Event, <<>>) of
            SessionId when is_binary(SessionId), SessionId =/= <<>> ->
                Base#{<<"session_id">> => SessionId};
            _ ->
                Base
        end,
    case maps:get(run_id, Event, undefined) of
        RunId when is_binary(RunId), RunId =/= <<>> ->
            WithSession#{<<"run_id">> => RunId};
        _ ->
            WithSession
    end.

event_id(Event, Seconds, Nanos) ->
    Prefix =
        case maps:get(run_id, Event, undefined) of
            RunId when is_binary(RunId), RunId =/= <<>> ->
                RunId;
            _ ->
                case maps:get(session_id, Event, <<>>) of
                    SessionId when is_binary(SessionId), SessionId =/= <<>> ->
                        SessionId;
                    _ ->
                        <<"event">>
                end
        end,
    Ns = Seconds * 1000000000 + Nanos,
    <<Prefix/binary, "-", (integer_to_binary(Ns))/binary>>.

timestamp(Sink) ->
    case maps:get(clock, Sink) of
        undefined ->
            Ns = erlang:system_time(nanosecond),
            {Ns div 1000000000, Ns rem 1000000000};
        Clock ->
            Clock()
    end.

rfc3339(Seconds, Nanos) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} =
        calendar:system_time_to_universal_time(Seconds, second),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B.~9..0BZ",
        [Year, Month, Day, Hour, Minute, Second, Nanos]
    )).

post(Sink, Path, Body, Headers) ->
    _ = application:ensure_all_started(inets),
    Url = binary_to_list(<<(maps:get(base_url, Sink))/binary, Path/binary>>),
    Request = {Url, Headers, "application/json", binary_to_list(Body)},
    HttpOptions = [{timeout, maps:get(timeout, Sink)}],
    Options = [{body_format, binary}],
    case httpc:request(post, Request, HttpOptions, Options) of
        {ok, {{_, Status, _}, _ResponseHeaders, ResponseBody}} ->
            {ok, Status, ResponseBody};
        {error, Reason} ->
            {error, Reason}
    end.

bounded(Bin) when is_binary(Bin), byte_size(Bin) > 1024 ->
    binary:part(Bin, 0, 1024);
bounded(Bin) ->
    Bin.

strip_slashes(Bin) when byte_size(Bin) > 0 ->
    case binary:last(Bin) of
        $/ -> strip_slashes(binary:part(Bin, 0, byte_size(Bin) - 1));
        _ -> Bin
    end;
strip_slashes(Bin) ->
    Bin.
