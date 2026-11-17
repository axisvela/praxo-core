#!/usr/bin/env escript
main(_) ->
    add_paths(),
    run_scope_escalation(),
    run_depth_limit(),
    run_child_limit(),
    run_sibling_budget(),
    run_cancellation(),
    run_final_argument_reauthorization(),
    io:format("erlang governance: delegation checks passed (6)~n").

add_paths() ->
    Script = escript:script_name(),
    Dir = filename:dirname(filename:absname(Script)),
    Build = filename:absname(
        filename:join([Dir, "..", "..", "build", "ebin"])
    ),
    _ = code:add_pathz(Build),
    _ = code:add_pathz("language/erlang/build/ebin"),
    ok.

new_state(Value) ->
    Key = {governance, make_ref()},
    put(Key, Value),
    Key.

state_get(Key) ->
    get(Key).

state_set(Key, Value) ->
    put(Key, Value).

new_budget(Remaining) ->
    new_state(Remaining).

budget_available(Budget) ->
    state_get(Budget) > 0.

budget_take(Budget) ->
    case state_get(Budget) of
        Remaining when Remaining > 0 ->
            state_set(Budget, Remaining - 1),
            true;
        _ ->
            false
    end.

new_authority(Allowed, Delegable, MaxDepth, MaxChildren, Budget, Policy) ->
    new_authority(Allowed, Delegable, MaxDepth, MaxChildren, 0, Budget, Policy).

new_authority(Allowed, Delegable, MaxDepth, MaxChildren, Depth, Budget, Policy) ->
    #{
        allowed => Allowed,
        delegable => Delegable,
        max_depth => MaxDepth,
        max_children => MaxChildren,
        depth => Depth,
        budget => Budget,
        policy => Policy
    }.

governed_authority(Allowed, MaxChildren, Budget) ->
    new_authority(Allowed, Allowed, 1, MaxChildren, Budget, allow_all()).

allow_all() ->
    fun(_Action) ->
        #{allowed => true, reason => <<"root">>}
    end.

record_policy(Action) ->
    case maps:get(kind, Action) of
        <<"tool.invoke">> ->
            case maps:get(tool_name, Action) of
                <<"record">> ->
                    Arguments = maps:get(arguments, Action, #{}),
                    case maps:get(<<"target">>, Arguments, <<>>) of
                        <<"blocked">> ->
                            #{allowed => false, reason => <<"blocked target">>};
                        _ ->
                            #{allowed => true, reason => <<"record allowed">>}
                    end;
                _ ->
                    #{allowed => false, reason => <<"child may only record">>}
            end;
        _ ->
            #{allowed => true, reason => <<"non-tool action">>}
    end.

budget_policy(Budget) ->
    fun(Action) ->
        case maps:get(kind, Action) of
            <<"tool.invoke">> ->
                case budget_available(Budget) of
                    true ->
                        #{allowed => true, reason => <<"budget available">>};
                    false ->
                        #{allowed => false,
                          reason => <<"delegation budget exhausted">>}
                end;
            _ ->
                #{allowed => true, reason => <<"non-tool action">>}
        end
    end.

compose_policy(undefined, undefined) ->
    fun(_Action) ->
        #{allowed => true, reason => <<"delegation policy chain allowed">>}
    end;
compose_policy(undefined, Child) ->
    Child;
compose_policy(Parent, undefined) ->
    Parent;
compose_policy(Parent, Child) ->
    fun(Action) ->
        case Parent(Action) of
            #{allowed := true} -> Child(Action);
            Decision -> Decision
        end
    end.

new_governor(Authority) ->
    MaxChildren =
        case maps:get(max_children, Authority) of
            Value when Value >= 1 -> Value;
            _ -> 1
        end,
    #{
        authority => Authority#{max_children => MaxChildren},
        active => new_state(0)
    }.

delegate(Governor, Request) ->
    Authority = maps:get(authority, Governor),
    Allowed = maps:get(allowed, Request, []),
    Delegable = maps:get(delegable, Request, []),
    Policy = maps:get(policy, Request, undefined),
    Depth = maps:get(depth, Authority) + 1,
    Budget = maps:get(budget, Authority),
    Checks = [
        {Depth > maps:get(max_depth, Authority), <<"DELEGATION_DEPTH">>},
        {Allowed == [], <<"DELEGATION_SCOPE">>},
        {not subset(Allowed, maps:get(delegable, Authority)),
         <<"DELEGATION_SCOPE">>},
        {not subset(Allowed, maps:get(allowed, Authority)),
         <<"DELEGATION_SCOPE">>},
        {not subset(Delegable, maps:get(delegable, Authority)),
         <<"DELEGATION_SCOPE">>},
        {not budget_available(Budget), <<"DELEGATION_BUDGET">>}
    ],
    case [Code || {true, Code} <- Checks] of
        [Code | _] ->
            {error, Code};
        [] ->
            ActiveKey = maps:get(active, Governor),
            Active = state_get(ActiveKey),
            case Active >= maps:get(max_children, Authority) of
                true ->
                    {error, <<"DELEGATION_CHILDREN">>};
                false ->
                    state_set(ActiveKey, Active + 1),
                    {ok, child_scope(
                        Authority,
                        Allowed,
                        Delegable,
                        Policy,
                        Depth,
                        Budget,
                        ActiveKey
                    )}
            end
    end.

