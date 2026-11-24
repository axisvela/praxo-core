-module(praxo_sup).
-behaviour(supervisor).
-export([start_link/1, init/1]).

start_link(Table) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, [Table]).

init([Table]) ->
    Child = #{
        id => worker,
        start => {worker, start_link, [Table]},
        restart => permanent,
        shutdown => 5000,
        type => worker
    },
    {ok, {{one_for_one, 5, 10}, [Child]}}.
