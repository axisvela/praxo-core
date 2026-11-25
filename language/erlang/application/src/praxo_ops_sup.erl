-module(praxo_ops_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => telemetry,
            start => {praxo_ops_telemetry, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [praxo_ops_telemetry]
        },
        #{
            id => executor,
            start => {praxo_ops_executor, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [praxo_ops_executor]
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, Children}}.
