defmodule Praxo.OtelSink do
  @moduledoc "OpenTelemetry OTLP/HTTP event sink."

  defstruct endpoint: "http://127.0.0.1:4318/v1/traces",
            service_name: "praxo-core",
            transport: nil,
            allowed_data_keys: [],
            __otel_sink__: true

  def new(opts) do
    %__MODULE__{
      endpoint: Keyword.get(opts, :endpoint, "http://127.0.0.1:4318/v1/traces"),
      service_name: Keyword.get(opts, :service_name, "praxo-core"),
      transport: Keyword.get(opts, :transport),
      allowed_data_keys: Keyword.get(opts, :allowed_data_keys, [])
    }
  end

  def emit(%__MODULE__{} = sink, %Praxo.Event{} = event) do
    data = if is_map(event.data), do: event.data, else: %{}
    stamp = timestamp()
    key = Enum.join([event.session_id, event.run_id || "", event.kind, stamp,
                     Praxo.Json.encode(data)], "|")
    digest = :crypto.hash(:sha256, key) |> Base.encode16(case: :lower)
    trace_id = binary_part(digest, 0, 32)
    span_id = binary_part(digest, 32, 16)
    nanos = System.system_time(:nanosecond)
    attributes = [attribute("praxo.event.type", event.kind)]

    attributes =
      if event.session_id != "",
        do: attributes ++ [attribute("praxo.session.id", event.session_id)],
        else: attributes

    attributes =
      if event.run_id && event.run_id != "",
        do: attributes ++ [attribute("praxo.run.id", event.run_id)],
        else: attributes

    attributes = attributes ++ [attribute("praxo.event.at", stamp)]

    attributes =
      Enum.reduce(sink.allowed_data_keys, attributes, fn name, acc ->
        case Map.fetch(data, name) do
          {:ok, value} -> acc ++ [attribute("praxo.event.data." <> name, text(value))]
          :error -> acc
        end
      end)

    payload = %{
      "resourceSpans" => [
        %{
          "resource" => %{
            "attributes" => [attribute("service.name", sink.service_name)]
          },
          "scopeSpans" => [
            %{
              "scope" => %{"name" => "praxo-core"},
              "spans" => [
                %{
                  "traceId" => trace_id,
                  "spanId" => span_id,
                  "name" => "praxo." <> event.kind,
                  "kind" => 1,
                  "startTimeUnixNano" => Integer.to_string(nanos),
                  "endTimeUnixNano" => Integer.to_string(nanos),
                  "attributes" => attributes
                }
              ]
            }
          ]
        }
      ]
    }

    request = %{
      method: "POST",
      url: sink.endpoint,
      headers: %{"content-type" => "application/json"},
      body: Praxo.Json.encode(payload)
    }

    case send_request(sink, request) do
      {:ok, status, _body} when status in 200..299 ->
        sink

      {:ok, status, body} ->
        bounded =
          (body || "")
          |> to_string()
          |> String.slice(0, 512)
          |> String.trim()

        raise Praxo.Error,
          code: "OTEL_HTTP",
          message: "otel: HTTP #{status}: #{bounded}"

      {:error, reason} ->
        raise Praxo.Error,
          code: "OTEL_HTTP",
          message: "otel: #{inspect(reason)}"
    end
  end

  defp attribute(key, value) do
    %{"key" => key, "value" => %{"stringValue" => to_string(value)}}
  end

  defp text(value) when is_binary(value), do: value
  defp text(value), do: Praxo.Json.encode(value)

  defp timestamp, do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp send_request(%{transport: transport}, request) when is_function(transport, 1) do
    transport.(request)
  end

  defp send_request(_sink, request) do
    :inets.start()
    :ssl.start()

    headers =
      Enum.map(request.headers, fn {key, value} ->
        {String.to_charlist(key), String.to_charlist(value)}
      end)

    case :httpc.request(
           :post,
           {String.to_charlist(request.url), headers, ~c"application/json", request.body},
           [timeout: 30_000],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _, body}} -> {:ok, status, body}
      {:error, reason} -> {:error, reason}
    end
  end
end
