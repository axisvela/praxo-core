defmodule Praxo.Gemini do
  @moduledoc "Gemini generateContent adapter."

  alias Praxo.Json

  def new(opts) do
    config = %{
      base_url:
        String.trim_trailing(
          Keyword.get(opts, :base_url, "https://generativelanguage.googleapis.com"),
          "/"
        ),
      model: Keyword.fetch!(opts, :model),
      api_key: Keyword.get(opts, :api_key),
      max_output_tokens: Keyword.get(opts, :max_output_tokens, 0),
      transport: Keyword.get(opts, :transport),
      timeout: Keyword.get(opts, :timeout, 60_000)
    }

    fn request -> generate(request, config) end
  end

  def generate(%Praxo.Request{} = request, config) do
    if config.api_key in [nil, ""], do: throw("GEMINI_API_KEY")
    if config.model in [nil, ""], do: throw("GEMINI_MODEL")

    payload = build_payload(request, config)

    case do_transport(payload, config) do
      {:ok, data} -> parse_response(data)
      {:error, reason} -> {:error, reason}
    end
  catch
    "GEMINI_API_KEY" -> {:error, "GEMINI_API_KEY"}
    "GEMINI_MODEL" -> {:error, "GEMINI_MODEL"}
    "PROVIDER_HTTP" -> {:error, "PROVIDER_HTTP"}
  end

  defp build_payload(request, config) do
    {system, contents} = build_contents(request.messages)
    tools = build_tools(request.tools)

    payload = %{"contents" => contents}

    payload =
      if system == [],
        do: payload,
        else: Map.put(payload, "system_instruction", %{"parts" => system})

    payload =
      if tools == [] do
        payload
      else
        payload
        |> Map.put("tools", [%{"functionDeclarations" => tools}])
        |> Map.put("toolConfig", %{
          "functionCallingConfig" => %{"mode" => tool_mode(request.tool_choice)}
        })
      end

    if config.max_output_tokens > 0 do
      Map.put(payload, "generationConfig", %{
        "maxOutputTokens" => config.max_output_tokens
      })
    else
      payload
    end
  end

  defp build_contents(messages) do
    {system, out, pending, _names} =
      Enum.reduce(messages, {[], [], [], %{}}, fn message, {system, out, pending, names} ->
        cond do
          message.role == "system" ->
            system =
              if message.content in [nil, ""],
                do: system,
                else: system ++ [%{"text" => message.content}]
            {system, out, pending, names}

          message.role == "tool" ->
            name = Map.get(names, message.tool_id || "", message.tool_id || "tool")
            result = %{
              "functionResponse" => %{
                "name" => name,
                "response" => %{"result" => message.content || ""}
              }
            }
            {system, out, pending ++ [result], names}

          true ->
            out = flush_tools(out, pending)
            parts = message_parts(message)
            out = if parts == [], do: out, else: out ++ [%{"role" => role(message.role), "parts" => parts}]
            names =
              Enum.reduce(message.tool_calls || [], names, fn call, acc ->
                if call.id in [nil, ""] or call.name in [nil, ""],
                  do: acc,
                  else: Map.put(acc, call.id, call.name)
              end)
            {system, out, [], names}
        end
      end)

    {system, flush_tools(out, pending)}
  end

  defp role("assistant"), do: "model"
  defp role(_), do: "user"

  defp flush_tools(out, []), do: out
  defp flush_tools(out, pending), do: out ++ [%{"role" => "user", "parts" => pending}]

  defp message_parts(message) do
    parts =
      []
      |> maybe_text(message.content)
      |> then(fn parts ->
        Enum.reduce(message.content_blocks || [], parts, fn block, acc ->
          if block.kind == "text" and is_binary(block.text) and block.text != "" do
            acc ++ [%{"text" => block.text}]
          else
            acc
          end
        end)
      end)

    Enum.reduce(message.tool_calls || [], parts, fn call, acc ->
      acc ++ [%{"functionCall" => %{"name" => call.name, "args" => call.arguments || %{}}}]
    end)
  end

  defp maybe_text(parts, nil), do: parts
  defp maybe_text(parts, ""), do: parts
  defp maybe_text(parts, text), do: parts ++ [%{"text" => text}]

  defp build_tools([]), do: []

  defp build_tools(tools) do
    Enum.map(tools, fn tool ->
      %{
        "name" => tool.name,
        "description" => tool.description,
        "parameters" => tool.parameters || %{"type" => "object", "properties" => %{}}
      }
    end)
  end

  defp tool_mode("required"), do: "ANY"
  defp tool_mode("none"), do: "NONE"
  defp tool_mode(_), do: "AUTO"

  defp do_transport(payload, %{transport: transport}) when is_function(transport, 1) do
    transport.(payload)
  end

  defp do_transport(payload, config) do
    :inets.start()
    :ssl.start()
    model = URI.encode_www_form(config.model)
    url = String.to_charlist(config.base_url <> "/v1beta/models/" <> model <> ":generateContent")
    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"x-goog-api-key", String.to_charlist(config.api_key || "")}
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
    candidate = List.first(data["candidates"] || []) || %{}
    {content, calls} = parse_parts(get_in(candidate, ["content", "parts"]) || [])
    usage = data["usageMetadata"] || %{}

    {:ok,
     %Praxo.Response{
       message: %Praxo.Message{
         role: "assistant",
         content: content,
         tool_calls: calls
       },
       usage: %Praxo.Usage{
         input_tokens: usage["promptTokenCount"] || 0,
         output_tokens: usage["candidatesTokenCount"] || 0
       }
     }}
  end

  defp parse_parts(parts) do
    Enum.reduce(parts, {"", []}, fn part, {text, calls} ->
      text = text <> (part["text"] || "")

      case part["functionCall"] do
        nil ->
          {text, calls}

        call ->
          tool = %Praxo.ToolCall{
            id: "call-#{length(calls) + 1}",
            name: call["name"] || "",
            arguments: call["args"] || %{}
          }

          {text, calls ++ [tool]}
      end
    end)
  end
end
