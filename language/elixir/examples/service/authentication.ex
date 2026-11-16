defmodule ServiceAuth do
  defmodule Principal do
    defstruct [:subject, :tenant, :expires]
  end

  defmodule AuthError do
    defexception [:message]
  end

  defmodule HttpTransport do
    def post_form(url, form, authorization) do
      {:ok, _} = Application.ensure_all_started(:inets)
      {:ok, _} = Application.ensure_all_started(:ssl)

      headers = [{~c"content-type", ~c"application/x-www-form-urlencoded"}]

      headers =
        case authorization do
          nil -> headers
          value -> [{~c"authorization", String.to_charlist(value)} | headers]
        end

      request =
        {String.to_charlist(url), headers, ~c"application/x-www-form-urlencoded",
         URI.encode_query(form)}

      http_options = [
        timeout: 2_000,
        connect_timeout: 2_000,
        body_format: :binary,
        ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()]
      ]

      case :httpc.request(:post, request, http_options, []) do
        {:ok, {{_, status, _}, _headers, body}} -> {:ok, status, to_string(body)}
        {:error, _reason} -> {:error, :unavailable}
      end
    rescue
      _ -> {:error, :unavailable}
    catch
      _, _ -> {:error, :unavailable}
    end
  end

  defmodule ContextAuthenticator do
    alias ServiceAuth.Principal

    def new(tenant), do: %{tenant: tenant}

    def authenticate(auth, principal, authorization \\ nil, now \\ nil)

    def authenticate(%{tenant: tenant}, principal, _authorization, _now)
        when is_binary(principal) and principal != "" do
      %Principal{subject: principal, tenant: tenant, expires: nil}
    end

    def authenticate(_auth, _principal, _authorization, _now), do: nil
  end

  defmodule IntrospectionAuthenticator do
    alias ServiceAuth.{Principal}

    defstruct [:transport, :endpoint, :client_id, :client_secret, :tenant_claim]

    def new(transport, endpoint, opts \\ []) when is_function(transport, 3) do
      tenant_claim = Keyword.get(opts, :tenant_claim, "tenant")
      tenant_claim = if tenant_claim == "", do: "tenant", else: tenant_claim

      %__MODULE__{
        transport: transport,
        endpoint: endpoint,
        client_id: Keyword.get(opts, :client_id, ""),
        client_secret: Keyword.get(opts, :client_secret, ""),
        tenant_claim: tenant_claim
      }
    end

    def authenticate(%__MODULE__{} = auth, authorization, now \\ System.system_time(:second)) do
      with "Bearer " <> raw <- authorization || "",
           token when token != "" <- String.trim(raw),
           {:ok, 200, body} <-
             auth.transport.(auth.endpoint, form(auth, token), basic_auth(auth)),
           {:ok, payload} <- decode(body),
           true <- payload["active"] == true,
           subject when is_binary(subject) and subject != "" <- payload["sub"],
           tenant when is_binary(tenant) and tenant != "" <- payload[auth.tenant_claim],
           expires when is_integer(expires) and expires > now <- payload["exp"] do
        %Principal{subject: subject, tenant: tenant, expires: expires}
      else
        _ -> nil
      end
    rescue
      _ -> nil
    catch
      _, _ -> nil
    end

    defp form(auth, token) do
      %{
        "token" => token,
        "client_id" => auth.client_id,
        "client_secret" => auth.client_secret
      }
    end

    defp decode(body) when is_binary(body) do
      {:ok, :json.decode(body)}
    rescue
      _ -> :error
    catch
      _, _ -> :error
    end

    defp decode(_body), do: :error

    defp basic_auth(%{client_id: ""}), do: nil

    defp basic_auth(%{client_id: id, client_secret: secret}) do
      "Basic " <> Base.encode64("#{id}:#{secret}")
    end
  end

  defmodule RevocationClient do
    alias ServiceAuth.AuthError

    defstruct [:transport, :endpoint, :client_id, :client_secret]

    def new(transport, endpoint, opts \\ []) when is_function(transport, 3) do
      %__MODULE__{
        transport: transport,
        endpoint: endpoint,
        client_id: Keyword.get(opts, :client_id, ""),
        client_secret: Keyword.get(opts, :client_secret, "")
      }
    end

    def revoke(%__MODULE__{} = client, token) do
      if token in [nil, ""] do
        raise AuthError, message: "revocation token is required"
      end

      result =
        try do
          client.transport.(client.endpoint, form(client, token), basic_auth(client))
        rescue
          _ -> :error
        catch
          _, _ -> :error
        end

      case result do
        {:ok, 200, _body} -> :ok
        _ -> raise AuthError, message: "token revocation failed"
      end
    end

    defp form(client, token) do
      %{
        "token" => token,
        "token_type_hint" => "access_token",
        "client_id" => client.client_id,
        "client_secret" => client.client_secret
      }
    end

    defp basic_auth(%{client_id: ""}), do: nil

    defp basic_auth(%{client_id: id, client_secret: secret}) do
      "Basic " <> Base.encode64("#{id}:#{secret}")
    end
  end
end
