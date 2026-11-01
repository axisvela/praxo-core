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
            case compact(Options2, Messages) of
                {ok, Compacted} ->
                    loop(Options2, Compacted, RunId, 1, MaxSteps, praxo_models:usage(), Limit);
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

loop(Options, _Messages, RunId, Step, MaxSteps, _Total, _Limit) when Step > MaxSteps ->
    fail(Options, RunId, <<"AGENT_MAX_STEPS">>);
loop(Options, Messages, RunId, Step, MaxSteps, Total, Limit) ->
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
    end.

run_model(Options, Messages, Request, RunId, Step, MaxSteps, Total, Limit) ->
    case generate(maps:get(model, Options), Request) of
        {error, Code, Model} ->
            fail(Options#{model => Model}, RunId, Code);
        {ok, Response, Model} ->
            Options1 = Options#{model => Model},
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
            Result = praxo_models:run_result(RunId, ValidOutput, Step, Total),
            case after_run(Options, Result, undefined) of
                undefined ->
                    Options1 = emit(Options, <<"run.completed">>, RunId),
                    {ok, Result, Options1};
                Reason ->
                    Options1 = emit(Options, <<"run.failed">>, RunId,
                        #{<<"error">> => to_code(Reason)}),
                    {error, to_code(Reason), Options1}
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

invoke_tools(Options, [], Messages, _RunId, Limit) ->
    {ok, Options, Messages, Limit};
invoke_tools(Options, [Call | Rest], Messages, RunId, Limit) ->
    OriginalName = maps:get(name, Call),
    OriginalArguments = maps:get(arguments, Call),
    case allowed(Options, OriginalName) of
        false ->
            fail(Options, RunId, <<"AGENT_TOOL_NOT_ALLOWED">>);
        true ->
            Action = praxo_models:action(<<"tool.invoke">>, maps:get(session_id, Options),
                OriginalName, OriginalArguments),
            case authorize(Options, Action) of
                {error, Code} ->
                    fail(Options, RunId, Code);
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
                    Arguments = maps:get(arguments, Active),
                    case allowed(Options, Name) of
                        false ->
                            fail(Options, RunId, <<"AGENT_TOOL_NOT_ALLOWED">>);
                        true ->
                            Changed = (Name =/= OriginalName) orelse (Arguments =/= OriginalArguments),
                            FinalAction = praxo_models:action(<<"tool.invoke">>,
                                maps:get(session_id, Options), Name, Arguments),
                            case Changed of
                                true ->
                                    case authorize(Options, FinalAction) of
                                        {error, Code} -> fail(Options, RunId, Code);
                                        ok -> run_prepared(Options, Active, Rest, Messages, RunId, Limit)
                                    end;
                                false ->
                                    run_prepared(Options, Active, Rest, Messages, RunId, Limit)
                            end
                    end
            end
    end.

run_prepared(Options, Call, Rest, Messages, RunId, Limit) ->
    Name = maps:get(name, Call),
    Tools = maps:get(tools, Options),
    Index = praxo_util:index_of(fun(Tool) -> maps:get(name, Tool) == Name end, Tools),
    Selection =
        case maps:get(tool_selection, Options) of
            undefined -> ok;
            Selected -> praxo_middleware:check_tool_selected(Selected, Name)
        end,
    case Selection of
        {error, Code} ->
            fail(Options, RunId, Code);
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
                            fail(Options, RunId, Code);
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
                            {Tool1, Value0} = call(Tool, maps:get(arguments, Call)),
                            UpdatedTools =
                                lists:sublist(Tools, Index) ++
                                    [Tool1] ++ lists:nthtail(Index + 1, Tools),
                            Options2 = Options1#{tools => UpdatedTools},
                            Value =
                                case maps:get(pii, Options2) of
                                    true -> praxo_middleware:redact_value(Value0);
                                    false -> Value0
                                end,
                            Messages1 = Messages ++ [
                                praxo_models:message_tool(
                                    praxo_json:encode(Value),
                                    maps:get(id, Call)
                                )
                            ],
                            invoke_tools(Options2, Rest, Messages1, RunId, Limit1)
                    end
            end
    end.

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

fail(Options, RunId, Code) ->
    _ = after_run(Options, undefined, Code),
    Options1 = emit(Options, <<"run.failed">>, RunId, #{<<"error">> => Code}),
    {error, Code, Options1}.

unique_run_id() ->
    Nanos = erlang:system_time(nanosecond),
    Unique = erlang:unique_integer([positive, monotonic]),
    <<"run-", (integer_to_binary(Nanos))/binary, "-", (integer_to_binary(Unique))/binary>>.
