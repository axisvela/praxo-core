#!/usr/bin/env escript
main(_) ->
    FallbackCalls = counters:new(1, []),
    "primary" = run(
        fun() -> "primary" end,
        fun() -> counters:add(FallbackCalls, 1, 1), "fallback" end),
    0 = counters:get(FallbackCalls, 1),

    "fallback" = run(
        fun() -> throw(<<"MODEL_UNAVAILABLE">>) end,
        fun() -> "fallback" end),

    try
        run(
            fun() -> throw(<<"MODEL_UNAVAILABLE">>) end,
            fun() -> throw(<<"MODEL_UNAVAILABLE">>) end)
    catch
        throw:<<"MODEL_UNAVAILABLE">> ->
            io:format("Erlang provider fallback example passed~n")
    end.

run(Primary, Fallback) ->
    try
        Primary()
    catch
        throw:PrimaryError ->
            try Fallback() catch throw:_ -> throw(PrimaryError) end
    end.
