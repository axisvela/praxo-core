-module(praxo_middleware).
-export([
    pii_redact/1,
    redact_value/1,
    extract_json/1,
    structured_output/2,
    structured_output/3,
    apply_structured/2,
    call_limit/2,
    model_call/1,
    tool_call/1,
    tool_selection/1,
    select_tools/2,
    check_tool_selected/2
]).

pii_redact(Text) ->
    Text1 = replace(Text, <<"[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}">>, <<"[REDACTED:email]">>),
    Text2 = replace(Text1, <<"\\b\\d{3}-\\d{2}-\\d{4}\\b">>, <<"[REDACTED:ssn]">>),
    Text3 = replace(Text2, <<"\\b(?:\\d{4}[ -]?){3}\\d{4}\\b">>, <<"[REDACTED:credit_card]">>),
    replace(Text3, <<"\\b(?:\\+?1[-. ]?)?\\(?\\d{3}\\)?[-. ]?\\d{3}[-. ]?\\d{4}\\b">>, <<"[REDACTED:phone]">>).

replace(Text, Pattern, Replacement) ->
    re:replace(Text, Pattern, Replacement, [unicode, global, {return, binary}]).

redact_value(Value) when is_binary(Value) -> pii_redact(Value);
redact_value(Value) when is_list(Value) -> [redact_value(Item) || Item <- Value];
redact_value(Value) when is_map(Value) ->
    maps:from_list([{Key, redact_value(Item)} || {Key, Item} <- maps:to_list(Value)]);
redact_value(Value) -> Value.

extract_json(Text0) ->
    Value0 = string:trim(Text0),
    Value =
        case Value0 of
            <<"```", _/binary>> ->
                Stripped = re:replace(
                    Value0,
                    <<"^```[^\\n]*\\n">>,
                    <<>>,
                    [unicode, {return, binary}]
                ),
                string:trim(
                    re:replace(
                        Stripped,
                        <<"```\\s*$">>,
                        <<>>,
                        [unicode, {return, binary}]
                    )
                );
            _ ->
                Value0
        end,
    case re:run(Value, <<"[\\{\\[]">>, [{capture, first, index}]) of
        {match, [{Start, _}]} ->
            Rest = binary:part(Value, Start, byte_size(Value) - Start),
            praxo_json:parse(Rest);
        nomatch ->
            {error, no_json}
    end.

structured_output(Schema, MaxRepairs) ->
    structured_output(Schema, MaxRepairs, undefined).

structured_output(Schema, MaxRepairs, Repairer) ->
    #{schema => Schema, max_repairs => MaxRepairs, repairer => Repairer}.

apply_structured(Config, Text) ->
    do_apply(Config, Text, 0).

do_apply(Config, Output, Attempt) ->
    Valid =
        case extract_json(Output) of
            {ok, Value} -> praxo_jsonschema:validate(maps:get(schema, Config), Value) == [];
            _ -> false
        end,
    case Valid of
        true ->
            {ok, Output};
        false ->
            MaxRepairs = maps:get(max_repairs, Config),
            Repairer = maps:get(repairer, Config),
            case Attempt >= MaxRepairs of
                true ->
                    {error, <<"AGENT_STRUCTURED_OUTPUT">>};
                false ->
                    case Repairer of
                        undefined ->
                            {error, <<"AGENT_STRUCTURED_OUTPUT">>};
                        _ ->
                            try Repairer(Output) of
                                {ok, Repaired} when is_binary(Repaired) ->
                                    case string:trim(Repaired) of
                                        <<>> -> {error, <<"AGENT_STRUCTURED_OUTPUT">>};
                                        _ -> do_apply(Config, Repaired, Attempt + 1)
                                    end;
                                {ok, _} ->
                                    {error, <<"AGENT_STRUCTURED_OUTPUT">>};
                                {error, Error} ->
                                    {error, Error}
                            catch
                                Class:Reason:Stack ->
                                    {error, {Class, Reason, Stack}}
                            end
                    end
            end
    end.

call_limit(ModelLimit, ToolLimit) ->
    #{model_limit => ModelLimit, tool_limit => ToolLimit, models => 0, tools => 0}.

model_call(Limit) ->
    Updated = Limit#{models => maps:get(models, Limit) + 1},
    ModelLimit = maps:get(model_limit, Limit),
    case ModelLimit > 0 andalso maps:get(models, Updated) > ModelLimit of
        true -> {error, <<"AGENT_MODEL_CALL_LIMIT">>, Updated};
        false -> {ok, Updated}
    end.

tool_call(Limit) ->
    Updated = Limit#{tools => maps:get(tools, Limit) + 1},
    ToolLimit = maps:get(tool_limit, Limit),
    case ToolLimit > 0 andalso maps:get(tools, Updated) > ToolLimit of
        true -> {error, <<"AGENT_TOOL_CALL_LIMIT">>, Updated};
        false -> {ok, Updated}
    end.

tool_selection(Selected) ->
    #{selected => Selected}.

select_tools(#{selected := Selected}, Tools) ->
    [Tool || Tool <- Tools, lists:member(maps:get(name, Tool), Selected)].

check_tool_selected(#{selected := Selected}, Name) ->
    case lists:member(Name, Selected) of
        true -> ok;
        false -> {error, <<"AGENT_TOOL_NOT_SELECTED">>}
    end.
