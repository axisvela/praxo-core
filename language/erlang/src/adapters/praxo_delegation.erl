-module(praxo_delegation).
-export([subagent_run/2]).

subagent_run(Runner, Request) ->
    Parent = maps:get(parent_session_id, Request, <<>>),
    Agent = maps:get(agent_id, Request, <<>>),
    case Parent =:= <<>> orelse Agent =:= <<>> of
        true ->
            {error, <<"SUBAGENT_INVALID">>};
        false ->
            Timestamp = timestamp(),
            Base = #{
                id => <<"subagent">>,
                parent_session_id => Parent,
                agent_id => Agent,
                mode => mode(maps:get(mode, Request, <<"isolated">>)),
                status => <<"running">>,
                output => <<>>,
                error => <<>>,
                created_at => Timestamp,
                updated_at => Timestamp
            },
            try Runner(Request) of
                {ok, Result} when is_map(Result) ->
                    {ok, Base#{
                        status => <<"completed">>,
                        output => maps:get(output, Result, <<>>)
                    }};
                {error, Reason} ->
                    {ok, Base#{status => <<"failed">>, error => error_code(Reason)}};
                Result when is_map(Result) ->
                    {ok, Base#{
                        status => <<"completed">>,
                        output => maps:get(output, Result, <<>>)
                    }}
            catch
                throw:{praxo_error, Code, _} ->
                    {ok, Base#{status => <<"failed">>, error => Code}};
                error:Reason ->
                    {ok, Base#{status => <<"failed">>, error => error_code(Reason)}}
            end
    end.

mode(<<"fork">>) -> <<"fork">>;
mode(_) -> <<"isolated">>.

timestamp() ->
    integer_to_binary(erlang:system_time(millisecond)).

error_code(Code) when is_binary(Code) -> Code;
error_code(Code) when is_atom(Code) -> atom_to_binary(Code, utf8);
error_code({Code, _}) when is_binary(Code) -> Code;
error_code(_) -> <<"SUBAGENT_ERROR">>.
