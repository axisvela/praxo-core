defmodule Praxo.Anthropic do
  @moduledoc "Anthropic Messages adapter."

  alias Praxo.Json

  def new(opts) do
    config = %{
      base_url: String.trim_trailing(Keyword.get(opts, :base_url, "https://api.anthropic.com"), "/"),
      model: Keyword.fetch!(opts, :model),
      api_key: Keyword.get(opts, :api_key),
      version: Keyword.get(opts, :version, "2023-06-01"),
      max_tokens: Keyword.get(opts, :max_tokens, 1024),
      transport: Keyword.get(opts, :transport),
      stream_transport: Keyword.get(opts, :stream_transport),
      timeout: Keyword.get(opts, :timeout, 60_000)
    }

    fn request -> generate(request, config) end
  end

  def streaming_model(opts) do
    config = %{
      base_url: String.trim_trailing(Keyword.get(opts, :base_url, "https://api.anthropic.com"), "/"),
      model: Keyword.fetch!(opts, :model),
      api_key: Keyword.get(opts, :api_key),
      version: Keyword.get(opts, :version, "2023-06-01"),
      max_tokens: Keyword.get(opts, :max_tokens, 1024),
      transport: Keyword.get(opts, :transport),
      stream_transport: Keyword.get(opts, :stream_transport),
      timeout: Keyword.get(opts, :timeout, 60_000)
    }

    %{
      generate: fn request -> generate(request, config) end,
      stream: fn request, on_delta -> generate_stream(request, config, on_delta) end
    }
  end

  def generate(%Praxo.Request{} = request, config) do
    if config.api_key in [nil, ""], do: throw("ANTHROPIC_API_KEY")
    if config.model in [nil, ""], do: throw("ANTHROPIC_MODEL")

    payload = build_payload(request, config)

    case do_transport(payload, config) do
      {:ok, data} -> parse_response(data)
      {:error, reason} -> {:error, reason}
    end
  catch
    "ANTHROPIC_API_KEY" -> {:error, "ANTHROPIC_API_KEY"}
    "ANTHROPIC_MODEL" -> {:error, "ANTHROPIC_MODEL"}
  end

  def generate_stream(%Praxo.Request{} = request, config, on_delta) do
    if config.api_key in [nil, ""], do: throw("ANTHROPIC_API_KEY")
    if config.model in [nil, ""], do: throw("ANTHROPIC_MODEL")

    payload = build_payload(request, config, true)

    case do_stream_transport(payload, config) do
      {:ok, text} -> parse_stream(text, on_delta)
      {:error, reason} -> {:error, reason}
    end
  catch
    "ANTHROPIC_API_KEY" -> {:error, "ANTHROPIC_API_KEY"}
    "ANTHROPIC_MODEL" -> {:error, "ANTHROPIC_MODEL"}
  end

  defp do_stream_transport(payload, %{stream_transport: transport})
       when is_function(transport, 1) do
    transport.(payload)
  end

  defp do_stream_transport(payload, config) do
    :inets.start()
    :ssl.start()
    url = String.to_charlist(config.base_url <> "/v1/messages")

    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"accept", ~c"text/event-stream"},
      {~c"x-api-key", String.to_charlist(config.api_key || "")},
      {~c"anthropic-version", String.to_charlist(config.version)}
    ]

    case :httpc.request(
           :post,
           {url, headers, ~c"application/json", Json.encode(payload)},
           [timeout: config.timeout],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _, body}} when status >= 200 and status < 300 ->
        {:ok, body}

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "PROVIDER_HTTP_#{status}"}

      {:error, _} ->
        {:error, "PROVIDER_HTTP"}
    end
  end

  defp parse_stream(text, on_delta) do
    initial = %{
      content: "",
      calls: %{},
      input: 0,
      output: 0,
      cached: 0,
      stop: nil,
      stopped: false
    }

    result =
      text
      |> String.split("\n")
      |> Enum.reduce_while({:ok, initial}, fn raw, {:ok, state} ->
        line = String.trim(raw)

        if String.starts_with?(line, "data:") do
          chunk = line |> String.slice(5, String.length(line) - 5) |> String.trim()

          if chunk == "" do
            {:cont, {:ok, state}}
          else
            case Json.parse(chunk) do
              {:error, _} ->
                {:halt, {:error, "MODEL_STREAM"}}

              {:ok, event} ->
                case handle_stream_event(event, state, on_delta) do
                  {:ok, next} ->
                    if next.stopped do
                      {:halt, {:ok, next}}
                    else
                      {:cont, {:ok, next}}
                    end

                  {:error, code} ->
                    {:halt, {:error, code}}
                end
            end
          end
        else
          {:cont, {:ok, state}}
        end
      end)

    case result do
      {:ok, state} ->
        if state.stopped or state.stop != nil do
          build_stream_response(state)
        else
          {:error, "MODEL_STREAM"}
        end

      _ ->
        {:error, "MODEL_STREAM"}
    end
  end

  defp handle_stream_event(event, state, on_delta) when is_map(event) do
    case Map.get(event, "type", "") do
      "message_start" ->
        usage = get_in(event, ["message", "usage"]) || %{}
        {:ok, %{state | input: usage["input_tokens"] || 0, cached: usage["cache_read_input_tokens"] || 0}}

      "content_block_start" ->
        index = Map.get(event, "index", 0)
        block = Map.get(event, "content_block", %{})

        if block["type"] == "tool_use" do
          calls =
            Map.put(state.calls, index, %{
              id: block["id"] || "",
              name: block["name"] || "",
              arguments: ""
            })

          {:ok, %{state | calls: calls}}
        else
          {:ok, state}
        end

      "content_block_delta" ->
        index = Map.get(event, "index", 0)
        delta = Map.get(event, "delta", %{})

        case delta["type"] do
          "text_delta" ->
            text = delta["text"] || ""

            if text == "" do
              {:ok, state}
            else
              case on_delta.(text) do
                {:error, code} -> {:error, code}
                _ -> {:ok, %{state | content: state.content <> text}}
              end
            end

          "input_json_delta" ->
            calls =
              Map.update(state.calls, index, %{id: "", name: "", arguments: delta["partial_json"] || ""}, fn call ->
                %{call | arguments: call.arguments <> (delta["partial_json"] || "")}
              end)

            {:ok, %{state | calls: calls}}

          _ ->
            {:ok, state}
        end

      "message_delta" ->
        stop = get_in(event, ["delta", "stop_reason"]) || state.stop
        output = get_in(event, ["usage", "output_tokens"]) || state.output
        {:ok, %{state | stop: stop, output: output}}

      "message_stop" ->
        {:ok, %{state | stopped: true}}

      "error" ->
        {:error, "MODEL_STREAM"}

      _ ->
        {:ok, state}
    end
  end

  defp handle_stream_event(_event, state, _on_delta), do: {:ok, state}

  defp build_stream_response(state) do
    calls =
      state.calls
      |> Enum.sort()
      |> Enum.filter(fn {_index, call} -> call.name != "" end)
      |> Enum.reduce_while({:ok, []}, fn {_index, call}, {:ok, acc} ->
        arguments =
          if call.arguments == "" do
            {:ok, %{}}
          else
            case Json.parse(call.arguments) do
              {:ok, value} when is_map(value) -> {:ok, value}
              _ -> {:error, "PROVIDER_JSON"}
            end
          end

        case arguments do
          {:ok, value} ->
            {:cont, {:ok, acc ++ [%Praxo.ToolCall{id: call.id, name: call.name, arguments: value}]}}

          {:error, code} ->
            {:halt, {:error, code}}
        end
      end)

    case calls do
      {:ok, tool_calls} ->
        {:ok,
         %Praxo.Response{
           message: %Praxo.Message{role: "assistant", content: state.content, tool_calls: tool_calls},
           usage: %Praxo.Usage{input_tokens: state.input, output_tokens: state.output}
         }}

      {:error, code} ->
        {:error, code}
    end
  end

  defp build_payload(request, config, stream \\ false) do
    {system, messages} = build_messages(request.messages)
    tools = build_tools(request.tools)

    payload = %{
      "model" => config.model,
      "max_tokens" => config.max_tokens,
      "messages" => messages,
      "stream" => stream
    }

    payload = if system == "", do: payload, else: Map.put(payload, "system", system)
    payload = if tools == [], do: payload, else: Map.put(payload, "tools", tools)

    if tools != [] do
      case tool_choice(request.tool_choice) do
        nil -> payload
        choice -> Map.put(payload, "tool_choice", choice)
      end
    else
      payload
    end
  end

  defp build_messages(messages) do
    {system, out, pending} =
      Enum.reduce(messages, {[], [], []}, fn message, {system, out, pending} ->
        cond do
          message.role == "system" ->
            system =
              if message.content in [nil, ""], do: system, else: system ++ [message.content]
            {system, out, pending}

          message.role == "tool" ->
            result = %{
              "type" => "tool_result",
              "tool_use_id" => message.tool_id || "",
              "content" => message.content || ""
            }
            {system, out, pending ++ [result]}

          true ->
            out = flush_tools(out, pending)
            content = message_content(message)
            out = if content == [], do: out, else: out ++ [%{"role" => message.role, "content" => content}]
            {system, out, []}
        end
      end)

    out = flush_tools(out, pending)
    {Enum.join(system, "\n\n"), out}
  end

  defp flush_tools(out, []), do: out
  defp flush_tools(out, pending), do: out ++ [%{"role" => "user", "content" => pending}]

  defp message_content(message) do
    content =
      []
      |> maybe_text(message.content)
      |> then(fn content ->
        Enum.reduce(message.content_blocks || [], content, fn block, acc ->
          if block.kind == "text" and is_binary(block.text) and block.text != "" do
            acc ++ [%{"type" => "text", "text" => block.text}]
          else
            acc
          end
        end)
      end)

    Enum.reduce(message.tool_calls || [], content, fn call, acc ->
      acc ++ [%{
        "type" => "tool_use",
        "id" => call.id,
        "name" => call.name,
        "input" => call.arguments || %{}
      }]
    end)
  end

  defp maybe_text(content, nil), do: content
  defp maybe_text(content, ""), do: content
  defp maybe_text(content, text), do: content ++ [%{"type" => "text", "text" => text}]

  defp build_tools([]), do: []

  defp build_tools(tools) do
    Enum.map(tools, fn tool ->
      %{
        "name" => tool.name,
        "description" => tool.description,
        "input_schema" => tool.parameters || %{"type" => "object", "properties" => %{}}
      }
    end)
  end

  defp tool_choice("auto"), do: %{"type" => "auto"}
  defp tool_choice("required"), do: %{"type" => "any"}
  defp tool_choice("none"), do: %{"type" => "none"}
  defp tool_choice(_), do: nil

  defp do_transport(payload, %{transport: transport}) when is_function(transport, 1) do
    transport.(payload)
  end

  defp do_transport(payload, config) do
    :inets.start()
    :ssl.start()
    url = String.to_charlist(config.base_url <> "/v1/messages")
    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"x-api-key", String.to_charlist(config.api_key || "")},
      {~c"anthropic-version", String.to_charlist(config.version)}
    ]
    body = Json.encode(payload)

    case :httpc.request(
           :post,
           {url, headers, ~c"application/json", body},
           [timeout: config.timeout],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _, response_body}} when status >= 200 and status < 300 ->
        case Json.parse(response_body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "PROVIDER_JSON"}
        end

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "PROVIDER_HTTP_#{status}"}

      {:error, _} ->
        {:error, "PROVIDER_HTTP"}
    end
  end

  defp parse_response(data) do
    error = data["error"]
    if error != nil, do: throw("PROVIDER_HTTP")
    {content, calls} = parse_content(data["content"] || [])
    usage = data["usage"] || %{}

    {:ok,
     %Praxo.Response{
       message: %Praxo.Message{
         role: "assistant",
         content: content,
         tool_calls: calls
       },
       usage: %Praxo.Usage{
         input_tokens: usage["input_tokens"] || 0,
         output_tokens: usage["output_tokens"] || 0
       }
     }}
  catch
    "PROVIDER_HTTP" -> {:error, "PROVIDER_HTTP"}
  end

  defp parse_content(blocks) do
    Enum.reduce(blocks, {"", []}, fn block, {text, calls} ->
      case block["type"] do
        "text" -> {text <> (block["text"] || ""), calls}
        "tool_use" ->
          call = %Praxo.ToolCall{
            id: block["id"] || "call-#{length(calls) + 1}",
            name: block["name"] || "",
            arguments: block["input"] || %{}
          }
          {text, calls ++ [call]}
        _ -> {text, calls}
      end
    end)
  end
end
