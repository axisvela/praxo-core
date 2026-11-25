-module(praxo_ops_agent).
-export([run/2, run/3, run_traced/3]).

run(Tenant, Service) ->
    run(Tenant, Service, <<"Investigate the incident and draft a review-only remediation.">>).

run(Tenant, Service, Intent) ->
    {Result, _Trace} = run_traced(Tenant, Service, Intent),
    Result.

run_traced(Tenant, Service, Intent) ->
    TraceTab = ets:new(praxo_ops_trace, [ordered_set, public]),
    put(reads, 0),
    put(drafts, 0),
    put(executions, 0),
    {BaseModel, Mode} = select_model(Service, Intent),
    Model = fun F(Request) ->
        Result = BaseModel(Request),
        record_trace(TraceTab, Request, Result),
        case Result of
            {ok, Response, _State} -> {ok, Response, F};
            {error, Code, _State} -> {error, Code, F}
        end
    end,
    Options0 = praxo_agent:new_agent_options(Model),
    Options = Options0#{
        tools => tools(),
        allowed_tools => [
            <<"search_signals">>,
            <<"draft_remediation">>,
            <<"execute_remediation">>
        ],
        policy => policy(Tenant),
        require_policy => true,
        require_tool_scope => true,
        max_steps => 4,
        max_tokens => 60000,
        system_prompt => system_prompt(Tenant)
    },
    Session = praxo_models:session(session_id(Tenant, Service, Intent)),
    Result = praxo_agent:run_agent(Options, Session, Intent),
    Trace = [Step || {_Key, Step} <- ets:tab2list(TraceTab)],
    ets:delete(TraceTab),
    Stats = stats(),
    Outcome =
        case Result of
            {ok, RunResult, _Options} ->
                Output = maps:get(output, RunResult),
                case parse_report(Output) of
                    {ok, Report0} ->
                        Report = normalize_report(Report0, Service, Trace),
                        Required = [
                            <<"service">>,
                            <<"signals">>,
                            <<"remediation">>,
                            <<"executions">>
                        ],
                        Valid = lists:all(fun(Key) -> maps:is_key(Key, Report) end, Required)
                            andalso maps:get(<<"executions">>, Report, 0) =:= 0,
                        case Valid of
                            true ->
                                Final = Report#{
                                    <<"tenant">> => Tenant,
                                    <<"model">> => Mode,
                                    <<"agent_trace">> => Trace
                                },
                                {ok, Final, Stats};
                            false ->
                                {error, Output, Stats}
                        end;
                    error ->
                        {error, Output, Stats}
                end;
            {error, Code, _Options} ->
                {error, Code, Stats}
        end,
    {Outcome, Trace}.

select_model(Service, Intent) ->
    case live_model() of
        {ok, Live} ->
            {Live, <<"live">>};
        none ->
            {deterministic_model(Service, Intent), <<"deterministic">>}
    end.

live_model() ->
    case {os:getenv("PRAXO_BASE_URL"), os:getenv("PRAXO_MODEL")} of
        {false, _} ->
            none;
        {_, false} ->
            none;
        {"", _} ->
            none;
        {_, ""} ->
            none;
        {BaseUrl, ModelName} ->
            Key =
                case os:getenv("PRAXO_API_KEY") of
                    false -> <<>>;
                    Value -> list_to_binary(Value)
                end,
            Base = list_to_binary(string:trim(BaseUrl, trailing, "/")),
            AdapterOptions = maps:merge(
                #{api_key => Key},
                transport_options(Base)
            ),
            Adapter = praxo_openai_compatible:new(
                Base,
                list_to_binary(ModelName),
                AdapterOptions
            ),
            Live = fun(Request) ->
                {ok, Response, Adapter2} = praxo_openai_compatible:generate(
                    Adapter,
                    Request#{tools => tool_specs()}
                ),
                {ok, Response, Adapter2}
            end,
            {ok, Live}
    end.

transport_options(Base) ->
    case {os:getenv("PRAXO_CA_BUNDLE"), os:getenv("PRAXO_HTTP_PROXY")} of
        {false, _} ->
            #{};
        {_, false} ->
            #{};
        {CaFile, ProxyUrl} ->
            Ca = list_to_binary(CaFile),
            Proxy = list_to_binary(ProxyUrl),
            #{
                transport => fun(Path, Payload) ->
                    http_post(Base, Ca, Proxy, Path, Payload)
                end
            }
    end.

