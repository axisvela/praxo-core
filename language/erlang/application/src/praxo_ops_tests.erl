-module(praxo_ops_tests).
-export([run/0]).

run() ->
    {ok, _Apps} = application:ensure_all_started(praxo_ops),
    reset(),
    success(),
    direct_execution(),
    out_of_scope(),
    tenant_mismatch(),
    telemetry_failure(),
    supervision(),
    io:format("erlang ai ops: 6 tests passed~n").

reset() ->
    application:set_env(praxo_ops, telemetry_failure, false),
    praxo_ops_telemetry:reset(),
    praxo_ops_executor:reset().

success() ->
    {ok, Report, Stats} = praxo_ops_agent:run(
        <<"acme">>,
        <<"service-100">>,
        <<"Investigate the checkout incident.">>
    ),
    <<"deterministic">> = maps:get(<<"model">>, Report),
    Remediation = maps:get(<<"remediation">>, Report),
    <<"draft_only">> = maps:get(<<"status">>, Remediation),
    true = is_binary(maps:get(<<"diagnosis">>, Remediation)),
    true = is_binary(maps:get(<<"rationale">>, Remediation)),
    0 = maps:get(<<"executions">>, Report),
    Trace = maps:get(<<"agent_trace">>, Report),
    true = has_tool(Trace, <<"search_signals">>),
    true = has_tool(Trace, <<"draft_remediation">>),
    #{reads := 1, drafts := 1, executions := 0} = Stats,
    0 = praxo_ops_executor:count(),
    io:format("success: draft_only executions=0 reads=1 drafts=1~n").

direct_execution() ->
    reset(),
    {error, <<"AGENT_POLICY_DENIED">>, Stats} = praxo_ops_agent:run(
        <<"acme">>,
        <<"service-100">>,
        <<"Remediate now for service-100.">>
    ),
    #{reads := 0, drafts := 0, executions := 0} = Stats,
    0 = praxo_ops_executor:count(),
    io:format("deny: direct remediation rejected with zero effects~n").

out_of_scope() ->
    reset(),
    {error, <<"AGENT_POLICY_DENIED">>, Stats} = praxo_ops_agent:run(
        <<"acme">>,
        <<"service-200">>,
        <<"Investigate the incident.">>
    ),
    #{reads := 0, drafts := 0, executions := 0} = Stats,
    0 = praxo_ops_telemetry:reads(),
    io:format("deny: service-200 rejected before read~n").

tenant_mismatch() ->
    reset(),
    {error, <<"AGENT_POLICY_DENIED">>, Stats} = praxo_ops_agent:run(
        <<"other">>,
        <<"service-100">>,
        <<"Investigate the incident.">>
    ),
    #{reads := 0, drafts := 0, executions := 0} = Stats,
    0 = praxo_ops_telemetry:reads(),
    io:format("deny: tenant mismatch rejected before read~n").

telemetry_failure() ->
    reset(),
    application:set_env(praxo_ops, telemetry_failure, true),
    {error, <<"TELEMETRY_UNAVAILABLE">>, Stats} = praxo_ops_agent:run(
        <<"acme">>,
        <<"service-100">>,
        <<"Investigate the incident.">>
    ),
    #{reads := 1, drafts := 0, executions := 0} = Stats,
    application:set_env(praxo_ops, telemetry_failure, false),
    io:format("failure: telemetry unavailable after one read~n").

supervision() ->
    reset(),
    OldPid = whereis(praxo_ops_telemetry),
    true = is_pid(OldPid),
    exit(OldPid, kill),
    NewPid = wait_for_restart(OldPid, 50),
    true = is_pid(NewPid),
    true = NewPid =/= OldPid,
    {ok, Signal} = praxo_ops_telemetry:search(<<"service-100">>),
    <<"checkout-api">> = maps:get(<<"suspect">>, Signal),
    io:format("supervision: telemetry restarted with a new pid~n").

wait_for_restart(_OldPid, 0) ->
    error(telemetry_process_did_not_restart);
wait_for_restart(OldPid, Attempts) ->
    case whereis(praxo_ops_telemetry) of
        Pid when is_pid(Pid), Pid =/= OldPid ->
            Pid;
        _ ->
            timer:sleep(20),
            wait_for_restart(OldPid, Attempts - 1)
    end.

has_tool([], _Name) ->
    false;
has_tool([Step | Rest], Name) ->
    Calls = maps:get(<<"tool_calls">>, Step, []) ++
        maps:get(<<"tool_calls">>, maps:get(<<"model_output">>, Step, #{}), []),
    case lists:any(fun(Call) -> maps:get(<<"name">>, Call, undefined) =:= Name end, Calls) of
        true -> true;
        false -> has_tool(Rest, Name)
    end.
