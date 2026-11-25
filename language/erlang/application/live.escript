#!/usr/bin/env escript
%%! -noshell

main(_Args) ->
    ScriptDir = filename:dirname(filename:absname(escript:script_name())),
    code:add_pathz(filename:join([ScriptDir, "build", "ebin"])),
    {ok, _Apps} = application:ensure_all_started(praxo_ops),
    Intent = <<"Investigate the checkout incident using the telemetry. Explain the likely cause and draft a review-only remediation.">>,
    {Result, Trace} = praxo_ops_agent:run_traced(<<"acme">>, <<"service-100">>, Intent),
    io:format("RESULT~n~p~nTRACE~n~p~n", [Result, Trace]).
