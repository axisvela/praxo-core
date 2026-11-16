Code.require_file("authentication.ex", __DIR__)

defmodule ServiceAuthTest do
  alias ServiceAuth.{AuthError, ContextAuthenticator, IntrospectionAuthenticator, RevocationClient}

  @now 1_700_000_000

  def run do
    test_context_authenticator()
    test_introspection_success()
    test_introspection_rejections()
    test_custom_tenant_claim()
    test_revocation()
    IO.puts("Elixir service auth tests passed")
  end

  defp test_context_authenticator do
    auth = ContextAuthenticator.new("tenant-a")
    principal = ContextAuthenticator.authenticate(auth, "user-1")
    equal!(principal.subject, "user-1", "context subject")
    equal!(principal.tenant, "tenant-a", "context tenant")
    equal!(principal.expires, nil, "context expires")
    equal!(ContextAuthenticator.authenticate(auth, nil), nil, "context missing principal")
    equal!(ContextAuthenticator.authenticate(auth, ""), nil, "context empty principal")
  end

  defp test_introspection_success do
    body =
      ~s({"active":true,"sub":"user-1","tenant":"tenant-a","exp":#{@now + 60}})

    {transport, calls} = scripted({:ok, 200, body})

    auth =
      IntrospectionAuthenticator.new(transport, "https://idp.example/introspect",
        client_id: "svc",
        client_secret: "secret"
      )

    principal = IntrospectionAuthenticator.authenticate(auth, "Bearer token-1", @now)
    equal!(principal.subject, "user-1", "introspection subject")
    equal!(principal.tenant, "tenant-a", "introspection tenant")
    equal!(principal.expires, @now + 60, "introspection expires")

    [call] = calls.()
    equal!(call.url, "https://idp.example/introspect", "introspection endpoint")
    equal!(call.form["token"], "token-1", "introspection token")
    equal!(call.form["client_id"], "svc", "introspection client id")
    equal!(call.form["client_secret"], "secret", "introspection client secret")

    equal!(
      call.authorization,
      "Basic " <> Base.encode64("svc:secret"),
      "introspection basic auth"
    )
  end

  defp test_introspection_rejections do
    body =
      ~s({"active":true,"sub":"user-1","tenant":"tenant-a","exp":#{@now + 60}})

    {transport, calls} = scripted({:ok, 200, body})

    auth =
      IntrospectionAuthenticator.new(transport, "https://idp.example/introspect",
        client_id: "svc",
        client_secret: "secret"
      )

    equal!(IntrospectionAuthenticator.authenticate(auth, nil, @now), nil, "missing bearer")
    equal!(IntrospectionAuthenticator.authenticate(auth, "Basic token", @now), nil, "wrong scheme")
    equal!(IntrospectionAuthenticator.authenticate(auth, "Bearer   ", @now), nil, "empty token")
    equal!(calls.(), [], "rejected requests are local")

    rejected =
      [
        ~s({"active":false,"sub":"user-1","tenant":"tenant-a","exp":#{@now + 60}}),
        ~s({"active":true,"sub":"","tenant":"tenant-a","exp":#{@now + 60}}),
        ~s({"active":true,"sub":"user-1","tenant":"","exp":#{@now + 60}}),
        ~s({"active":true,"sub":"user-1","tenant":"tenant-a","exp":#{@now}}),
        ~s({"active":true,"sub":"user-1","tenant":"tenant-a"}),
        "not-json"
      ]

    Enum.each(rejected, fn response_body ->
      {reject_transport, _calls} = scripted({:ok, 200, response_body})
      reject_auth = IntrospectionAuthenticator.new(reject_transport, "https://idp.example")

      equal!(
        IntrospectionAuthenticator.authenticate(reject_auth, "Bearer token-1", @now),
        nil,
        "rejected introspection body"
      )
    end)

    {status_transport, _calls} = scripted({:ok, 500, body})
    status_auth = IntrospectionAuthenticator.new(status_transport, "https://idp.example")

    equal!(
      IntrospectionAuthenticator.authenticate(status_auth, "Bearer token-1", @now),
      nil,
      "non-200 introspection"
    )

    raising = fn _url, _form, _authorization -> raise AuthError, message: "unavailable" end
    raising_auth = IntrospectionAuthenticator.new(raising, "https://idp.example")

    equal!(
      IntrospectionAuthenticator.authenticate(raising_auth, "Bearer token-1", @now),
      nil,
      "transport error"
    )
  end

  defp test_custom_tenant_claim do
    body = ~s({"active":true,"sub":"user-1","org":"org-a","exp":#{@now + 60}})
    {transport, _calls} = scripted({:ok, 200, body})

    auth =
      IntrospectionAuthenticator.new(transport, "https://idp.example",
        tenant_claim: "org"
      )

    principal = IntrospectionAuthenticator.authenticate(auth, "Bearer token-1", @now)
    equal!(principal.tenant, "org-a", "custom tenant claim")
  end

  defp test_revocation do
    {transport, calls} = scripted({:ok, 200, ""})

    client =
      RevocationClient.new(transport, "https://idp.example/revoke",
        client_id: "svc",
        client_secret: "secret"
      )

    equal!(RevocationClient.revoke(client, "token-1"), :ok, "revocation result")
    [call] = calls.()
    equal!(call.form["token"], "token-1", "revocation token")
    equal!(call.form["token_type_hint"], "access_token", "revocation hint")

    equal!(
      call.authorization,
      "Basic " <> Base.encode64("svc:secret"),
      "revocation basic auth"
    )

    {status_transport, _calls} = scripted({:ok, 400, ""})
    status_client = RevocationClient.new(status_transport, "https://idp.example/revoke")

    equal!(
      error_message(fn -> RevocationClient.revoke(status_client, "token-1") end),
      "token revocation failed",
      "revocation non-200"
    )

    raising = fn _url, _form, _authorization -> raise AuthError, message: "unavailable" end
    raising_client = RevocationClient.new(raising, "https://idp.example/revoke")

    equal!(
      error_message(fn -> RevocationClient.revoke(raising_client, "token-1") end),
      "token revocation failed",
      "revocation transport error"
    )

    {empty_transport, empty_calls} = scripted({:ok, 200, ""})
    empty_client = RevocationClient.new(empty_transport, "https://idp.example/revoke")

    equal!(
      error_message(fn -> RevocationClient.revoke(empty_client, "") end),
      "revocation token is required",
      "revocation empty token"
    )

    equal!(empty_calls.(), [], "empty revocation is local")
  end

  defp scripted(response) do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    transport = fn url, form, authorization ->
      Agent.update(agent, &[%{url: url, form: form, authorization: authorization} | &1])
      response
    end

    calls = fn -> Agent.get(agent, &Enum.reverse/1) end
    {transport, calls}
  end

  defp error_message(fun) do
    fun.()
    nil
  rescue
    error in AuthError -> error.message
  end

  defp equal!(actual, expected, label) do
    unless actual == expected do
      raise "#{label}: expected #{inspect(expected)}, got #{inspect(actual)}"
    end
  end
end

ServiceAuthTest.run()
