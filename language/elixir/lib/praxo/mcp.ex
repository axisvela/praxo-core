defmodule Praxo.McpTool do
  defstruct name: "", description: "", title: "", input_schema: %{}, annotations: %{}
end

defmodule Praxo.Mcp do
  alias Praxo.{AgentOptions, Error, Json, McpTool, Tool}

  @default_protocol_version "2024-11-05"

  defstruct port: nil,
            timeout: 30_000,
            protocol_version: "",
            server_info: %{},
            server_capabilities: %{},
            connected: false,
            closed: false

  def default_protocol_version, do: @default_protocol_version

  def connect(options \\ []) do
    with {:ok, port} <- Praxo.Mcp.Transport.open(options) do
      client = %__MODULE__{
        port: port,
        timeout: Keyword.get(options, :timeout, 30_000)
      }

      case handshake(client, options) do
        {:ok, client} ->
          {:ok, client}

        {:error, error} ->
          Praxo.Mcp.Transport.close(port)
          {:error, error}
      end
    end
  end

  def close(%__MODULE__{closed: true}), do: :ok

  def close(%__MODULE__{port: port}) do
    Praxo.Mcp.Transport.close(port)
    :ok
  end

  def list_tools(%__MODULE__{} = client, options \\ []) do
    case list_tools_loop(client, nil, MapSet.new(), MapSet.new(), [], options) do
      {:ok, tools, _names} -> {:ok, tools}
      {:error, error} -> {:error, error}
    end
  end

  def call_tool(%__MODULE__{} = client, name, arguments \\ %{}, options \\ []) do
    with :ok <- validate_tool_name(name),
         :ok <- validate_arguments(arguments),
         {:ok, result} <-
           request(
             client,
             "tools/call",
             %{"name" => name, "arguments" => arguments},
             options
           ) do
      map_call_result(name, result)
    end
  end

  def tools(%__MODULE__{} = client, options \\ []) do
    with {:ok, infos} <- list_tools(client, options) do
      tools =
        Enum.map(infos, fn info ->
          %Tool{
            name: info.name,
            description: info.description,
            parameters: info.input_schema,
            invoke: fn arguments ->
              case call_tool(client, info.name, arguments, options) do
                {:ok, value} -> value
                {:error, error} -> raise error
              end
            end
          }
        end)

      {:ok, tools}
    end
  end

  def register_tools(client, target, request_options \\ [])
  def register_tools(client, %AgentOptions{} = options, request_options) do
    with {:ok, tools} <- tools(client, request_options) do
      {:ok, %{options | tools: options.tools ++ tools}}
    end
  end

  def register_tools(client, existing, request_options) when is_list(existing) do
    with {:ok, tools} <- tools(client, request_options) do
      {:ok, existing ++ tools}
    end
  end

  def request(client, method, params, options \\ [])
  def request(%__MODULE__{closed: true}, _method, _params, _options) do
    {:error, error("MCP_CLOSED", "mcp: client is closed")}
  end

  def request(%__MODULE__{} = client, method, params, options) do
    id = System.unique_integer([:positive, :monotonic])
    message = %{"jsonrpc" => "2.0", "id" => id, "method" => method}

    message =
      if params == nil do
        message
      else
        Map.put(message, "params", params)
      end

    with :ok <- send_message(client, message) do
      timeout = Keyword.get(options, :timeout, client.timeout)
      cancel = Keyword.get(options, :cancel)
      receive_response(
        client.port,
        id,
        method,
        Praxo.Mcp.Transport.deadline(timeout),
        cancel,
        timeout
      )
    end
  end

  defp handshake(client, options) do
    protocol_version =
      Keyword.get(options, :protocol_version, @default_protocol_version)

    client_info = %{
      "name" => Keyword.get(options, :client_name, "praxo-core"),
      "version" => Keyword.get(options, :client_version, "0.4.1")
    }

    case request(
           client,
           "initialize",
           %{
             "protocolVersion" => protocol_version,
             "capabilities" => %{},
             "clientInfo" => client_info
           },
           timeout: client.timeout
         ) do
      {:ok, result} ->
        version = Map.get(result, "protocolVersion")

        if is_binary(version) and version != "" do
          case send_notification(client, "notifications/initialized", nil) do
            :ok ->
              {:ok,
               %{
                 client
                 | protocol_version: version,
                   server_info: as_object(Map.get(result, "serverInfo")),
                   server_capabilities: as_object(Map.get(result, "capabilities")),
                   connected: true
               }}

            {:error, error} ->
              {:error, error}
          end
        else
          {:error,
           error("MCP_HANDSHAKE", "mcp: initialize returned no protocol version")}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp list_tools_loop(client, cursor, names, cursors, acc, options) do
    params = if cursor == nil, do: nil, else: %{"cursor" => cursor}

    with {:ok, result} <- request(client, "tools/list", params, options) do
      raw = Map.get(result, "tools", [])

      if not is_list(raw) do
        {:error, error("MCP_PROTOCOL", "mcp: tools/list tools must be a list")}
      else
        case parse_tools(raw, names, acc) do
          {:ok, tools, names} ->
            next_cursor = Map.get(result, "nextCursor")
            advance_tools(client, next_cursor, names, cursors, tools, options)

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defp parse_tools(raw, names, acc) do
    Enum.reduce_while(raw, {:ok, acc, names}, fn item, {:ok, acc, names} ->
      with {:ok, tool} <- parse_tool(item),
           false <- MapSet.member?(names, tool.name) do
        {:cont, {:ok, acc ++ [tool], MapSet.put(names, tool.name)}}
      else
        true ->
          {:halt,
           {:error,
            error("MCP_DUPLICATE_TOOL", "mcp: duplicate tool #{tool_name(item)}")}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp parse_tool(item) when is_map(item) do
    name = Map.get(item, "name")
    schema = Map.get(item, "inputSchema")

    cond do
      not is_binary(name) or name == "" ->
        {:error, error("MCP_PROTOCOL", "mcp: tool name is required")}

      not is_map(schema) ->
        {:error, error("MCP_PROTOCOL", "mcp: missing input schema for #{name}")}

      true ->
        {:ok,
         %McpTool{
           name: name,
           description: string_or(Map.get(item, "description"), ""),
           title: string_or(Map.get(item, "title"), ""),
           input_schema: schema,
           annotations: as_object(Map.get(item, "annotations"))
         }}
    end
  end

  defp parse_tool(_item) do
    {:error, error("MCP_PROTOCOL", "mcp: tool definition must be an object")}
  end

  defp advance_tools(_client, nil, names, _cursors, tools, _options) do
    {:ok, sort_tools(tools), names}
  end

  defp advance_tools(client, next_cursor, names, cursors, tools, options) do
    cond do
      not is_binary(next_cursor) ->
        {:error,
         error("MCP_PROTOCOL", "mcp: tools/list nextCursor must be a string")}

      next_cursor == "" ->
        {:ok, sort_tools(tools), names}

      MapSet.member?(cursors, next_cursor) ->
        {:error,
         error("MCP_PAGINATION", "mcp: repeated tool pagination cursor")}

      true ->
        list_tools_loop(
          client,
          next_cursor,
          names,
          MapSet.put(cursors, next_cursor),
          tools,
          options
        )
    end
  end

  defp sort_tools(tools) do
    Enum.sort_by(tools, & &1.name)
  end

  defp map_call_result(name, result) do
    if Map.get(result, "isError") == true do
      detail = Enum.join(text_contents(result), "\n")
      {:error, error("MCP_TOOL_ERROR", "mcp: tool #{name} failed: #{detail}")}
    else
      case Map.get(result, "structuredContent") do
        nil ->
          text_result(result)

        :null ->
          text_result(result)

        structured ->
          {:ok, structured}
      end
    end
  end

  defp text_result(result) do
    case text_contents(result) do
      [] -> {:ok, nil}
      [text] -> {:ok, text}
      texts -> {:ok, texts}
    end
  end

  defp text_contents(result) do
    content = Map.get(result, "content", [])

    if is_list(content) do
      Enum.reduce(content, [], fn block, acc ->
        if is_map(block) and Map.get(block, "type") == "text" and
             is_binary(Map.get(block, "text")) do
          acc ++ [Map.get(block, "text")]
        else
          acc
        end
      end)
    else
      []
    end
  end

  defp validate_tool_name(name) do
    if is_binary(name) and name != "" do
      :ok
    else
      {:error, error("MCP_PROTOCOL", "mcp: tool name is required")}
    end
  end

  defp validate_arguments(arguments) when is_map(arguments), do: :ok

  defp validate_arguments(_arguments) do
    {:error, error("MCP_PROTOCOL", "mcp: tool arguments must be an object")}
  end

  defp send_notification(%__MODULE__{} = client, method, params) do
    message = %{"jsonrpc" => "2.0", "method" => method}

    message =
      if params == nil do
        message
      else
        Map.put(message, "params", params)
      end

    send_message(client, message)
  end

  defp send_message(%__MODULE__{port: port}, message) do
    try do
      case Port.command(port, [Json.encode(message), "\n"]) do
        true -> :ok
        false -> {:error, error("MCP_TRANSPORT", "mcp: failed to write to server")}
      end
    rescue
      _ ->
        {:error, error("MCP_TRANSPORT", "mcp: failed to write to server")}
    catch
      _, _ ->
        {:error, error("MCP_TRANSPORT", "mcp: failed to write to server")}
    end
  end

  defp receive_response(port, id, method, deadline, cancel, timeout) do
    remaining = deadline - System.monotonic_time(:millisecond)

    cond do
      remaining <= 0 ->
        send_notification(
          %__MODULE__{port: port},
          "notifications/cancelled",
          %{"requestId" => id, "reason" => "timeout"}
        )

        {:error,
         error("MCP_TIMEOUT", "mcp: #{method} timed out after #{timeout}ms")}

      is_function(cancel, 0) and cancel.() ->
        send_notification(
          %__MODULE__{port: port},
          "notifications/cancelled",
          %{"requestId" => id, "reason" => "cancelled"}
        )

        {:error, error("MCP_CANCELLED", "mcp: #{method} cancelled")}

      true ->
        receive do
          {^port, {:data, {:eol, line}}} ->
            handle_line(line, port, id, method, deadline, cancel, timeout)

          {^port, {:data, {:noeol, _chunk}}} ->
            receive_response(port, id, method, deadline, cancel, timeout)

          {^port, {:exit_status, status}} ->
            {:error, error("MCP_CLOSED", "mcp: server exited with status #{status}")}
        after
          min(max(remaining, 0), 50) ->
            receive_response(port, id, method, deadline, cancel, timeout)
        end
    end
  end

  defp handle_line(line, port, id, method, deadline, cancel, timeout) do
    case Json.parse(line) do
      {:ok, message} when is_map(message) ->
        cond do
          Map.get(message, "id") == id ->
            handle_response(message, method)

          Map.has_key?(message, "id") ->
            receive_response(port, id, method, deadline, cancel, timeout)

          true ->
            receive_response(port, id, method, deadline, cancel, timeout)
        end

      _ ->
        {:error, error("MCP_PROTOCOL", "mcp: server sent invalid JSON")}
    end
  end

  defp handle_response(message, method) do
    case Map.get(message, "error") do
      error_value when is_map(error_value) ->
        text = Map.get(error_value, "message") || "#{method} failed"
        {:error, error("MCP_RPC", "mcp: #{method}: #{text}")}

      _ ->
        case Map.get(message, "result") do
          result when is_map(result) ->
            {:ok, result}

          _ ->
            {:error,
             error("MCP_PROTOCOL", "mcp: #{method} result must be an object")}
        end
    end
  end

  defp as_object(value) when is_map(value), do: value
  defp as_object(_value), do: %{}

  defp string_or(value, _fallback) when is_binary(value), do: value
  defp string_or(_value, fallback), do: fallback

  defp tool_name(item) when is_map(item) do
    case Map.get(item, "name") do
      name when is_binary(name) -> name
      _ -> ""
    end
  end

  defp tool_name(_item), do: ""

  defp error(code, message), do: %Error{code: code, message: message}
end
