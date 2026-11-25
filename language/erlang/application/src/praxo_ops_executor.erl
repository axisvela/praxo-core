-module(praxo_ops_executor).
-behaviour(gen_server).

-export([start_link/0, execute/1, count/0, reset/0]).
-export([init/1, handle_call/3, handle_cast/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

execute(Service) ->
    gen_server:call(?MODULE, {execute, Service}, 5000).

count() ->
    gen_server:call(?MODULE, count).

reset() ->
    gen_server:call(?MODULE, reset).

init([]) ->
    {ok, #{executions => 0}}.

handle_call({execute, Service}, _From, State = #{executions := Executions}) ->
    State2 = State#{executions => Executions + 1},
    {reply, {ok, #{<<"service">> => Service, <<"status">> => <<"executed">>}}, State2};
handle_call(count, _From, State = #{executions := Executions}) ->
    {reply, Executions, State};
handle_call(reset, _From, State) ->
    {reply, ok, State#{executions => 0}}.

handle_cast(_Request, State) ->
    {noreply, State}.
