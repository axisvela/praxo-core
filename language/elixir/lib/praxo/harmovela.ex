defmodule Praxo.HarmovelaSink do
  @moduledoc "Harmovela HTTP event sink."

  defstruct base_url: "",
            source: "praxo-core",
            spec_version: "0.2",
            transport: nil,
            __harmovela_sink__: true

  def new(opts) do
    base_url =
      opts
      |> Keyword.fetch!(:base_url)
      |> String.trim_trailing("/")

    %__MODULE__{
      base_url: base_url,
      source: Keyword.get(opts, :source, "praxo-core"),
      spec_version: Keyword.get(opts, :spec_version, "0.2"),
      transport: Keyword.get(opts, :transport)
    }
  end

  def emit(%__MODULE__{base_url: ""}, _event) do
    raise Praxo.Error,
      code: "HARMOVELA_BASE_URL",
      message: "harmovela: base URL is required"
  end

  def emit(%__MODULE__{} = sink, %Praxo.Event{} = event) do
    body = Praxo.Json.encode(envelope(sink, event))

    request = %{
      method: "POST",
      url: sink.base_url <> "/events",
      headers: %{"content-type" => "application/json"},
      body: body
    }

    case send_request(sink, request) do
      {:ok, status, _response_body} when status in 200..299 ->
        sink

      {:ok, status, response_body} ->
        bounded =
          (response_body || "")
          |> to_string()
          |> String.slice(0, 512)
          |> String.trim()

        raise Praxo.Error,
          code: "HARMOVELA_HTTP",
          message: "harmovela: HTTP #{status}: #{bounded}"

      {:error, reason} ->
        raise Praxo.Error,
          code: "HARMOVELA_HTTP",
          message: "harmovela: #{inspect(reason)}"
    end
  end

  defp send_request(%{transport: transport}, request) when is_function(transport, 1) do
    transport.(request)
  end

  defp send_request(_sink, request) do
    :inets.start()
    :ssl.start()

    url = String.to_charlist(request.url)

    headers =
      Enum.map(request.headers, fn {key, value} ->
        {String.to_charlist(key), String.to_charlist(value)}
      end)

    case :httpc.request(
           :post,
           {url, headers, ~c"application/json", request.body},
           [timeout: 30_000],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _, response_body}} -> {:ok, status, response_body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp envelope(sink, event) do
    {created_at, nanos} = timestamp()

    payload = if is_map(event.data), do: event.data, else: %{}

    payload =
      if is_binary(event.session_id) and event.session_id != "" do
        Map.put(payload, "session_id", event.session_id)
      else
        payload
      end

    payload =
      if is_binary(event.run_id) and event.run_id != "" do
        Map.put(payload, "run_id", event.run_id)
      else
        payload
      end

    %{
      "spec_version" => sink.spec_version,
      "id" => event_id(event, nanos),
      "type" => event.kind,
      "source" => sink.source,
      "created_at" => created_at,
      "payload" => payload
    }
  end

  defp event_id(event, nanos) do
    prefix =
      cond do
        is_binary(event.run_id) and event.run_id != "" -> event.run_id
        is_binary(event.session_id) and event.session_id != "" -> event.session_id
        true -> "event"
      end

    "#{prefix}-#{nanos}"
  end

  defp timestamp do
    now = DateTime.utc_now()
    seconds = DateTime.to_unix(now, :second)
    nanos = elem(now.microsecond, 0) * 1000
    base = Calendar.strftime(now, "%Y-%m-%dT%H:%M:%S")
    created_at = "#{base}.#{String.pad_leading(Integer.to_string(nanos), 9, "0")}Z"
    {created_at, seconds * 1_000_000_000 + nanos}
  end
end
