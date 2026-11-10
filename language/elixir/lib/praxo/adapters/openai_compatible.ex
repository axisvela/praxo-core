defmodule Praxo.OpenAICompatible do
  @moduledoc "OpenAI-compatible chat completions adapter."

  alias Praxo.Json

  def new(opts) do
    config = %{
      base_url: String.trim_trailing(Keyword.fetch!(opts, :base_url), "/"),
      model: Keyword.fetch!(opts, :model),
      api_key: Keyword.get(opts, :api_key),
      transport: Keyword.get(opts, :transport),
      timeout: Keyword.get(opts, :timeout, 60_000)
    }

    fn request -> generate(request, config) end
  end

  def generate(%Praxo.Request{} = request, config) do
    payload = build_payload(request, config)

    case do_transport(payload, config) do
      {:ok, data} -> parse_response(data)
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_payload(request, config) do
    payload = %{
      "model" => config.model,
      "messages" => Enum.map(request.messages, &message_payload/1)
    }

    tools =
      Enum.map(request.tools, fn tool ->
        %{
          "type" => "function",
          "function" => %{
            "name" => tool.name,
            "description" => tool.description,
            "parameters" => %{"type" => "object"}
          }
        }
      end)

    payload = if tools == [], do: payload, else: Map.put(payload, "tools", tools)
    if request.tool_choice != nil, do: Map.put(payload, "tool_choice", request.tool_choice), else: payload
  end

  defp message_payload(%Praxo.Message{} = message) do
    content = content(message)
    out = %{"role" => message.role, "content" => content}

    out =
      if message.role == "assistant" and message.tool_calls != [] do
        calls =
          Enum.map(message.tool_calls, fn call ->
            %{
              "id" => call.id,
              "type" => "function",
              "function" => %{
                "name" => call.name,
                "arguments" => Json.encode(call.arguments || %{})
              }
            }
          end)

        Map.put(out, "tool_calls", calls)
      else
        out
      end

    if message.role == "tool" and message.tool_id != nil do
      Map.put(out, "tool_call_id", message.tool_id)
    else
      out
    end
  end

  defp content(%Praxo.Message{content: content, content_blocks: blocks}) do
    cond do
      is_binary(content) and content != "" ->
        content

      blocks != [] ->
        blocks
        |> Enum.filter(&(&1.kind == "text" and is_binary(&1.text)))
        |> Enum.map_join("", & &1.text)

      true ->
        ""
    end
  end

  defp do_transport(payload, %{transport: transport}) when is_function(transport, 1) do
    transport.(payload)
  end

  defp do_transport(payload, config) do
    :inets.start()
    :ssl.start()
    url = String.to_charlist(config.base_url <> "/chat/completions")
    headers = [{~c"content-type", ~c"application/json"}] ++ auth_header(config.api_key)
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

  defp auth_header(nil), do: []
  defp auth_header(key), do: [{~c"authorization", String.to_charlist("Bearer " <> key)}]

  defp parse_response(data) do
    choice = List.first(data["choices"] || []) || %{}
    message = choice["message"] || %{}

    tool_calls =
      Enum.map(message["tool_calls"] || [], fn call ->
        function = call["function"] || %{}

        arguments =
          case function["arguments"] do
            text when is_binary(text) and text != "" -> Json.parse!(text)
            value -> value || %{}
          end

        %Praxo.ToolCall{
          id: call["id"] || "",
          name: function["name"] || "",
          arguments: arguments
        }
      end)

    usage = data["usage"] || %{}

    {:ok,
     %Praxo.Response{
       message: %Praxo.Message{
         role: "assistant",
         content: message["content"],
         tool_calls: tool_calls
       },
       usage: %Praxo.Usage{
         input_tokens: usage["prompt_tokens"] || 0,
         output_tokens: usage["completion_tokens"] || 0
       }
     }}
  end
end
