-module(praxo_ops_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    praxo_ops_sup:start_link().

stop(_State) ->
    ok.