http_post(Base, Ca, Proxy, Path, Payload) ->
    inets:start(),
    ssl:start(),
    Url = binary_to_list(<<Base/binary, Path/binary>>),
    Headers = [
        {"content-type", "application/json"},
        {"authorization", "Bearer " ++ binary_to_list(api_key())}
    ],
    ok = httpc:set_options(proxy_options(Proxy)),
    Options = [
        {timeout, 60000},
        {ssl, [{cacertfile, binary_to_list(Ca)}]}
    ],
    case httpc:request(
        post,
        {Url, Headers, "application/json", praxo_json:encode(Payload)},
        Options,
        [{body_format, binary}]
    ) of
        {ok, {{_, Status, _}, _, Body}} when Status >= 200, Status < 300 ->
            case praxo_json:parse(Body) of
                {ok, Data} -> {ok, Data};
                {error, _} -> {error, <<"PROVIDER_JSON">>}
            end;
        {ok, {{_, Status, _}, _, _}} ->
            {error, <<"PROVIDER_HTTP_", (integer_to_binary(Status))/binary>>};
        {error, _} ->
            {error, <<"PROVIDER_HTTP">>}
    end.

proxy_options(Proxy) ->
    try uri_string:parse(Proxy) of
        Parsed ->
            Host = binary_to_list(maps:get(host, Parsed)),
            Port = maps:get(port, Parsed, 80),
            [
                {proxy, {{Host, Port}, []}},
                {https_proxy, {{Host, Port}, []}}
            ]
    catch
        _:_ -> []
    end.

api_key() ->
    case os:getenv("PRAXO_API_KEY") of
        false -> <<>>;
        Value -> list_to_binary(Value)
    end.

deterministic_model(Service, Intent) ->
    fun F(Request) ->
        Messages = maps:get(messages, Request),
        ToolMessages = [
            Message
         || Message <- Messages,
            maps:get(role, Message, undefined) =:= <<"tool">>
        ],
        Reply = fun(Content, Calls) ->
            {ok, praxo_models:response(
                praxo_models:message_assistant(Content, Calls)), F}
        end,
        case ToolMessages of
            [] ->
                case direct_execution(Intent) of
                    true ->
                        Reply(<<>>, [execute_call(Service, Intent)]);
                    false ->
                        Reply(<<>>, [search_call(Service)])
                end;
            [First | _] ->
                case praxo_json:parse(maps:get(content, First)) of
                    {ok, #{<<"error">> := Code}} when is_binary(Code) ->
                        Reply(Code, []);
                    {ok, FirstValue} when length(ToolMessages) =:= 1 ->
                        _ = FirstValue,
                        Reply(<<>>, [draft_call(Service)]);
                    {ok, FirstValue} ->
                        {ok, LastValue} = praxo_json:parse(
                            maps:get(content, lists:last(ToolMessages))
                        ),
                        Report = #{
                            <<"service">> => Service,
                            <<"signals">> => FirstValue,
                            <<"remediation">> => LastValue,
                            <<"executions">> => 0
                        },
                        Reply(praxo_json:encode(Report), []);
                    _ ->
                        Reply(<<"INVALID_SIGNALS">>, [])
                end
        end
    end.

search_call(Service) ->
    praxo_models:tool_call(
        <<"signals-1">>,
        <<"search_signals">>,
        #{<<"service">> => Service}
    ).

draft_call(Service) ->
    praxo_models:tool_call(
        <<"remediation-1">>,
        <<"draft_remediation">>,
        #{
            <<"service">> => Service,
            <<"action">> => <<"review_remediation">>,
            <<"diagnosis">> => <<"checkout-api shows elevated error rate and latency">>,
            <<"rationale">> =>
                <<"error_rate 0.18 and latency_ms 940 exceed the review threshold">>
        }
    ).

execute_call(Service, Intent) ->
    praxo_models:tool_call(
        <<"execute-1">>,
        <<"execute_remediation">>,
        #{<<"service">> => Service, <<"intent">> => Intent}
    ).

direct_execution(Intent) ->
    Lower = string:lowercase(binary_to_list(Intent)),
    string:find(Lower, "execute remediation") =/= nomatch orelse
        string:find(Lower, "remediate now") =/= nomatch.

