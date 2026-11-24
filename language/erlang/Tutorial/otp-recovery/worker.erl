-module(worker).
-export([start_link/1]).

start_link(Table) ->
    {ok, spawn_link(fun() -> loop(Table) end)}.

loop(Table) ->
    ets:update_counter(Table, starts, 1),
    receive
        crash -> exit(injected_crash);
        stop -> ok
    end.
