-module(authentication_test).

-export([main/0]).

main() ->
    Now = 1700000000,
    context_test(),
    introspection_success(Now),
    introspection_rejections(Now),
    custom_tenant_claim(Now),
    revocation_test(),
    io:format("Erlang service auth tests passed~n").

context_test() ->
    Auth = authentication:context_new(<<"tenant-a">>),
    #{subject := <<"user-1">>, tenant := <<"tenant-a">>, expires := undefined} =
        authentication:context_authenticate(Auth, <<"user-1">>),
    undefined = authentication:context_authenticate(Auth, undefined),
    undefined = authentication:context_authenticate(Auth, <<>>),
    ok.

introspection_success(Now) ->
    Body = body(<<"true">>, <<"user-1">>, <<"tenant-a">>, Now + 60),
    ExpectedAuthorization =
        iolist_to_binary([<<"Basic ">>, base64:encode(<<"svc:secret">>)]),
    Transport = fun(Url, Form, Authorization) ->
        <<"https://idp.example/introspect">> = Url,
        #{
            <<"token">> := <<"token-1">>,
            <<"client_id">> := <<"svc">>,
            <<"client_secret">> := <<"secret">>
        } = Form,
        ExpectedAuthorization = Authorization,
        {ok, 200, Body}
    end,
    Client = authentication:introspection_new(
        Transport,
        <<"https://idp.example/introspect">>,
        [{client_id, <<"svc">>}, {client_secret, <<"secret">>}]
    ),
    #{subject := <<"user-1">>, tenant := <<"tenant-a">>, expires := Expires} =
        authentication:introspection_authenticate(Client, <<"Bearer token-1">>, Now),
    assert_equal(Now + 60, Expires, introspection_expires),
    ok.

introspection_rejections(Now) ->
    LocalClient = authentication:introspection_new(
        fun(_, _, _) -> erlang:error(should_not_call) end,
        <<"https://idp.example/introspect">>,
        []
    ),
    undefined = authentication:introspection_authenticate(LocalClient, undefined, Now),
    undefined = authentication:introspection_authenticate(LocalClient, <<"Basic token">>, Now),
    undefined = authentication:introspection_authenticate(LocalClient, <<"Bearer   ">>, Now),

    Rejected =
        [
            body(<<"false">>, <<"user-1">>, <<"tenant-a">>, Now + 60),
            body(<<"true">>, <<>>, <<"tenant-a">>, Now + 60),
            body(<<"true">>, <<"user-1">>, <<>>, Now + 60),
            body(<<"true">>, <<"user-1">>, <<"tenant-a">>, Now),
            <<"{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\"}">>,
            <<"not-json">>
        ],
    lists:foreach(
        fun(ResponseBody) ->
            Client = authentication:introspection_new(
                fun(_, _, _) -> {ok, 200, ResponseBody} end,
                <<"https://idp.example/introspect">>,
                []
            ),
            undefined = authentication:introspection_authenticate(
                Client, <<"Bearer token-1">>, Now
            )
        end,
        Rejected
    ),

    StatusClient = authentication:introspection_new(
        fun(_, _, _) -> {ok, 500, body(<<"true">>, <<"user-1">>, <<"tenant-a">>, Now + 60)} end,
        <<"https://idp.example/introspect">>,
        []
    ),
    undefined = authentication:introspection_authenticate(StatusClient, <<"Bearer token-1">>, Now),

    ErrorClient = authentication:introspection_new(
        fun(_, _, _) -> {error, unavailable} end,
        <<"https://idp.example/introspect">>,
        []
    ),
    undefined = authentication:introspection_authenticate(ErrorClient, <<"Bearer token-1">>, Now),

    ThrowClient = authentication:introspection_new(
        fun(_, _, _) -> erlang:error(boom) end,
        <<"https://idp.example/introspect">>,
        []
    ),
    undefined = authentication:introspection_authenticate(ThrowClient, <<"Bearer token-1">>, Now),
    ok.

custom_tenant_claim(Now) ->
    Body = <<"{\"active\":true,\"sub\":\"user-1\",\"org\":\"org-a\",\"exp\":1700000060}">>,
    Client = authentication:introspection_new(
        fun(_, _, _) -> {ok, 200, Body} end,
        <<"https://idp.example/introspect">>,
        [{tenant_claim, <<"org">>}]
    ),
    #{tenant := <<"org-a">>} =
        authentication:introspection_authenticate(Client, <<"Bearer token-1">>, Now),
    ok.

revocation_test() ->
    ExpectedAuthorization =
        iolist_to_binary([<<"Basic ">>, base64:encode(<<"svc:secret">>)]),
    Transport = fun(Url, Form, Authorization) ->
        <<"https://idp.example/revoke">> = Url,
        #{
            <<"token">> := <<"token-1">>,
            <<"token_type_hint">> := <<"access_token">>,
            <<"client_id">> := <<"svc">>,
            <<"client_secret">> := <<"secret">>
        } = Form,
        ExpectedAuthorization = Authorization,
        {ok, 200, <<>>}
    end,
    Client = authentication:revocation_new(
        Transport,
        <<"https://idp.example/revoke">>,
        [{client_id, <<"svc">>}, {client_secret, <<"secret">>}]
    ),
    ok = authentication:revoke(Client, <<"token-1">>),

    StatusClient = authentication:revocation_new(
        fun(_, _, _) -> {ok, 400, <<>>} end,
        <<"https://idp.example/revoke">>,
        []
    ),
    expect_auth_error(
        <<"token revocation failed">>,
        fun() -> authentication:revoke(StatusClient, <<"token-1">>) end
    ),

    ErrorClient = authentication:revocation_new(
        fun(_, _, _) -> {error, unavailable} end,
        <<"https://idp.example/revoke">>,
        []
    ),
    expect_auth_error(
        <<"token revocation failed">>,
        fun() -> authentication:revoke(ErrorClient, <<"token-1">>) end
    ),

    ThrowClient = authentication:revocation_new(
        fun(_, _, _) -> erlang:error(boom) end,
        <<"https://idp.example/revoke">>,
        []
    ),
    expect_auth_error(
        <<"token revocation failed">>,
        fun() -> authentication:revoke(ThrowClient, <<"token-1">>) end
    ),

    LocalClient = authentication:revocation_new(
        fun(_, _, _) -> erlang:error(should_not_call) end,
        <<"https://idp.example/revoke">>,
        []
    ),
    expect_auth_error(
        <<"revocation token is required">>,
        fun() -> authentication:revoke(LocalClient, <<>>) end
    ),
    ok.

body(Active, Subject, Tenant, Expires) ->
    list_to_binary(
        io_lib:format(
            "{\"active\":~s,\"sub\":\"~s\",\"tenant\":\"~s\",\"exp\":~p}",
            [Active, Subject, Tenant, Expires]
        )
    ).

expect_auth_error(Expected, Fun) ->
    try Fun() of
        Value -> erlang:error({expected_auth_error, Expected, Value})
    catch
        error:{auth_error, Expected} -> ok;
        error:Other -> erlang:error({unexpected_error, Other})
    end.

assert_equal(Expected, Expected, _Label) ->
    ok;
assert_equal(Expected, Actual, Label) ->
    erlang:error({assertion_failed, Label, Expected, Actual}).
