#!/usr/bin/env escript
main(_) ->
    code:add_pathz("language/erlang/build/ebin"),
    All = praxo_sink:new(),
    Tool = praxo_sink:new(),
    Filtered = praxo_sink:filter(Tool, [<<"tool.call">>]),
    Multi = praxo_sink:multi([All, Filtered]),
    Events = [
        praxo_models:event(<<"run.started">>, <<"s1">>),
        praxo_models:event(<<"tool.call">>, <<"s1">>),
        praxo_models:event(<<"run.completed">>, <<"s1">>)
    ],
    Emitted = lists:foldl(
        fun(Event, Sink) -> praxo_sink:emit(Sink, Event) end,
        Multi, Events),
    [AllResult, FilterResult] = maps:get(sinks, Emitted),
    [<<"run.started">>, <<"tool.call">>, <<"run.completed">>] =
        praxo_sink:kinds(AllResult),
    [<<"tool.call">>] = praxo_sink:kinds(maps:get(target, FilterResult)),
    io:format("Erlang event sink example passed~n").
