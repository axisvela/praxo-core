defmodule Praxo.PluginProcess do
  @moduledoc """
  JSON-Lines process plugin host with token authentication, health handshake,
  invocation timeout, cooperative cancel, and typed call errors.
  """

  defmodule CallError do
    defexception [:code, :message]

    @codes ~w(CAPABILITY_DENIED NOT_ACTIVE NOT_FOUND INVALID_REQUEST TIMEOUT INTERNAL CANCELED)

    @impl true
    def exception(opts) do
      raw = to_string(Keyword.get(opts, :code, "INTERNAL"))
      code = if raw in @codes, do: raw, else: "INTERNAL"
      message = Keyword.get(opts, :message, "")
      %__MODULE__{code: code, message: if(message == "", do: code, else: message)}
    end
  end

  alias Praxo.Json

  defstruct [:port, :plugin_id, :token, :seq, active: false]

  @protocol_version 1
  @control_service "host.control"

  def start(config) do
    plugin_id = Map.fetch!(config, :plugin_id)
    path = Map.fetch!(config, :path)
    args = Map.get(config, :args, [])
    token = Map.get(config, :token, "")
    token = if token in [nil, ""], do: random_token(), else: token
    token_env = Map.get(config, :token_env_var, "PRAXOVELA_PLUGIN_TOKEN")

    executable = System.find_executable(path) || path
    port =
      Port.open({:spawn_executable, String.to_charlist(executable)}, [
        :binary,
        :exit_status,
        {:line, 8 * 1024 * 1024},
        {:args, Enum.map(args, &String.to_charlist/1)},
        {:env, [{String.to_charlist(token_env), String.to_charlist(token)}]}
      ])

    state = %__MODULE__{port: port, plugin_id: plugin_id, token: token, seq: 0}

    case call(state, @control_service, "health", "", Map.get(config, :start_timeout, 10_000)) do
      {:ok, _payload} -> {:ok, %{state | active: true}}
      {:error, error} ->
        Port.close(port)
        {:error, error}
    end
  end

  def invoke(state, service, method, payload, timeout \\ 30_000)

  def invoke(%__MODULE__{active: false}, _service, _method, _payload, _timeout) do
    {:error, %CallError{code: "NOT_ACTIVE", message: "plugin: host is not active"}}
  end

  def invoke(state, service, method, payload, timeout) do
    call(state, service, method, payload, timeout)
  end

  def stop(%__MODULE__{port: port} = state) do
    _ =
      if state.active do
        call(state, @control_service, "shutdown", "", 5_000)
      end

    if Port.info(port) != nil, do: Port.close(port)
    :ok
  end

  defp call(state, service, method, payload, timeout) do
    seq = state.seq + 1
    id = "req-#{seq}"
    frame = %{
      "id" => id,
      "version" => @protocol_version,
      "plugin_id" => state.plugin_id,
      "service" => service,
      "method" => method,
      "token" => state.token,
      "payload" => Base.encode64(payload || "")
    }

    case Port.command(state.port, Json.encode(frame) <> "\n") do
      true -> await(state, id, timeout)
      false -> {:error, %CallError{code: "INTERNAL", message: "plugin: process closed"}}
    end
  end

  defp await(state, id, timeout) do
    receive do
      {port, {:data, {:eol, line}}} when port == state.port ->
        response = Json.parse!(line)
        cond do
          response["id"] != id ->
            await(state, id, timeout)

          response["ok"] != true ->
            {:error, error(response["code"], response["message"])}

          true ->
            case Base.decode64(to_string(response["payload"] || "")) do
              {:ok, payload} -> {:ok, payload}
              :error -> {:error, %CallError{code: "INTERNAL", message: "plugin: invalid payload"}}
            end
        end

      {port, {:exit_status, status}} when port == state.port ->
        {:error, %CallError{code: "INTERNAL", message: "plugin: process exited #{status}"}}
    after
      timeout ->
        send_cancel(state, id)
        if Port.info(state.port) != nil, do: Port.close(state.port)
        {:error, %CallError{code: "TIMEOUT", message: "plugin: invocation timed out"}}
    end
  end

  defp send_cancel(state, id) do
    frame = %{
      "id" => id,
      "version" => @protocol_version,
      "plugin_id" => state.plugin_id,
      "service" => @control_service,
      "method" => "cancel",
      "token" => state.token
    }

    Port.command(state.port, Json.encode(frame) <> "\n")
  rescue
    _ -> false
  end

  defp error(code, message) do
    raw = to_string(code || "INTERNAL")
    allowed = ~w(CAPABILITY_DENIED NOT_ACTIVE NOT_FOUND INVALID_REQUEST TIMEOUT INTERNAL CANCELED)
    %CallError{code: if(raw in allowed, do: raw, else: "INTERNAL"), message: to_string(message || "")}
  end

  defp random_token do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end
end
