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
      timeout: Keyword.get(opts, :timeout, 60_000)
    }

    fn request -> generate(request, config) end
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

  defp build_payload(request, config) do
    {system, messages} = build_messages(request.messages)
    tools = build_tools(request.tools)

    payload = %{
      "model" => config.model,
      "max_tokens" => config.max_tokens,
      "messages" => messages
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