tools() ->
    [
        tool(
            <<"search_signals">>,
            <<"Search fixed telemetry through the supervised store; read-only.">>,
            service_parameters(),
            fun(Arguments) ->
                put(reads, get(reads) + 1),
                case praxo_ops_telemetry:search(maps:get(<<"service">>, Arguments)) of
                    {ok, Signal} -> Signal;
                    {error, Code} -> #{<<"error">> => Code}
                end
            end
        ),
        tool(
            <<"draft_remediation">>,
            <<"Draft a model-written review-only remediation; never executes.">>,
            draft_parameters(),
            fun(Arguments) ->
                put(drafts, get(drafts) + 1),
                #{
                    <<"remediation_id">> => <<"remediation-100">>,
                    <<"service">> => maps:get(<<"service">>, Arguments),
                    <<"action">> => maps:get(<<"action">>, Arguments),
                    <<"diagnosis">> => maps:get(<<"diagnosis">>, Arguments),
                    <<"rationale">> => maps:get(<<"rationale">>, Arguments),
                    <<"status">> => <<"draft_only">>,
                    <<"review_required">> => true,
                    <<"executions">> => 0
                }
            end
        ),
        tool(
            <<"execute_remediation">>,
            <<"Would execute remediation. Always denied in the agent path.">>,
            execute_parameters(),
            fun(Arguments) ->
                put(executions, get(executions) + 1),
                praxo_ops_executor:execute(maps:get(<<"service">>, Arguments))
            end
        )
    ].

tool(Name, Description, Parameters, Invoke) ->
    (praxo_agent:new_tool(Name, Description, Invoke))#{parameters => Parameters}.

tool_specs() ->
    [
        #{
            name => <<"search_signals">>,
            description => <<"Search fixed telemetry through the supervised store; read-only.">>,
            parameters => service_parameters()
        },
        #{
            name => <<"draft_remediation">>,
            description => <<"Draft a model-written review-only remediation; never executes.">>,
            parameters => draft_parameters()
        },
        #{
            name => <<"execute_remediation">>,
            description => <<"Would execute remediation. Always denied in the agent path.">>,
            parameters => execute_parameters()
        }
    ].

service_parameters() ->
    #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"service">>],
        <<"properties">> => #{
            <<"service">> => #{<<"type">> => <<"string">>}
        }
    }.

draft_parameters() ->
    #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"service">>, <<"action">>, <<"diagnosis">>, <<"rationale">>],
        <<"properties">> => #{
            <<"service">> => #{<<"type">> => <<"string">>},
            <<"action">> => #{
                <<"type">> => <<"string">>,
                <<"enum">> => [<<"review_remediation">>]
            },
            <<"diagnosis">> => #{<<"type">> => <<"string">>},
            <<"rationale">> => #{<<"type">> => <<"string">>}
        }
    }.

execute_parameters() ->
    #{
        <<"type">> => <<"object">>,
        <<"required">> => [<<"service">>, <<"intent">>],
        <<"properties">> => #{
            <<"service">> => #{<<"type">> => <<"string">>},
            <<"intent">> => #{<<"type">> => <<"string">>}
        }
    }.

