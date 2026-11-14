#!/usr/bin/env escript
main(_) ->
    Operator = #{tenant => <<"acme">>, role => <<"operator">>, active => true},
    true = maps:get(allowed, authorize(Operator, #{kind => <<"model.generate">>})),
    true = maps:get(allowed, authorize(Operator,
        #{kind => <<"tool.invoke">>, tool => <<"record">>, tenant => <<"acme">>})),
    false = maps:get(allowed, authorize(Operator#{role => <<"viewer">>},
        #{kind => <<"tool.invoke">>, tool => <<"record">>, tenant => <<"acme">>})),
    false = maps:get(allowed, authorize(Operator,
        #{kind => <<"tool.invoke">>, tool => <<"record">>, tenant => <<"other">>})),
    false = maps:get(allowed, authorize(undefined, #{kind => <<"model.generate">>})),
    io:format("Erlang identity policy example passed~n").

authorize(undefined, _Action) ->
    #{allowed => false, reason => <<"missing">>};
authorize(Principal, Action) ->
    case maps:get(active, Principal) of
        false -> #{allowed => false, reason => <<"inactive">>};
        true ->
            case maps:get(kind, Action) of
                <<"model.generate">> -> #{allowed => true, reason => <<"model">>};
                <<"tool.invoke">> ->
                    case maps:get(role, Principal) of
                        <<"operator">> ->
                            Tenant = maps:get(tenant, Principal),
                            case {maps:get(tool, Action), maps:get(tenant, Action)} of
                                {<<"record">>, Tenant} ->
                                    #{allowed => true, reason => <<"operator">>};
                                _ -> #{allowed => false, reason => <<"operation">>}
                            end;
                        _ -> #{allowed => false, reason => <<"role">>}
                    end
            end
    end.