child_scope(Authority, Allowed, Delegable, Policy, Depth, Budget, ActiveKey) ->
    ReleasedKey = new_state(false),
    Release = fun() ->
        case state_get(ReleasedKey) of
            true ->
                ok;
            false ->
                state_set(ReleasedKey, true),
                state_set(ActiveKey, state_get(ActiveKey) - 1)
        end
    end,
    ChildPolicy = compose_policy(
        compose_policy(maps:get(policy, Authority), Policy),
        budget_policy(Budget)
    ),
    ChildAuthority = Authority#{
        allowed => Allowed,
        delegable => Delegable,
        depth => Depth,
        policy => ChildPolicy
    },
    #{authority => ChildAuthority, release => Release}.

subset([], _Set) ->
    true;
subset([Item | Rest], Set) ->
    lists:member(Item, Set) andalso subset(Rest, Set).

release(Scope) ->
    (maps:get(release, Scope))().

budgeted_tool(Tool, Budget) ->
    Invoke = maps:get(invoke, Tool),
    Tool#{
        invoke => fun(Arguments) ->
            case budget_take(Budget) of
                true ->
                    Invoke(Arguments);
                false ->
                    #{<<"error">> => <<"DELEGATION_BUDGET">>}
            end
        end
    }.

child_run(Scope, Model, Tools, Prompt) ->
    child_run(Scope, Model, Tools, Prompt, #{}).

child_run(Scope, Model, Tools, Prompt, Extra) ->
    Authority = maps:get(authority, Scope),
    Allowed = maps:get(allowed, Authority),
    Budget = maps:get(budget, Authority),
    Scoped = [
        budgeted_tool(Tool, Budget)
     || Tool <- Tools,
        lists:member(maps:get(name, Tool), Allowed)
    ],
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => Scoped,
        allowed_tools => Allowed,
        max_steps => 3,
        policy => maps:get(policy, Authority),
        require_policy => true,
        require_tool_scope => true,
        session_id => <<"governed-delegation-child">>
    },
    praxo_agent:run_agent(
        maps:merge(Options, Extra),
        praxo_models:session(<<"governed-delegation">>),
        Prompt
    ).

record_tool() ->
    CallsKey = new_state(0),
    Tool = praxo_agent:new_tool(
        <<"record">>,
        <<"Record a delegated effect">>,
        fun(_Arguments) ->
            state_set(CallsKey, state_get(CallsKey) + 1),
            <<"recorded">>
        end
    ),
    {Tool, fun() -> state_get(CallsKey) end}.

parent_only_tool() ->
    CallsKey = new_state(0),
    Tool = praxo_agent:new_tool(
        <<"parent_only">>,
        <<"Parent-only capability">>,
        fun(_Arguments) ->
            state_set(CallsKey, state_get(CallsKey) + 1),
            <<"parent-effect">>
        end
    ),
    {Tool, fun() -> state_get(CallsKey) end}.

fixture_model(Tool, Target, Final) ->
    praxo_agent:scripted_model([
        praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(
                    <<"call-1">>,
                    Tool,
                    #{<<"target">> => Target}
                )
            ])
        ),
        praxo_models:response(praxo_models:message_assistant(Final))
    ]).

check(true, _Message) ->
    ok;
check(false, Message) ->
    erlang:error(Message).

expect_error(Fun, Expected) ->
    Result = Fun(),
    case Result of
        {error, Expected} -> ok;
        {error, Expected, _} -> ok;
        _ -> erlang:error({expected_error, Expected, Result})
    end.

run_scope_escalation() ->
    {_Record, RecordCalls} = record_tool(),
    {_ParentOnly, ParentOnlyCalls} = parent_only_tool(),
    Governor = new_governor(
        new_authority(
            [<<"record">>, <<"parent_only">>],
            [<<"record">>],
            1,
            2,
            new_budget(2),
            allow_all()
        )
    ),
    expect_error(
        fun() ->
            delegate(Governor, #{allowed => [<<"parent_only">>]})
        end,
        <<"DELEGATION_SCOPE">>
    ),
    check(RecordCalls() == 0, <<"scope escalation produced a record effect">>),
    check(ParentOnlyCalls() == 0, <<"scope escalation produced a parent effect">>),
    {ok, Child} = delegate(Governor, #{
        allowed => [<<"record">>],
        policy => fun record_policy/1
    }),
    release(Child),
    io:format("scope escalation: rejected; effects=0~n").