policy(Tenant) ->
    fun(Action) ->
        Kind = maps:get(kind, Action),
        Arguments = maps:get(arguments, Action, #{}),
        case Tenant of
            <<"acme">> ->
                case Kind of
                    <<"model.generate">> ->
                        #{allowed => true};
                    <<"tool.invoke">> ->
                        policy_tool(Action, Arguments);
                    _ ->
                        #{allowed => false}
                end;
            _ ->
                #{allowed => false}
        end
    end.

policy_tool(Action, Arguments) ->
    Tool = maps:get(tool_name, Action),
    Service = maps:get(<<"service">>, Arguments, undefined),
    case Tool of
        <<"execute_remediation">> ->
            #{allowed => false};
        _ when Service =/= <<"service-100">> ->
            #{allowed => false};
        <<"search_signals">> ->
            #{allowed => true};
        <<"draft_remediation">> ->
            ActionName = maps:get(<<"action">>, Arguments, undefined),
            Diagnosis = maps:get(<<"diagnosis">>, Arguments, undefined),
            Rationale = maps:get(<<"rationale">>, Arguments, undefined),
            case ActionName =:= <<"review_remediation">> andalso
                is_binary(Diagnosis) andalso Diagnosis =/= <<>> andalso
                is_binary(Rationale) andalso Rationale =/= <<>> of
                true -> #{allowed => true};
                false -> #{allowed => false}
            end;
        _ ->
            #{allowed => false}
    end.

system_prompt(Tenant) ->
    iolist_to_binary([
        <<"You are an OTP operations copilot for tenant ">>,
        Tenant,
        <<". The only authorized service id is service-100. ">>,
        <<"Use that exact id in tool arguments; display names such as 'checkout' are not service ids. ">>,
        <<"Search telemetry, diagnose, and draft a review-only remediation. ">>,
        <<"Never execute remediation; return JSON with service, signals, remediation, and executions.">>
    ]).

session_id(Tenant, Service, Intent) ->
    iolist_to_binary([
        <<"erlang-ai-ops-">>,
        Tenant,
        <<"-">>,
        Service,
        <<"-">>,
        integer_to_binary(erlang:phash2(Intent))
    ]).

record_trace(TraceTab, Request, Result) ->
    Messages = maps:get(messages, Request, []),
    ToolCalls = lists:flatmap(
        fun(Message) ->
            [
                #{
                    <<"name">> => maps:get(name, Call, <<>>),
                    <<"arguments">> => maps:get(arguments, Call, #{})
                }
             || Call <- maps:get(tool_calls, Message, [])
            ]
        end,
        Messages
    ),
    ToolResults = [
        #{
            <<"tool_id">> => maps:get(tool_id, Message, undefined),
            <<"content">> => maps:get(content, Message, <<>>)
        }
     || Message <- Messages,
        maps:get(role, Message, undefined) =:= <<"tool">>
    ],
    Step = #{
        <<"tool_calls">> => ToolCalls,
        <<"tool_results">> => ToolResults,
        <<"model_output">> => model_output(Result)
    },
    ets:insert(TraceTab, {erlang:unique_integer([monotonic, positive]), Step}).

model_output({ok, Response, _}) ->
    Message = maps:get(message, Response),
    Calls = [
        #{
            <<"name">> => maps:get(name, Call, <<>>),
            <<"arguments">> => maps:get(arguments, Call, #{})
        }
     || Call <- maps:get(tool_calls, Message, [])
    ],
    #{
        <<"content">> => truncate(maps:get(content, Message, <<>>), 800),
        <<"tool_calls">> => Calls
    };
model_output({error, Code, _}) ->
    #{<<"error">> => Code};
model_output(_) ->
    #{}.

truncate(undefined, _Max) ->
    <<>>;
truncate(Text, Max) when is_binary(Text), byte_size(Text) > Max ->
    <<(binary:part(Text, 0, Max))/binary, "...">>;
truncate(Text, _Max) ->
    Text.

parse_report(Output) ->
    case praxo_json:parse(Output) of
        {ok, Map} when is_map(Map) ->
            {ok, Map};
        _ ->
            case re:run(Output, <<"\\{.*\\}">>, [dotall, {capture, first, binary}]) of
                {match, [Json]} ->
                    case praxo_json:parse(Json) of
                        {ok, Map} when is_map(Map) -> {ok, Map};
                        _ -> error
                    end;
                _ ->
                    error
            end
    end.

normalize_report(Report, Service, Trace) ->
    Payloads = lists:append([
        [
            Payload
         || Result <- maps:get(<<"tool_results">>, Step, []),
            {ok, Payload} <- [parse_payload(maps:get(<<"content">>, Result, <<>>))]
        ]
     || Step <- Trace
    ]),
    Remediation = find_payload(Payloads, <<"remediation_id">>),
    Signals = find_payload(Payloads, <<"suspect">>),
    Taxonomy = find_payload(Payloads, <<"tags">>),
    Review = find_payload(Payloads, <<"review_id">>),
    Report1 = Report#{<<"service">> => Service, <<"executions">> => 0},
    Report2 = maybe_put(Report1, <<"remediation">>, Remediation),
    Report3 = maybe_put(Report2, <<"signals">>, Signals),
    Report4 = maybe_put(Report3, <<"taxonomy">>, Taxonomy),
    maybe_put(Report4, <<"review">>, Review).

parse_payload(Content) ->
    case praxo_json:parse(Content) of
        {ok, Map} when is_map(Map) -> {ok, Map};
        _ -> error
    end.

find_payload([], _Key) ->
    undefined;
find_payload([Payload | Rest], Key) ->
    case maps:is_key(Key, Payload) of
        true -> Payload;
        false -> find_payload(Rest, Key)
    end.

maybe_put(Map, _Key, undefined) -> Map;
maybe_put(Map, Key, Value) -> Map#{Key => Value}.

stats() ->
    #{
        reads => get(reads),
        drafts => get(drafts),
        executions => get(executions)
    }.
