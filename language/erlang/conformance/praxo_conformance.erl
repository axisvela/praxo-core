-module(praxo_conformance).
-export([main/0, main/1]).

-define(GROUPS, [
    <<"agent-loop">>,
    <<"checkpoint">>,
    <<"context">>,
    <<"event">>,
    <<"jsonschema">>,
    <<"memory">>,
    <<"middleware">>,
    <<"plugin">>,
    <<"policy">>,
    <<"stream">>,
    <<"toolcall">>
]).

main() -> main(["../../spec"]).

main([SpecDir]) ->
    Version = string:trim(element(2, file:read_file(filename:join(SpecDir, "SPEC_VERSION")))),
    {Failures, _Seen} = lists:foldl(
        fun(Group, {Failures0, Seen0}) ->
            Path = filename:join([SpecDir, "vectors", binary_to_list(Group) ++ ".json"]),
            {ok, Content} = file:read_file(Path),
            {ok, File} = praxo_json:parse(Content),
            Failures1 = check_meta(Failures0, Group, File, Version),
            Vectors = praxo_json:get_array(File, <<"vectors">>),
            lists:foldl(
                fun(Vector, {Failures2, Seen2}) ->
                    Id = praxo_util:default(praxo_json:get_string(Vector, <<"id">>), <<>>),
                    Failures3 =
                        case sets:is_element(Id, Seen2) of
                            true -> Failures2 ++ [format_failure(Group, Id, <<"duplicate id">>)];
                            false -> Failures2
                        end,
                    Seen3 = sets:add_element(Id, Seen2),
                    Result =
                        try
                            run_vector(Group, Vector),
                            ok
                        catch
                            Class:Reason:Stack ->
                                format_exception(Class, Reason, Stack)
                        end,
                    case Result of
                        ok -> {Failures3, Seen3};
                        Message -> {Failures3 ++ [format_failure(Group, Id, Message)], Seen3}
                    end
                end,
                {Failures1, Seen0},
                Vectors
            )
        end,
        {[], sets:new()},
        ?GROUPS
    ),
    case Failures of
        [] ->
            io:format("all spec vectors passed~n"),
            halt(0);
        _ ->
            lists:foreach(fun(Message) -> io:format(standard_error, "~s~n", [Message]) end, Failures),
            halt(1)
    end.

check_meta(Failures, Group, File, Version) ->
    Failures1 =
        case praxo_json:get_string(File, <<"group">>) of
            Group -> Failures;
            _ -> Failures ++ [format_failure(Group, <<"meta">>, <<"group mismatch">>)]
        end,
    case praxo_json:get_string(File, <<"specVersion">>) of
        Version -> Failures1;
        _ -> Failures1 ++ [format_failure(Group, <<"meta">>, <<"specVersion mismatch">>)]
    end.

format_failure(Group, Id, Message) ->
    iolist_to_binary([Group, "/", Id, ": ", Message]).

format_exception(Class, Reason, Stack) ->
    iolist_to_binary(io_lib:format("~p:~p~n~p", [Class, Reason, Stack])).

check(true, _Message) -> ok;
check(false, Message) -> throw(Message).

node_or(Node, Key, Fallback) when is_map(Node) -> maps:get(Key, Node, Fallback);
node_or(_, _, Fallback) -> Fallback.

