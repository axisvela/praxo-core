-module(authentication).

-export([
    context_new/1,
    context_authenticate/2,
    introspection_new/3,
    introspection_authenticate/3,
    revocation_new/3,
    revoke/2
]).

context_new(Tenant) ->
    #{tenant => Tenant}.

context_authenticate(#{tenant := Tenant}, Principal)
    when is_binary(Principal), Principal =/= <<>> ->
    #{subject => Principal, tenant => Tenant, expires => undefined};
context_authenticate(_Client, _Principal) ->
    undefined.

introspection_new(Transport, Endpoint, Options) ->
    TenantClaim = default(proplists:get_value(tenant_claim, Options, <<"tenant">>), <<"tenant">>),
    #{
        transport => Transport,
        endpoint => Endpoint,
        client_id => proplists:get_value(client_id, Options, <<>>),
        client_secret => proplists:get_value(client_secret, Options, <<>>),
        tenant_claim => TenantClaim
    }.

introspection_authenticate(Client, Authorization, Now) ->
    case bearer_token(Authorization) of
        {ok, Token} ->
            Form = #{
                <<"token">> => Token,
                <<"client_id">> => maps:get(client_id, Client),
                <<"client_secret">> => maps:get(client_secret, Client)
            },
            AuthorizationHeader = basic_auth(Client),
            Transport = maps:get(transport, Client),
            try Transport(maps:get(endpoint, Client), Form, AuthorizationHeader) of
                {ok, 200, Body} ->
                    principal_from_body(Body, maps:get(tenant_claim, Client), Now);
                _ ->
                    undefined
            catch
                _:_ -> undefined
            end;
        error ->
            undefined
    end.

revocation_new(Transport, Endpoint, Options) ->
    #{
        transport => Transport,
        endpoint => Endpoint,
        client_id => proplists:get_value(client_id, Options, <<>>),
        client_secret => proplists:get_value(client_secret, Options, <<>>)
    }.

revoke(_Client, Token) when Token =:= <<>>; Token =:= undefined ->
    erlang:error({auth_error, <<"revocation token is required">>});
revoke(Client, Token) ->
    Form = #{
        <<"token">> => Token,
        <<"token_type_hint">> => <<"access_token">>,
        <<"client_id">> => maps:get(client_id, Client),
        <<"client_secret">> => maps:get(client_secret, Client)
    },
    Transport = maps:get(transport, Client),
    Result =
        try Transport(maps:get(endpoint, Client), Form, basic_auth(Client)) catch
            _:_ -> {error, unavailable}
        end,
    case Result of
        {ok, 200, _Body} -> ok;
        _ -> erlang:error({auth_error, <<"token revocation failed">>})
    end.

bearer_token(<<"Bearer ", Rest/binary>>) ->
    case string:trim(Rest) of
        <<>> -> error;
        Token -> {ok, Token}
    end;
bearer_token(_Authorization) ->
    error.

principal_from_body(Body, TenantClaim, Now) ->
    try json:decode(Body) of
        #{<<"active">> := true, <<"sub">> := Subject, <<"exp">> := Expires} = Payload
            when is_binary(Subject), Subject =/= <<>>, is_integer(Expires), Expires > Now ->
            case maps:get(TenantClaim, Payload, undefined) of
                Tenant when is_binary(Tenant), Tenant =/= <<>> ->
                    #{subject => Subject, tenant => Tenant, expires => Expires};
                _ ->
                    undefined
            end;
        _ ->
            undefined
    catch
        _:_ -> undefined
    end.

basic_auth(#{client_id := <<>>}) ->
    undefined;
basic_auth(#{client_id := ClientId, client_secret := ClientSecret}) ->
    Credentials = iolist_to_binary([ClientId, <<":">>, ClientSecret]),
    iolist_to_binary([<<"Basic ">>, base64:encode(Credentials)]).

default(undefined, Fallback) -> Fallback;
default(<<>>, Fallback) -> Fallback;
default(Value, _Fallback) -> Value.
