#!/usr/bin/env escript
main(_) ->
    {ok, <<"status: green">>, 3} = run(2, 3),
    {error, <<"MODEL_UNAVAILABLE">>, 3} = run(3, 3),
    io:format("Erlang retry example passed~n").

run(Failures, Max) ->
    run(Failures, Max, 1).

run(Failures, Max, Attempt) when Attempt =< Failures ->
    case Attempt of
        Max -> {error, <<"MODEL_UNAVAILABLE">>, Attempt};
        _ -> run(Failures, Max, Attempt + 1)
    end;
run(_Failures, _Max, Attempt) ->
    {ok, <<"status: green">>, Attempt}.
