-module(praxo_ops_telemetry).
-behaviour(gen_server).

-export([start_link/0, search/1, reads/0, reset/0]).
-export([init/1, handle_call/3, handle_cast/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

search(Service) ->
    gen_server:call(?MODULE, {search, Service}, 5000).

reads() ->
    gen_server:call(?MODULE, reads).

reset() ->
    gen_server:call(?MODULE, reset).

init([]) ->
    {ok, #{reads => 0}}.

handle_call({search, Service}, _From, State = #{reads := Reads}) ->
    State2 = State#{reads => Reads + 1},
    case application:get_env(praxo_ops, telemetry_failure, false) of
        true ->
            {reply, {error, <<"TELEMETRY_UNAVAILABLE">>}, State2};
        false ->
            Signal = #{
                <<"service">> => Service,
                <<"error_rate">> => 0.18,
                <<"latency_ms">> => 940,
                <<"suspect">> => <<"checkout-api">>,
                <<"trace">> => <<"trace-100">>,
                <<"source">> => <<"telemetry_fixture">>
            },
            {reply, {ok, Signal}, State2}
    end;
handle_call(reads, _From, State = #{reads := Reads}) ->
    {reply, Reads, State};
handle_call(reset, _From, State) ->
    {reply, ok, State#{reads => 0}}.

handle_cast(_Request, State) ->
    {noreply, State}.
