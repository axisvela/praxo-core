defmodule Praxo.Mcp.Transport do
  alias Praxo.Error

  @max_line 1_048_576

  def open(options) do
    command = Keyword.get(options, :command)

    if not is_binary(command) or command == "" do
      {:error, error("MCP_TRANSPORT", "mcp: command is required")}
    else
      args = Keyword.get(options, :args, []) |> Enum.map(&to_string/1)
      port_options = port_options(options)

      try do
        port =
          if batch?(command) do
            Port.open({:spawn, command_line(command, args)}, port_options)
          else
            Port.open(
              {:spawn_executable, command},
              [{:args, args} | port_options]
            )
          end

        {:ok, port}
      rescue
        _ ->
          try do
            {:ok, Port.open({:spawn, command_line(command, args)}, port_options)}
          rescue
            _ ->
              {:error,
               error("MCP_TRANSPORT", "mcp: failed to start server #{command}")}
          end
      end
    end
  end

  def close(port) do
    os_pid =
      try do
        case Port.info(port, :os_pid) do
          {:os_pid, pid} -> pid
          _ -> nil
        end
      rescue
        _ -> nil
      end

    try do
      Port.close(port)
    rescue
      _ -> :ok
    end

    receive do
      {^port, {:exit_status, _status}} -> :ok
    after
      1_000 -> kill_process(os_pid)
    end
  end

  def deadline(timeout), do: System.monotonic_time(:millisecond) + timeout

  defp port_options(options) do
    base = [:binary, :exit_status, {:line, @max_line}]

    base =
      case Keyword.get(options, :env) do
        nil ->
          base

        env when is_map(env) or is_list(env) ->
          [
            {:env,
             Enum.map(env, fn {key, value} ->
               {to_charlist(key), to_charlist(value)}
             end)}
            | base
          ]
      end

    case Keyword.get(options, :cwd) do
      nil -> base
      cwd -> [{:cd, to_charlist(cwd)} | base]
    end
  end

  defp batch?(command) do
    String.downcase(Path.extname(command)) in [".bat", ".cmd"]
  end

  defp command_line(command, args) do
    Enum.map_join([command | args], " ", &quote_arg/1)
  end

  defp quote_arg(value) do
    "\"" <> String.replace(to_string(value), "\"", "\\\"") <> "\""
  end

  defp kill_process(nil), do: :ok

  defp kill_process(os_pid) do
    if match?({:win32, _}, :os.type()) do
      System.cmd("taskkill", ["/PID", Integer.to_string(os_pid), "/T", "/F"],
        stderr_to_stdout: true
      )
    else
      System.cmd("kill", ["-9", Integer.to_string(os_pid)], stderr_to_stdout: true)
    end

    :ok
  rescue
    _ -> :ok
  end

  defp error(code, message), do: %Error{code: code, message: message}
end