run_depth_limit() ->
    {_Record, RecordCalls} = record_tool(),
    Governor = new_governor(
        governed_authority([<<"record">>], 1, new_budget(2))
    ),
    {ok, Child} = delegate(Governor, #{
        allowed => [<<"record">>],
        delegable => [<<"record">>],
        policy => fun record_policy/1
    }),
    Grand = new_governor(maps:get(authority, Child)),
    expect_error(
        fun() -> delegate(Grand, #{allowed => [<<"record">>]}) end,
        <<"DELEGATION_DEPTH">>
    ),
    check(RecordCalls() == 0, <<"depth rejection produced an effect">>),
    release(Child),
    io:format("depth limit: grandchild rejected; effects=0~n").

run_child_limit() ->
    Governor = new_governor(
        governed_authority([<<"record">>], 1, new_budget(2))
    ),
    {ok, First} = delegate(Governor, #{allowed => [<<"record">>]}),
    expect_error(
        fun() -> delegate(Governor, #{allowed => [<<"record">>]}) end,
        <<"DELEGATION_CHILDREN">>
    ),
    release(First),
    {ok, Second} = delegate(Governor, #{allowed => [<<"record">>]}),
    release(Second),
    io:format("child limit: enforced and released~n").

run_sibling_budget() ->
    {Record, RecordCalls} = record_tool(),
    Governor = new_governor(
        governed_authority([<<"record">>], 2, new_budget(1))
    ),
    {ok, First} = delegate(Governor, #{
        allowed => [<<"record">>],
        policy => fun record_policy/1
    }),
    {ok, Second} = delegate(Governor, #{
        allowed => [<<"record">>],
        policy => fun record_policy/1
    }),
    {ok, FirstResult, _} = child_run(
        First,
        fixture_model(<<"record">>, <<"first">>, <<"first-done">>),
        [Record],
        <<"record once">>
    ),
    check(
        maps:get(output, FirstResult) == <<"first-done">>,
        <<"first sibling did not complete">>
    ),
    expect_error(
        fun() ->
            child_run(
                Second,
                fixture_model(<<"record">>, <<"second">>, <<"second-done">>),
                [Record],
                <<"record twice">>
            )
        end,
        <<"AGENT_POLICY_DENIED">>
    ),
    check(RecordCalls() == 1, <<"sibling budget did not allow one effect">>),
    release(First),
    release(Second),
    io:format("sibling budget: effects=1~n").

run_cancellation() ->
    {Record, RecordCalls} = record_tool(),
    Governor = new_governor(
        governed_authority([<<"record">>], 1, new_budget(1))
    ),
    {ok, Child} = delegate(Governor, #{
        allowed => [<<"record">>],
        policy => fun record_policy/1
    }),
    CancelKey = new_state(false),
    Model = fun(_Request) ->
        state_set(CancelKey, true),
        {ok, praxo_models:response(
            praxo_models:message_assistant(<<>>, [
                praxo_models:tool_call(
                    <<"call-1">>,
                    <<"record">>,
                    #{<<"target">> => <<"safe">>}
                )
            ])
        ), praxo_agent:failing_model()}
    end,
    expect_error(
        fun() ->
            child_run(
                Child,
                Model,
                [Record],
                <<"record after cancel">>,
                #{cancellation => fun() -> state_get(CancelKey) end}
            )
        end,
        <<"AGENT_CANCELLED">>
    ),
    check(RecordCalls() == 0, <<"cancellation produced an effect">>),
    release(Child),
    io:format("cancellation: zero effects~n").

run_final_argument_reauthorization() ->
    {Record, RecordCalls} = record_tool(),
    Governor = new_governor(
        governed_authority([<<"record">>], 1, new_budget(1))
    ),
    {ok, Child} = delegate(Governor, #{
        allowed => [<<"record">>],
        policy => fun record_policy/1
    }),
    Middleware = [
        #{
            before_tool => fun(Call) ->
                Call#{arguments => #{<<"target">> => <<"blocked">>}}
            end
        }
    ],
    expect_error(
        fun() ->
            child_run(
                Child,
                fixture_model(<<"record">>, <<"safe">>, <<"unexpected">>),
                [Record],
                <<"record safely">>,
                #{middleware => Middleware}
            )
        end,
        <<"AGENT_POLICY_DENIED">>
    ),
    check(RecordCalls() == 0, <<"reauthored arguments produced an effect">>),
    release(Child),
    io:format("final argument reauthorization: denied; effects=0~n").