run_vector(Group, Vector) ->
    Input = node_or(Vector, <<"input">>, #{}),
    Expect = node_or(Vector, <<"expect">>, #{}),
    case Group of
        <<"toolcall">> -> run_toolcall(Input, Expect);
        <<"jsonschema">> -> run_jsonschema(Input, Expect);
        <<"plugin">> -> run_plugin(Input, Expect);
        <<"memory">> -> run_memory(Input, Expect);
        <<"event">> -> run_event(Input, Expect);
        <<"stream">> -> run_stream(Expect);
        <<"checkpoint">> -> run_checkpoint(Input, Expect);
        <<"policy">> -> run_policy(Input, Expect);
        <<"context">> -> run_context(Input, Expect);
        <<"middleware">> -> run_middleware(Input, Expect);
        <<"agent-loop">> -> run_agent_loop(Input, Expect);
        _ -> throw(<<"no runner for group">>)
    end.

run_toolcall(Input, Expect) ->
    Operation = praxo_util:default(praxo_json:get_string(Input, <<"operation">>), <<>>),
    Content = praxo_util:default(praxo_json:get_string(Input, <<"content">>), <<>>),
    case Operation of
        <<"strip">> ->
            check(
                praxo_toolcall:strip_tool_call_markup(Content) ==
                    praxo_util:default(praxo_json:get_string(Expect, <<"text">>), <<>>),
                <<"strip mismatch">>
            );
        _ ->
            case praxo_toolcall:parse_tool_call(Content) of
                {ok, Call} ->
                    check(not praxo_json:get_bool(Expect, <<"nil">>), <<"expected nil">>),
                    check(
                        maps:get(name, Call) ==
                            praxo_util:default(praxo_json:get_string(Expect, <<"name">>), <<>>),
                        <<"name mismatch">>
                    ),
                    check(
                        praxo_json:equals(
                            maps:get(arguments, Call),
                            node_or(Expect, <<"input">>, #{})
                        ),
                        <<"input mismatch">>
                    );
                error ->
                    check(praxo_json:get_bool(Expect, <<"nil">>), <<"expected a tool call">>)
            end
    end.

run_jsonschema(Input, Expect) ->
    Schema = node_or(Input, <<"schema">>, null),
    Data = node_or(Input, <<"data">>, null),
    Errors = praxo_jsonschema:validate(Schema, Data),
    Paths = lists:sort([maps:get(path, Error) || Error <- Errors]),
    Expected = lists:sort(praxo_json:get_array(Expect, <<"errorPaths">>)),
    check((Errors == []) == praxo_json:get_bool(Expect, <<"valid">>), <<"valid mismatch">>),
    check(praxo_json:equals(Paths, Expected), <<"errorPaths mismatch">>).

run_plugin(Input, Expect) ->
    Raw =
        case praxo_json:get_string(Input, <<"raw">>) of
            undefined -> praxo_json:encode(node_or(Input, <<"manifest">>, null));
            Value -> Value
        end,
    case praxo_plugin:parse_manifest(Raw) of
        {ok, Manifest} ->
            check(praxo_json:get_bool(Expect, <<"valid">>), <<"valid mismatch">>),
            case praxo_json:get_string(Expect, <<"id">>) of
                undefined -> ok;
                Id -> check(maps:get(id, Manifest) == Id, <<"id mismatch">>)
            end,
            case praxo_json:get_string(Expect, <<"kind">>) of
                undefined -> ok;
                Kind -> check(maps:get(kind, Manifest) == Kind, <<"kind mismatch">>)
            end;
        {error, _} ->
            check(not praxo_json:get_bool(Expect, <<"valid">>), <<"valid mismatch">>)
    end.

run_memory(Input, Expect) ->
    Store0 = praxo_memory:new(),
    Store = lists:foldl(
        fun(Put, Acc) ->
            RecordValue = node_or(Put, <<"record">>, #{}),
            Record = praxo_models:memory_record(
                praxo_util:default(praxo_json:get_string(RecordValue, <<"id">>), <<>>),
                praxo_util:default(praxo_json:get_string(RecordValue, <<"frame">>), <<>>),
                praxo_util:default(praxo_json:get_string(RecordValue, <<"content">>), <<>>),
                praxo_json:get_string(RecordValue, <<"createdAt">>)
            ),
            {Store1, _} = praxo_memory:put(
                Acc,
                praxo_util:default(praxo_json:get_string(Put, <<"session">>), <<>>),
                Record
            ),
            Store1
        end,
        Store0,
        praxo_json:get_array(Input, <<"puts">>)
    ),
    Records = praxo_memory:search(
        Store,
        praxo_util:default(praxo_json:get_string(Input, <<"session">>), <<>>),
        praxo_util:default(praxo_json:get_string(Input, <<"query">>), <<>>),
        praxo_json:get_int(Input, <<"limit">>)
    ),
    Ids = case Records of [] -> null; _ -> [maps:get(id, R) || R <- Records] end,
    Contents = case Records of [] -> null; _ -> [maps:get(content, R) || R <- Records] end,
    check(praxo_json:equals(Ids, node_or(Expect, <<"ids">>, null)), <<"ids mismatch">>),
    check(praxo_json:equals(Contents, node_or(Expect, <<"contents">>, null)), <<"contents mismatch">>).

run_event(Input, Expect) ->
    Events = [
        praxo_models:event(Kind, <<"s1">>)
     || Kind <- praxo_json:get_array(Input, <<"events">>)
    ],
    SinkMode = praxo_util:default(praxo_json:get_string(Input, <<"sink">>), <<"filter">>),
    case SinkMode of
        <<"multi">> ->
            Count = max(1, praxo_json:get_int(Input, <<"sinkCount">>, 1)),
            Sinks = [praxo_sink:new() || _ <- lists:seq(1, Count)],
            Multi = praxo_sink:multi(Sinks),
            Final = lists:foldl(fun(Event, Sink) -> praxo_sink:emit(Sink, Event) end, Multi, Events),
            PerSink = [praxo_sink:kinds(Sink) || Sink <- maps:get(sinks, Final)],
            check(
                praxo_json:equals(PerSink, node_or(Expect, <<"perSink">>, null)),
                <<"perSink mismatch">>
            );
        _ ->
            Base = praxo_sink:new(),
            Predicate = praxo_json:get_array(Input, <<"predicateTypes">>),
            Filter = praxo_sink:filter(Base, Predicate),
            Final = lists:foldl(fun(Event, Sink) -> praxo_sink:emit(Sink, Event) end, Filter, Events),
            TargetKinds = praxo_sink:kinds(maps:get(target, Final)),
            Delivered = case TargetKinds of [] -> null; _ -> TargetKinds end,
            check(
                praxo_json:equals(Delivered, node_or(Expect, <<"delivered">>, null)),
                <<"delivered mismatch">>
            )
    end.

run_stream(Expect) ->
    check(
        praxo_json:equals(praxo_models:stream_kinds(), node_or(Expect, <<"kinds">>, null)),
        <<"kinds mismatch">>
    ).

run_checkpoint(Input, Expect) ->
    Allow = lists:foldl(
        fun(Kind, Acc) -> praxo_checkpoint:register(Acc, Kind) end,
        praxo_checkpoint:new(),
        praxo_json:get_array(Input, <<"registered">>)
    ),
    Operation = praxo_util:default(praxo_json:get_string(Input, <<"operation">>), <<"roundtrip">>),
    Kind = praxo_util:default(praxo_json:get_string(Input, <<"type">>), <<>>),
    Value = node_or(Input, <<"value">>, null),
    case Operation of
        <<"roundtrip">> ->
            {ok, Data} = praxo_checkpoint:marshal(Allow, Kind, Value),
            {ok, Decoded} = praxo_checkpoint:unmarshal(Allow, Data),
            check(
                praxo_json:equals(Decoded, node_or(Expect, <<"value">>, null)),
                <<"value mismatch">>
            );
        <<"marshal">> ->
            Code =
                case praxo_checkpoint:marshal(Allow, Kind, Value) of
                    {ok, _} -> <<>>;
                    {error, Error} -> Error
                end,
            check(
                Code == praxo_util:default(praxo_json:get_string(Expect, <<"errorCode">>), <<>>),
                <<"errorCode mismatch">>
            );
        <<"unmarshal">> ->
            Envelope = praxo_json:encode(#{<<"type">> => Kind, <<"data">> => Value}),
            Code =
                case praxo_checkpoint:unmarshal(Allow, Envelope) of
                    {ok, _} -> <<>>;
                    {error, Error} -> Error
                end,
            check(
                Code == praxo_util:default(praxo_json:get_string(Expect, <<"errorCode">>), <<>>),
                <<"errorCode mismatch">>
            )
    end.

run_policy(Input, Expect) ->
    Grants = [
        praxo_models:path_grant(
            praxo_util:default(praxo_json:get_string(Item, <<"root">>), <<>>),
            praxo_util:default(praxo_json:get_string(Item, <<"access">>), <<"read">>)
        )
     || Item <- praxo_json:get_array(Input, <<"grants">>)
    ],
    Checker = praxo_runtime:path_checker(Grants),
    Target = praxo_util:default(praxo_json:get_string(Input, <<"target">>), <<>>),
    Need = praxo_util:default(praxo_json:get_string(Input, <<"need">>), <<"read">>),
    case praxo_json:get_bool(Expect, <<"error">>) of
        true ->
            Failed =
                try
                    praxo_runtime:check(Checker, Target, Need),
                    false
                catch
                    error:{policy_error, _} -> true
                end,
            check(Failed, <<"expected a policy error">>);
        false ->
            Decision = praxo_runtime:check(Checker, Target, Need),
            check(
                maps:get(allowed, Decision) == praxo_json:get_bool(Expect, <<"allowed">>),
                <<"allowed mismatch">>
            )
    end.

run_context(Input, Expect) ->
    Messages = [
        praxo_models:message(
            praxo_util:default(praxo_json:get_string(Item, <<"role">>), <<>>),
            praxo_util:default(praxo_json:get_string(Item, <<"content">>), <<>>)
        )
     || Item <- praxo_json:get_array(Input, <<"messages">>)
    ],
    case praxo_util:default(praxo_json:get_string(Input, <<"operation">>), <<>>) of
        <<"estimate">> ->
            check(
                praxo_runtime:estimate_tokens(Messages) ==
                    praxo_json:get_int(Expect, <<"tokens">>),
                <<"tokens mismatch">>
            );
        _ ->
            BudgetValue = node_or(Input, <<"budget">>, #{}),
            Budget = praxo_models:context_budget(
                praxo_json:get_int(BudgetValue, <<"maxTokens">>),
                praxo_json:get_int(BudgetValue, <<"keepRecent">>)
            ),
            {Output, Ok} = praxo_runtime:compact_context(Budget, Messages),
            check(Ok == praxo_json:get_bool(Expect, <<"ok">>), <<"ok mismatch">>),
            case Ok of
                true ->
                    check(
                        praxo_runtime:estimate_tokens(Output) ==
                            praxo_json:get_int(Expect, <<"tokens">>),
                        <<"tokens mismatch">>
                    ),
                    Wire = [praxo_models:message_wire(Message) || Message <- Output],
                    check(
                        praxo_json:equals(Wire, node_or(Expect, <<"messages">>, null)),
                        <<"messages mismatch">>
                    );
                false ->
                    ok
            end
    end.

run_middleware(Input, Expect) ->
    Operation = praxo_util:default(praxo_json:get_string(Input, <<"operation">>), <<>>),
    case Operation of
        <<"pii">> ->
            check(
                praxo_middleware:pii_redact(
                    praxo_util:default(praxo_json:get_string(Input, <<"text">>), <<>>)
                ) == praxo_util:default(praxo_json:get_string(Expect, <<"text">>), <<>>),
                <<"text mismatch">>
            );
        <<"pii-value">> ->
            check(
                praxo_json:equals(
                    praxo_middleware:redact_value(node_or(Input, <<"value">>, null)),
                    node_or(Expect, <<"value">>, null)
                ),
                <<"value mismatch">>
            );
        <<"structured">> ->
            Repair = praxo_json:get_string(Input, <<"repairOutput">>),
            Repairer =
                case Repair of
                    undefined -> undefined;
                    _ -> fun(_Text) -> {ok, Repair} end
                end,
            Config = praxo_middleware:structured_output(
                node_or(Input, <<"schema">>, #{}),
                praxo_json:get_int(Input, <<"maxRepairs">>),
                Repairer
            ),
            Result = praxo_middleware:apply_structured(
                Config,
                praxo_util:default(praxo_json:get_string(Input, <<"output">>), <<>>)
            ),
            case Result of
                {ok, Output} ->
                    check(praxo_json:get_bool(Expect, <<"ok">>), <<"expected error">>),
                    check(
                        Output ==
                            praxo_util:default(praxo_json:get_string(Expect, <<"output">>), <<>>),
                        <<"output mismatch">>
                    );
                {error, Code} ->
                    check(not praxo_json:get_bool(Expect, <<"ok">>), <<"expected success">>),
                    check(
                        Code ==
                            praxo_util:default(praxo_json:get_string(Expect, <<"errorCode">>), <<>>),
                        <<"errorCode mismatch">>
                    )
            end;
        <<"call-limit">> ->
            Limit0 = praxo_middleware:call_limit(
                praxo_json:get_int(Input, <<"modelLimit">>),
                praxo_json:get_int(Input, <<"toolLimit">>)
            ),
            {Outcomes, _} = lists:foldl(
                fun(Call, {Acc, Limit}) ->
                    {Code, Next} =
                        case Call of
                            <<"model">> ->
                                case praxo_middleware:model_call(Limit) of
                                    {ok, Value} -> {<<"ok">>, Value};
                                    {error, Error, Value} -> {Error, Value}
                                end;
                            _ ->
                                case praxo_middleware:tool_call(Limit) of
                                    {ok, Value} -> {<<"ok">>, Value};
                                    {error, Error, Value} -> {Error, Value}
                                end
                        end,
                    {Acc ++ [Code], Next}
                end,
                {[], Limit0},
                praxo_json:get_array(Input, <<"calls">>)
            ),
            check(
                praxo_json:equals(Outcomes, node_or(Expect, <<"outcomes">>, null)),
                <<"outcomes mismatch">>
            );
        <<"tool-selection">> ->
            Selected = praxo_json:get_array(Input, <<"selected">>),
            Selection = praxo_middleware:tool_selection(Selected),
            Tools = [
                praxo_models:tool_spec(Name, <<>>)
             || Name <- praxo_json:get_array(Input, <<"tools">>)
            ],
            Advertised = [
                maps:get(name, Tool)
             || Tool <- praxo_middleware:select_tools(Selection, Tools)
            ],
            check(
                praxo_json:equals(Advertised, node_or(Expect, <<"advertised">>, null)),
                <<"advertised mismatch">>
            ),
            Reject =
                case praxo_middleware:check_tool_selected(
                    Selection,
                    praxo_util:default(praxo_json:get_string(Input, <<"requested">>), <<>>)
                ) of
                    ok -> <<"ok">>;
                    {error, Code} -> Code
                end,
            check(
                Reject ==
                    praxo_util:default(praxo_json:get_string(Expect, <<"reject">>), <<>>),
                <<"reject mismatch">>
            );
        <<"fallback">> ->
            Content = praxo_util:default(
                praxo_json:get_string(Input, <<"fallbackContent">>),
                <<>>
            ),
            Model = praxo_agent:fallback_model(
                praxo_agent:failing_model(),
                praxo_agent:static_model(Content)
            ),
            {ok, Response, _} = praxo_agent:generate(
                Model,
                praxo_models:request([])
            ),
            check(
                maps:get(content, maps:get(message, Response)) == Content,
                <<"output mismatch">>
            );
        _ ->
            throw(<<"unknown middleware operation">>)
    end.

run_agent_loop(Input, Expect) ->
    Tools = [
        praxo_agent:new_tool(
            praxo_util:default(praxo_json:get_string(Item, <<"name">>), <<>>),
            praxo_util:default(praxo_json:get_string(Item, <<"description">>), <<>>)
        )
     || Item <- praxo_json:get_array(Input, <<"tools">>)
    ],
    Script = [
        begin
            Calls = [
                praxo_models:tool_call(
                    praxo_util:default(praxo_json:get_string(Call, <<"id">>), <<>>),
                    praxo_util:default(praxo_json:get_string(Call, <<"name">>), <<>>),
                    node_or(Call, <<"arguments">>, #{})
                )
             || Call <- praxo_json:get_array(Item, <<"toolCalls">>)
            ],
            praxo_models:response(
                praxo_models:message_assistant(
                    praxo_util:default(praxo_json:get_string(Item, <<"content">>), <<>>),
                    Calls
                ),
                praxo_models:usage(
                    praxo_json:get_int(Item, <<"inputTokens">>),
                    praxo_json:get_int(Item, <<"outputTokens">>)
                )
            )
        end
     || Item <- praxo_json:get_array(Input, <<"script">>)
    ],
    Model = praxo_agent:scripted_model(Script),
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => Tools,
        max_steps => praxo_json:get_int(Input, <<"maxSteps">>),
        max_tokens => praxo_json:get_int(Input, <<"maxTokens">>),
        events => praxo_sink:new()
    },
    Session = praxo_models:session(<<"s1">>),
    Prompt = praxo_util:default(praxo_json:get_string(Input, <<"prompt">>), <<>>),
    case praxo_agent:run_agent(Options, Session, Prompt) of
        {ok, Result, Returned} ->
            check(not praxo_json:get_bool(Expect, <<"error">>), <<"unexpected error">>),
            check(
                maps:get(output, Result) ==
                    praxo_util:default(praxo_json:get_string(Expect, <<"output">>), <<>>),
                <<"output mismatch">>
            ),
            check(
                maps:get(steps, Result) == praxo_json:get_int(Expect, <<"steps">>),
                <<"steps mismatch">>
            ),
            check_agent_events(Returned, Expect);
        {error, Code, Returned} ->
            check(praxo_json:get_bool(Expect, <<"error">>), <<"unexpected success">>),
            case praxo_json:get_string(Expect, <<"errorCode">>) of
                undefined -> ok;
                Expected -> check(Code == Expected, <<"errorCode mismatch">>)
            end,
            check_agent_events(Returned, Expect)
    end.

check_agent_events(Options, Expect) ->
    Invocations = lists:sum([maps:get(calls, Tool) || Tool <- maps:get(tools, Options)]),
    check(
        Invocations == praxo_json:get_int(Expect, <<"toolInvocations">>),
        <<"tool invocations mismatch">>
    ),
    Sink = maps:get(events, Options),
    Kinds = praxo_sink:kinds(Sink),
    Events = case Kinds of [] -> null; _ -> Kinds end,
    check(praxo_json:equals(Events, node_or(Expect, <<"events">>, null)), <<"events mismatch">>).
