defmodule Praxo.McpHttp do
  alias Praxo.{Error, Json}

  @default_protocol "2025-03-26"

  def transport(endpoint, options \\ []) do
    protocol = Keyword.get(options, :protocol_version, @default_protocol)
    headers = Keyword.get(options, :headers, [])
    timeout = Keyword.get(options, :timeout, 30_000)
    validate!(endpoint)
    table = :ets.new(:praxo_mcp_http, [:set, :public])
    :ets.insert(table, {:state, "", protocol})

    %{
      request: fn method, params, request_timeout ->
        request(endpoint, table, headers, request_timeout || timeout, method, params)
      end,
      notify: fn method, params ->
        notify(endpoint, table, headers, timeout, method, params)
      end,
      close: fn ->
        close(endpoint, table, headers, timeout)
      end
    }
  end

  defp request(endpoint, table, headers, timeout, method, params) do
    id = System.unique_integer([:positive, :monotonic])

    message = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => method,
      "params" => params || %{}
    }

    case post(endpoint, table, headers, timeout, message) do
      {:ok, status, response_headers, body} ->
        update_session(table, response_headers)
        handle_response(id, status, response_headers, body, table)

      {:error, _} ->
        {:error, error("MCP_TRANSPORT", "mcp: HTTP transport failed")}
    end
  end

  defp notify(endpoint, table, headers, timeout, method, params) do
    message = %{"jsonrpc" => "2.0", "method" => method, "params" => params || %{}}

    case post(endpoint, table, headers, timeout, message) do
      {:ok, _status, response_headers, _body} ->
        update_session(table, response_headers)
        :ok

      _ ->
        :ok
    end
  end

  defp close(endpoint, table, headers, timeout) do
    session = session(table)

    if session != "" do
      protocol = protocol(table)

      request_headers = [
        {~c"mcp-protocol-version", String.to_charlist(protocol)},
        {~c"mcp-session-id", String.to_charlist(session)}
        | header_pairs(headers)
      ]

      :httpc.request(
        :delete,
        {String.to_charlist(endpoint), request_headers, ~c"application/json", ~c""},
        [timeout: timeout, connect_timeout: timeout],
        []
      )
    end

    :ets.delete(table)
    :ok
  end

  defp handle_response(id, status, response_headers, body, table) do
    cond do
      status in [202, 204] ->
        {:ok, %{}}

      status >= 200 and status < 300 ->
        case response_messages(response_headers, body) do
          {:ok, messages} ->
            case select_message(messages, id) do
              {:ok, message} ->
                result = Map.get(message, "result", %{})
                update_protocol(table, result)

                case Map.get(message, "error") do
                  nil -> {:ok, result}
                  _ -> {:error, error("MCP_RPC", "mcp: JSON-RPC error")}
                end

              :error ->
                {:error, error("MCP_PROTOCOL", "mcp: response contained no message")}
            end

          {:error, code} ->
            {:error, error(code, "mcp: invalid response")}
        end

      true ->
        {:error, error("MCP_TRANSPORT", "mcp: HTTP #{status}")}
    end
  end

  defp post(endpoint, table, headers, timeout, message) do
    :inets.start()
    session = session(table)
    protocol = protocol(table)

    request_headers =
      [
        {~c"content-type", ~c"application/json"},
        {~c"accept", ~c"application/json, text/event-stream"},
        {~c"mcp-protocol-version", String.to_charlist(protocol)}
        | session_header(session) ++ header_pairs(headers)
      ]

    body = Json.encode(message)

    case :httpc.request(
           :post,
           {String.to_charlist(endpoint), request_headers, ~c"application/json",
            String.to_charlist(body)},
           [timeout: timeout, connect_timeout: timeout],
           []
         ) do
      {:ok, {{_, status, _}, response_headers, response_body}} ->
        {:ok, status, response_headers, IO.iodata_to_binary(response_body)}

      _ ->
        {:error, :transport}
    end
  end

  defp response_messages(headers, body) do
    content_type = header_value(headers, "content-type")

    if String.contains?(String.downcase(content_type), "text/event-stream") do
      parse_sse(body)
    else
      case Json.parse(body) do
        {:ok, value} when is_map(value) -> {:ok, [value]}
        _ -> {:error, "MCP_PROTOCOL"}
      end
    end
  end

  defp parse_sse(body) do
    messages =
      body
      |> String.replace("\r\n", "\n")
      |> String.split("\n\n")
      |> Enum.flat_map(&sse_event/1)

    if messages == [] do
      {:error, "MCP_PROTOCOL"}
    else
      {:ok, messages}
    end
  end

  defp sse_event(event) do
    data =
      event
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "data:"))
      |> Enum.map(fn line ->
        line |> String.replace_prefix("data:", "") |> String.trim_leading()
      end)

    case data do
      [] ->
        []

      _ ->
        case Json.parse(Enum.join(data, "\n")) do
          {:ok, value} when is_map(value) -> [value]
          _ -> []
        end
    end
  end

  defp select_message([], _id), do: :error

  defp select_message([message | rest], id) do
    if Map.get(message, "id") == id do
      {:ok, message}
    else
      select_message(rest, id)
    end
  end

  defp update_session(_table, []), do: :ok

  defp update_session(table, headers) do
    case header_value(headers, "mcp-session-id") do
      "" -> :ok
      session -> :ets.insert(table, {:state, session, protocol(table)})
    end
  end

  defp update_protocol(table, result) do
    case Map.get(result, "protocolVersion") do
      nil -> :ok
      "" -> :ok
      protocol -> :ets.insert(table, {:state, session(table), protocol})
    end
  end

  defp session(table) do
    case :ets.lookup(table, :state) do
      [{:state, session, _protocol}] -> session
      _ -> ""
    end
  end

  defp protocol(table) do
    case :ets.lookup(table, :state) do
      [{:state, _session, protocol}] -> protocol
      _ -> @default_protocol
    end
  end

  defp session_header(""), do: []
  defp session_header(session), do: [{~c"mcp-session-id", String.to_charlist(session)}]

  defp header_pairs(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.to_charlist(to_string(key)), String.to_charlist(to_string(value))}
    end)
  end

  defp header_value([], _name), do: ""

  defp header_value([{key, value} | rest], name) do
    if String.downcase(to_string(key)) == name do
      to_string(value)
    else
      header_value(rest, name)
    end
  end

  defp validate!(endpoint) do
    uri = URI.parse(endpoint)

    case uri.scheme do
      "https" ->
        :ok

      "http" ->
        if loopback?(uri.host) do
          :ok
        else
          raise Error, code: "MCP_TRANSPORT", message: "mcp: HTTP endpoint must use HTTPS"
        end

      _ ->
        raise Error, code: "MCP_TRANSPORT", message: "mcp: invalid HTTP endpoint"
    end
  end

  defp loopback?(host) do
    value = String.downcase(host || "")

    value == "localhost" or value == "127.0.0.1" or value == "::1" or
      String.starts_with?(value, "127.")
  end

  defp error(code, message), do: %Error{code: code, message: message}
end
