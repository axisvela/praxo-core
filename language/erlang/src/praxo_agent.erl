-module(praxo_agent).
-export([
    new_tool/2,
    new_tool/3,
    call/2,
    scripted_model/1,
    static_model/1,
    failing_model/0,
    fallback_model/2,
    generate/2,
    new_agent_options/1,
    run_agent/3
]).

new_tool(Name, Description) ->
    new_tool(Name, Description, fun(Arguments) -> Arguments end).

new_tool(Name, Description, Invoke) ->
    #{
        name => praxo_util:to_bin(Name),
        description => praxo_util:to_bin(Description),
        calls => 0,
        invoke => Invoke
    }.

call(Tool, Arguments) ->
    Updated = Tool#{calls => maps:get(calls, Tool) + 1},
    {Updated, (maps:get(invoke, Tool))(Arguments)}.

scripted_model(Steps) ->
    #{mode => scripted, script => Steps, index => 0}.

static_model(Content) ->
    #{mode => static, content => Content, index => 0}.

failing_model() ->
    #{mode => failing, index => 0}.

fallback_model(Primary, Fallback) ->
    #{mode => fallback, primary => Primary, fallback => Fallback, index => 0}.

generate(Model, Request) when is_function(Model, 1) ->
    Model(Request);
generate(#{mode := fallback, primary := Primary, fallback := Fallback} = Model, Request) ->
    case generate(Primary, Request) of
        {ok, Response, Primary2} ->
            {ok, Response, Model#{primary => Primary2}};
        {error, Code, Primary2} ->
            Model2 = Model#{primary => Primary2},
            case Fallback of
                undefined ->
                    {error, Code, Model2};
                _ ->
                    case generate(Fallback, Request) of
                        {ok, Response, Fallback2} ->
                            {ok, Response, Model2#{fallback => Fallback2}};
                        {error, FallbackCode, Fallback2} ->
                            {error, FallbackCode, Model2#{fallback => Fallback2}}
                    end
            end
    end;
generate(#{mode := static, content := Content} = Model, _Request) ->
    {ok, praxo_models:response(praxo_models:message_assistant(Content)), Model};
generate(#{mode := failing} = Model, _Request) ->
    {error, <<"MODEL_ERROR">>, Model};
generate(#{mode := scripted, script := Script, index := Index} = Model, _Request) ->
    case Index >= length(Script) of
        true ->
            {error, <<"MODEL_ERROR">>, Model};
        false ->
            {ok, lists:nth(Index + 1, Script), Model#{index => Index + 1}}
    end.

new_agent_options(Model) ->
    #{
        model => Model,
        tools => [],
        tool_selection => undefined,
        pii => false,
        structured_output => undefined,
        call_limit => undefined,
        events => undefined,
        system_prompt => <<>>,
        context => undefined,
        max_steps => 8,
        max_tokens => 0,
        session_id => <<"s1">>,
        policy => undefined,
        middleware => [],
        allowed_tools => [],
        cancellation => undefined,
        on_stream => undefined,
        max_parallel_tools => 1,
        interrupt_on => [],
        on_interrupt_decision => undefined,
        on_interrupt => undefined,
        entered => []
    }.

run_agent(Options0, Session, Prompt) ->
    RunId = unique_run_id(),
    Messages0 = maps:get(messages, Session) ++ [praxo_models:message(<<"user">>, Prompt)],
    Messages =
        case maps:get(system_prompt, Options0) of
            <<>> -> Messages0;
            SystemPrompt -> [praxo_models:message(<<"system">>, SystemPrompt) | Messages0]
        end,
    MaxSteps0 = maps:get(max_steps, Options0),
    MaxSteps = case MaxSteps0 > 0 of true -> MaxSteps0; false -> 8 end,
    Limit =
        case maps:get(call_limit, Options0) of
            undefined -> undefined;
            Value -> Value#{models => 0, tools => 0}
        end,
    case before_run(Options0#{entered => []}, RunId, Prompt) of
        {error, Reason, Options1} ->
            _ = after_run(Options1, undefined, Reason),
            {error, to_code(Reason), Options1};
        {ok, Options1} ->
            Options2 = emit(Options1, <<"run.started">>),
            case emit_stream(Options2, RunId, <<"values">>, 0, Prompt) of
                ok ->
                    case compact(Options2, Messages) of
                        {ok, Compacted} ->
                            loop(Options2, Compacted, RunId, 1, MaxSteps, praxo_models:usage(), Limit);
                        {error, Code} ->
                            fail(Options2, RunId, Code)
                    end;
                {error, Code} ->
                    fail(Options2, RunId, Code)
            end
    end.

before_run(Options, _RunId, _Prompt, []) -> {ok, Options};
before_run(Options, RunId, Prompt, [Middleware | Rest]) ->
    Options1 = Options#{entered => maps:get(entered, Options) ++ [Middleware]},
    case maps:get(before_run, Middleware, undefined) of
        undefined ->
            before_run(Options1, RunId, Prompt, Rest);
        Fun ->
            try
                Fun(#{run_id => RunId, prompt => Prompt}),
                before_run(Options1, RunId, Prompt, Rest)
            catch
                _:Reason -> {error, Reason, Options1}
            end
    end.

before_run(Options, RunId, Prompt) ->
    before_run(Options, RunId, Prompt, maps:get(middleware, Options)).

after_run(Options, Result, Error) ->
    lists:foldl(
        fun(Middleware, First) ->
            case maps:get(after_run, Middleware, undefined) of
                undefined -> First;
                Fun ->
                    try Fun(Result, Error), First
                    catch _:Caught -> case First of undefined -> Caught; _ -> First end
                    end
            end
        end,
        undefined,
        maps:get(entered, Options, [])
    ).

allowed(Options, Name) ->
    case maps:get(allowed_tools, Options, []) of
        [] -> true;
        Names -> lists:member(Name, Names)
    end.

authorize(Options, _Action) when map_get(policy, Options) == undefined -> ok;
authorize(Options, Action) ->
    case (maps:get(policy, Options))(Action) of
        #{allowed := true} -> ok;
        _ -> {error, <<"AGENT_POLICY_DENIED">>}
    end.

to_code(Reason) when is_binary(Reason) -> Reason;
to_code(Reason) -> praxo_util:to_bin(io_lib:format("~p", [Reason])).

compact(Options, Messages) ->
    case maps:get(context, Options, undefined) of
        undefined -> {ok, Messages};
        Budget ->
            case praxo_runtime:compact_context(Budget, Messages) of
                {Compacted, true} -> {ok, Compacted};
                {_Compacted, false} -> {error, <<"AGENT_CONTEXT_BUDGET">>}
            end
    end.

loop(Options, Messages, RunId, Step, MaxSteps, Total, Limit) ->
    case check_cancelled(Options) of
        {error, Code} ->
            fail(Options, RunId, Code);
        ok ->
            case Step > MaxSteps of
                true ->
                    fail(Options, RunId, <<"AGENT_MAX_STEPS">>);
                false ->
                    Specs0 = tool_specs(maps:get(tools, Options)),
                    Specs =
                        case maps:get(tool_selection, Options) of
                            undefined -> Specs0;
                            Selection -> praxo_middleware:select_tools(Selection, Specs0)
                        end,
                    RequestMessages =
                        case maps:get(pii, Options) of
                            true -> [redact_message(Message) || Message <- Messages];
                            false -> Messages
                        end,
                    Request = praxo_models:request(RequestMessages, Specs),
                    case check_model_limit(Limit) of
                        {error, Code, _} ->
                            fail(Options, RunId, Code);
                        {ok, NextLimit} ->
                            run_model(Options, Messages, Request, RunId, Step, MaxSteps, Total, NextLimit)
                    end
            end
    end.

run_model(Options, Messages, Request, RunId, Step, MaxSteps, Total, Limit) ->
    case generate(maps:get(model, Options), Request) of
        {error, Code, Model} ->
            fail(Options#{model => Model}, RunId, Code);
        {ok, Response, Model} ->
            Options1 = Options#{model => Model},
            case check_cancelled(Options1) of
                {error, Code} ->
                    fail(Options1, RunId, Code);
                ok ->
                    Total1 = praxo_models:add_usage(Total, maps:get(usage, Response)),
                    MaxTokens = maps:get(max_tokens, Options1),
                    Tokens = maps:get(input_tokens, Total1) + maps:get(output_tokens, Total1),
                    case MaxTokens > 0 andalso Tokens > MaxTokens of
                        true ->
                            fail(Options1, RunId, <<"AGENT_MAX_TOKENS">>);
                        false ->
                            Message = maps:get(message, Response),
                            Messages1 = Messages ++ [Message],
                            case maps:get(tool_calls, Message) of
                                [] ->
                                    finish(Options1, Message, RunId, Step, Total1);
                                Calls ->
                                    case invoke_tools(Options1, Calls, Messages1, RunId, Limit) of
                                        {ok, Options2, Messages2, Limit2} ->
                                            loop(
                                                Options2,
                                                Messages2,
                                                RunId,
                                                Step + 1,
                                                MaxSteps,
                                                Total1,
                                                Limit2
                                            );
                                        {error, Code, Options2} ->
                                            {error, Code, Options2}
                                    end
                            end
                    end
            end
    end.

finish(Options, Message, RunId, Step, Total) ->
    Output = maps:get(content, Message),
    Validated =
        case maps:get(structured_output, Options) of
            undefined -> {ok, Output};
            Config -> praxo_middleware:apply_structured(Config, Output)
        end,
    case Validated of
        {ok, ValidOutput} ->
            case emit_stream(Options, RunId, <<"messages">>, Step, ValidOutput) of
                {error, Code} ->
                    fail(Options, RunId, Code);
                ok ->
                    Result = praxo_models:run_result(RunId, ValidOutput, Step, Total),
                    case after_run(Options, Result, undefined) of
                        undefined ->
                            Options1 = emit(Options, <<"run.completed">>, RunId),
                            {ok, Result, Options1};
                        Reason ->
                            Options1 = emit(Options, <<"run.failed">>, RunId,
                                #{<<"error">> => to_code(Reason)}),
                            {error, to_code(Reason), Options1}
                    end
            end;
        {error, Code} when is_binary(Code) ->
            fail(Options, RunId, Code);
        {error, Error} ->
            Options1 = emit(
                Options,
                <<"run.failed">>,
                RunId,
                #{<<"error">> => <<"AGENT_STRUCTURED_OUTPUT">>}
            ),
            {error, Error, Options1}
    end.

invoke_tools(Options, Calls, Messages, RunId, Limit) ->
    Parallel =
        case maps:get(max_parallel_tools, Options, 1) of
            N when is_integer(N), N > 0 -> N;
            _ -> 1
        end,
    process_tool_batches(Options, Calls, Messages, RunId, Limit, Parallel).

process_tool_batches(Options, [], Messages, _RunId, Limit, _Parallel) ->
    {ok, Options, Messages, Limit};
process_tool_batches(Options, Calls, Messages, RunId, Limit, Parallel) ->
    case check_cancelled(Options) of
        {error, Code} ->
            tool_fail(Options, RunId, Code);
        ok ->
            Count = min(Parallel, length(Calls)),
            {Batch, Rest} = lists:split(Count, Calls),
            case prepare_batch(Options, Batch, RunId, Limit) of
                {ok, Prepared, Options1, Limit1} ->
                    case execute_batch(Options1, Prepared, Messages, Parallel) of
                        {ok, Options2, Messages1} ->
                            case check_cancelled(Options2) of
                                {error, Code} -> tool_fail(Options2, RunId, Code);
                                ok ->
                                    process_tool_batches(
                                        Options2,
                                        Rest,
                                        Messages1,
                                        RunId,
                                        Limit1,
                                        Parallel
                                    )
                            end;
                        Error ->
                            Error
                    end;
                Error ->
                    Error
            end
    end.

prepare_batch(Options, Calls, RunId, Limit) ->
    prepare_batch(Options, Calls, RunId, Limit, []).

prepare_batch(Options, [], _RunId, Limit, Acc) ->
    {ok, lists:reverse(Acc), Options, Limit};
prepare_batch(Options, [Call | Rest], RunId, Limit, Acc) ->
    case prepare_tool(Options, Call, RunId, Limit) of
        {ok, Options1, Item, Limit1} ->
            prepare_batch(Options1, Rest, RunId, Limit1, [Item | Acc]);
        Error ->
            Error
    end.

prepare_tool(Options, Call, RunId, Limit) ->
    OriginalName = maps:get(name, Call),
    OriginalArguments = maps:get(arguments, Call),
    case allowed(Options, OriginalName) of
        false ->
            tool_fail(Options, RunId, <<"AGENT_TOOL_NOT_ALLOWED">>);
        true ->
            Action = praxo_models:action(
                <<"tool.invoke">>,
                maps:get(session_id, Options),
                OriginalName,
                OriginalArguments
            ),
            case authorize(Options, Action) of
                {error, Code} ->
                    tool_fail(Options, RunId, Code);
                ok ->
                    Active = lists:foldl(
                        fun(Middleware, Current) ->
                            case maps:get(before_tool, Middleware, undefined) of
                                undefined -> Current;
                                Fun -> Fun(Current)
                            end
                        end,
                        Call,
                        maps:get(middleware, Options)
                    ),
                    Name = maps:get(name, Active),
                    case allowed(Options, Name) of
                        false ->
                            tool_fail(Options, RunId, <<"AGENT_TOOL_NOT_ALLOWED">>);
                        true ->
                            case apply_interrupt(Options, Active, RunId) of
                                {error, Options1, Code} ->
                                    tool_fail(Options1, RunId, Code);
                                {skip, Options1, Call1, Value} ->
                                    {ok, Options1,
                                     {-1, interrupt_tool(Value), Call1}, Limit};
                                {ok, Options1, Active1} ->
                                    Name1 = maps:get(name, Active1),
                                    Arguments1 = maps:get(arguments, Active1),
                                    Changed = (Name1 =/= OriginalName) orelse
                                        (Arguments1 =/= OriginalArguments),
                                    FinalAction = praxo_models:action(
                                        <<"tool.invoke">>,
                                        maps:get(session_id, Options1),
                                        Name1,
                                        Arguments1
                                    ),
                                    case Changed of
                                        true ->
                                            case authorize(Options1, FinalAction) of
                                                {error, Code} ->
                                                    tool_fail(Options1, RunId, Code);
                                                ok ->
                                                    prepare_selected_tool(
                                                        Options1, Active1, RunId, Limit
                                                    )
                                            end;
                                        false ->
                                            prepare_selected_tool(
                                                Options1, Active1, RunId, Limit
                                            )
                                    end
                            end
                    end
            end
    end.

interrupt_tool(Value) ->
    #{
        name => <<"interrupt.response">>,
        description => <<"interrupt response">>,
        calls => 0,
        invoke => fun(_Arguments) -> Value end
    }.

apply_interrupt(Options, Call, RunId) ->
    Name = maps:get(name, Call),
    case lists:member(Name, maps:get(interrupt_on, Options)) of
        false ->
            {ok, Options, Call};
        true ->
            case {maps:get(on_interrupt_decision, Options),
                  maps:get(on_interrupt, Options)} of
                {undefined, undefined} ->
                    {error, Options, <<"AGENT_INTERRUPT_UNHANDLED">>};
                {DecisionFun, _} when DecisionFun =/= undefined ->
                    Options1 = emit(
                        Options,
                        <<"tool.interrupt">>,
                        RunId,
                        #{<<"name">> => Name,
                          <<"arguments">> => maps:get(arguments, Call)}
                    ),
                    Decision = DecisionFun(#{
                        run_id => RunId,
                        session_id => maps:get(session_id, Options1),
                        call => Call
                    }),
                    case maps:get(action, Decision, <<>>) of
                        <<"approve">> ->
                            {ok, Options1, Call};
                        <<"edit">> ->
                            case maps:get(arguments, Decision, undefined) of
                                undefined ->
                                    {error, Options1,
                                     <<"AGENT_INTERRUPT_DECISION_INVALID">>};
                                Arguments ->
                                    {ok, Options1, Call#{arguments => Arguments}}
                            end;
                        <<"reject">> ->
                            {error, Options1, <<"AGENT_APPROVAL_DENIED">>};
                        <<"respond">> ->
                            {skip, Options1, Call,
                             maps:get(response, Decision, <<>>)};
                        _ ->
                            {error, Options1,
                             <<"AGENT_INTERRUPT_DECISION_INVALID">>}
                    end;
                {undefined, ApprovalFun} ->
                    Options1 = emit(
                        Options,
                        <<"tool.interrupt">>,
                        RunId,
                        #{<<"name">> => Name,
                          <<"arguments">> => maps:get(arguments, Call)}
                    ),
                    Approved = ApprovalFun(#{
                        run_id => RunId,
                        session_id => maps:get(session_id, Options1),
                        call => Call
                    }),
                    case Approved of
                        true -> {ok, Options1, Call};
                        _ -> {error, Options1, <<"AGENT_APPROVAL_DENIED">>}
                    end
            end
    end.

prepare_selected_tool(Options, Call, RunId, Limit) ->
    Name = maps:get(name, Call),
    Tools = maps:get(tools, Options),
    Index = praxo_util:index_of(
        fun(Tool) -> maps:get(name, Tool) == Name end,
        Tools
    ),
    Selection =
        case maps:get(tool_selection, Options) of
            undefined -> ok;
            Selected -> praxo_middleware:check_tool_selected(Selected, Name)
        end,
    case Selection of
        {error, Code} ->
            tool_fail(Options, RunId, Code);
        ok ->
            case Index of
                undefined ->
                    Options1 = emit(
                        Options,
                        <<"run.failed">>,
                        RunId,
                        #{<<"error">> => <<"tool not found">>}
                    ),
                    {error, <<"TOOL_NOT_FOUND">>, Options1};
                _ ->
                    case check_tool_limit(Limit) of
                        {error, Code, _} ->
                            tool_fail(Options, RunId, Code);
                        {ok, Limit1} ->
                            Tool = lists:nth(Index + 1, Tools),
                            Options1 = emit(
                                Options,
                                <<"tool.call">>,
                                RunId,
                                #{
                                    <<"name">> => Name,
                                    <<"arguments">> => maps:get(arguments, Call)
                                }
                            ),
                            {ok, Options1, {Index, Tool, Call}, Limit1}
                    end
            end
    end.

execute_batch(Options, Prepared, Messages, 1) ->
    lists:foldl(
        fun({Index, Tool, Call}, {ok, OptionsAcc, MessagesAcc}) ->
            {Tool1, Value0} = call(Tool, maps:get(arguments, Call)),
            UpdatedTools =
                case Index of
                    -1 -> maps:get(tools, OptionsAcc);
                    _ -> replace_at(maps:get(tools, OptionsAcc), Index, Tool1)
                end,
            OptionsAcc1 = OptionsAcc#{tools => UpdatedTools},
            Value =
                case maps:get(pii, OptionsAcc1) of
                    true -> praxo_middleware:redact_value(Value0);
                    false -> Value0
                end,
            MessagesAcc1 = MessagesAcc ++ [
                praxo_models:message_tool(
                    praxo_json:encode(Value),
                    maps:get(id, Call)
                )
            ],
            {ok, OptionsAcc1, MessagesAcc1}
        end,
        {ok, Options, Messages},
        Prepared
    );
execute_batch(Options, Prepared, Messages, _Parallel) ->
    Parent = self(),
    Refs = [
        begin
            Ref = make_ref(),
            {Pid, Mon} = spawn_monitor(fun() ->
                Parent ! {Ref, call(Tool, maps:get(arguments, Call))}
            end),
            {Ref, Pid, Mon, Call, Index}
        end
     || {Index, Tool, Call} <- Prepared
    ],
    lists:foldl(
        fun({Ref, _Pid, Mon, Call, Index}, {ok, OptionsAcc, MessagesAcc}) ->
            receive
                {Ref, {Tool1, Value0}} ->
                    receive
                        {'DOWN', Mon, process, _, _} -> ok
                    after
                        0 -> ok
                    end,
                    UpdatedTools =
                        case Index of
                            -1 -> maps:get(tools, OptionsAcc);
                            _ -> replace_at(
                                maps:get(tools, OptionsAcc), Index, Tool1
                            )
                        end,
                    OptionsAcc1 = OptionsAcc#{tools => UpdatedTools},
                    Value =
                        case maps:get(pii, OptionsAcc1) of
                            true -> praxo_middleware:redact_value(Value0);
                            false -> Value0
                        end,
                    MessagesAcc1 = MessagesAcc ++ [
                        praxo_models:message_tool(
                            praxo_json:encode(Value),
                            maps:get(id, Call)
                        )
                    ],
                    {ok, OptionsAcc1, MessagesAcc1};
                {'DOWN', Mon, process, _, Reason} ->
                    {error, to_code(Reason), OptionsAcc}
            after
                30000 ->
                    {error, <<"TOOL_TIMEOUT">>, OptionsAcc}
            end
        end,
        {ok, Options, Messages},
        Refs
    ).

replace_at(List, Index, Value) ->
    lists:sublist(List, Index) ++ [Value] ++ lists:nthtail(Index + 1, List).

tool_fail(Options, RunId, Code) ->
    {error, ErrorCode, Options1} = fail(Options, RunId, Code),
    {error, ErrorCode, Options1}.

check_model_limit(undefined) -> {ok, undefined};
check_model_limit(Limit) -> praxo_middleware:model_call(Limit).

check_tool_limit(undefined) -> {ok, undefined};
check_tool_limit(Limit) -> praxo_middleware:tool_call(Limit).

redact_message(Message) ->
    Blocks = [
        case maps:get(text, Block) of
            Text when is_binary(Text) -> Block#{text => praxo_middleware:pii_redact(Text)};
            _ -> Block
        end
     || Block <- maps:get(content_blocks, Message)
    ],
    ToolCalls = [
        Call#{arguments => praxo_middleware:redact_value(maps:get(arguments, Call))}
     || Call <- maps:get(tool_calls, Message)
    ],
    Message#{
        content => praxo_middleware:pii_redact(maps:get(content, Message)),
        content_blocks => Blocks,
        tool_calls => ToolCalls
    }.

tool_specs(Tools) ->
    [
        praxo_models:tool_spec(maps:get(name, Tool), maps:get(description, Tool))
     || Tool <- Tools
    ].

emit(Options, Kind) ->
    emit(Options, Kind, undefined, null).

emit(Options, Kind, RunId) ->
    emit(Options, Kind, RunId, null).

emit(Options, Kind, RunId, Data) ->
    case maps:get(events, Options) of
        undefined ->
            Options;
        Sink ->
            Event = praxo_models:event(Kind, maps:get(session_id, Options), RunId, Data),
            Options#{events => praxo_sink:emit(Sink, Event)}
    end.

check_cancelled(Options) ->
    case maps:get(cancellation, Options, undefined) of
        undefined ->
            ok;
        Cancellation when is_function(Cancellation, 0) ->
            case Cancellation() of
                true -> {error, <<"AGENT_CANCELLED">>};
                _ -> ok
            end;
        Cancellation when is_function(Cancellation, 1) ->
            case Cancellation(Options) of
                true -> {error, <<"AGENT_CANCELLED">>};
                _ -> ok
            end;
        true ->
            {error, <<"AGENT_CANCELLED">>};
        _ ->
            ok
    end.

emit_stream(Options, RunId, Kind, Step, Data) ->
    case maps:get(on_stream, Options, undefined) of
        undefined ->
            ok;
        Fun ->
            Part = praxo_models:stream_part(
                RunId,
                maps:get(session_id, Options),
                Kind,
                Step,
                Data
            ),
            try
                Fun(Part),
                ok
            catch
                _:_ -> {error, <<"STREAM_ERROR">>}
            end
    end.

fail(Options, RunId, Code) ->
    _ = after_run(Options, undefined, Code),
    Options1 = emit(Options, <<"run.failed">>, RunId, #{<<"error">> => Code}),
    {error, Code, Options1}.

unique_run_id() ->
    Nanos = erlang:system_time(nanosecond),
    Unique = erlang:unique_integer([positive, monotonic]),
    <<"run-", (integer_to_binary(Nanos))/binary, "-", (integer_to_binary(Unique))/binary>>.
