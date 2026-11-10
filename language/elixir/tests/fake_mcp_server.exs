defmodule Praxo.FakeMcpServer do
  @protocol "2024-11-05"

  def main(args) do
    mode = flag(args, "--mode", "default")
    marker = flag(args, "--marker", nil)
    loop(mode, marker, false)
  end

  defp loop(mode, marker, initialized) do
    case IO.gets(:stdio, "") do
      :eof ->
        mark(marker, "exit")

      {:error, _reason} ->
        mark(marker, "exit")

      line ->
        case String.trim(line) do
          "" ->
            loop(mode, marker, initialized)

          text ->
            case decode(text) do
              {:ok, message} when is_map(message) ->
                loop(mode, marker, handle(message, mode, marker, initialized))

              _ ->
                loop(mode, marker, initialized)
            end
        end
    end
  end

  defp handle(message, mode, marker, initialized) do
    method = Map.get(message, "method")
    id = Map.get(message, "id")
    params = Map.get(message, "params", %{})

    case method do
      "initialize" ->
        respond(id, %{
          "protocolVersion" => @protocol,
          "capabilities" => %{"tools" => %{}},
          "serverInfo" => %{"name" => "fake-mcp", "version" => "1.0.0"}
        })

        initialized

      "notifications/initialized" ->
        mark(marker, "initialized")
        true

      "notifications/cancelled" ->
        mark(marker, "cancelled:#{Map.get(params, "requestId")}")
        initialized

      "tools/list" ->
        if initialized do
          respond(id, list_tools(mode, Map.get(params, "cursor")))
        else
          respond_error(id, -32002, "not initialized")
        end

        initialized

      "tools/call" ->
        if initialized do
          mark(marker, "call:#{Map.get(params, "name")}")

          if mode == "hang" do
            mark(marker, "hanging")
          else
            respond(id, call_tool(params))
          end
        else
          respond_error(id, -32002, "not initialized")
        end

        initialized

      _ ->
        if id != nil do
          respond_error(id, -32601, "method not found")
        end

        initialized
    end
  end

  defp list_tools("repeated-cursor", cursor) do
    label = if cursor == nil, do: "loop-start", else: "loop-more"

    %{"tools" => [generic_tool(label)], "nextCursor" => "loop"}
  end

  defp list_tools("duplicate-name", nil) do
    %{"tools" => [generic_tool("dup")], "nextCursor" => "page-2"}
  end

  defp list_tools("duplicate-name", _cursor) do
    %{"tools" => [generic_tool("dup")]}
  end

  defp list_tools(_mode, nil) do
    %{
      "tools" => [
        %{
          "name" => "echo",
          "description" => "Echo input",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{"text" => %{"type" => "string"}},
            "required" => ["text"]
          }
        },
        generic_tool("add")
      ],
      "nextCursor" => "page-2"
    }
  end

  defp list_tools(_mode, "page-2") do
    %{"tools" => [generic_tool("fail"), generic_tool("multi")]}
  end

  defp list_tools(_mode, _cursor), do: %{"tools" => []}

  defp call_tool(params) do
    name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})

    case name do
      "echo" ->
        %{"content" => [%{"type" => "text", "text" => Map.get(arguments, "text", "")}]}

      "add" ->
        total = number(arguments, "a") + number(arguments, "b")

        %{
          "content" => [%{"type" => "text", "text" => Integer.to_string(total)}],
          "structuredContent" => %{"sum" => total}
        }

      "multi" ->
        %{
          "content" => [
            %{"type" => "text", "text" => "one"},
            %{"type" => "text", "text" => "two"}
          ]
        }

      "fail" ->
        %{
          "isError" => true,
          "content" => [%{"type" => "text", "text" => "boom"}]
        }

      _ ->
        %{
          "isError" => true,
          "content" => [%{"type" => "text", "text" => "unknown tool #{name}"}]
        }
    end
  end

  defp generic_tool(name) do
    %{
      "name" => name,
      "description" => "generic",
      "inputSchema" => %{"type" => "object", "properties" => %{}}
    }
  end

  defp number(arguments, key) do
    case Map.get(arguments, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> trunc(value)
      _ -> 0
    end
  end

  defp decode(text) do
    {:ok, :json.decode(text)}
  rescue
    _ -> {:error, :invalid_json}
  catch
    _, _ -> {:error, :invalid_json}
  end

  defp respond(id, result) do
    write(%{"jsonrpc" => "2.0", "id" => id, "result" => result})
  end

  defp respond_error(id, code, message) do
    write(%{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}})
  end

  defp write(message) do
    encoded = :json.encode(message) |> IO.iodata_to_binary()
    IO.puts(:stdio, encoded)
  end

  defp mark(nil, _line), do: :ok

  defp mark(path, line) do
    File.write(path, line <> "\n", [:append])
  rescue
    _ -> :ok
  end

  defp flag(args, name, fallback) do
    case Enum.find_index(args, &(&1 == name)) do
      nil -> fallback
      index -> Enum.at(args, index + 1, fallback)
    end
  end
end

Praxo.FakeMcpServer.main(System.argv())
