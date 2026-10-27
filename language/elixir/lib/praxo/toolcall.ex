defmodule Praxo.ToolCallParser do
  alias Praxo.{Json, Models}

  def parse_input_json(raw) do
    case Json.parse(String.trim(raw)) do
      {:ok, value} when is_map(value) -> {:ok, value}
      _ -> :error
    end
  end

  def parse_tool_call(content) do
    with :error <- parse_json_call(content),
         :error <- parse_xml(content),
         :error <- parse_tag(content) do
      parse_plain(content)
    end
  end

  defp parse_json_call(content) do
    case Json.parse(content) do
      {:ok, value} when is_map(value) ->
        case Json.get_string(value, "name") do
          nil -> :error
          "" -> :error
          name ->
            input = Json.get_object(value, "input")
            {:ok, Models.tool_call("", name, input)}
        end

      _ ->
        :error
    end
  end

  defp parse_xml(content) do
    pattern = ~r/<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*<\/tool_call>/s

    case Regex.scan(pattern, content, capture: :all_but_first) do
      [] ->
        :error

      matches ->
        [name, body] = List.last(matches)

        case parse_input_json(body) do
          {:ok, input} -> {:ok, Models.tool_call("", name, input)}
          :error -> :error
        end
    end
  end

  defp parse_tag(content) do
    pattern = ~r/<([A-Za-z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:<\/[A-Za-z][\w.-]*>|$)/s

    case Regex.scan(pattern, content, capture: :all_but_first) do
      [] ->
        :error

      matches ->
        [name, body] = List.last(matches)

        case parse_input_json(body) do
          {:ok, input} -> {:ok, Models.tool_call("", name, input)}
          :error -> :error
        end
    end
  end

  defp parse_plain(content) do
    pattern = ~r/^\s*([A-Za-z][\w.-]*)\s+(\{.*\})\s*$/m

    case Regex.scan(pattern, content, capture: :all_but_first) do
      [] ->
        :error

      matches ->
        case List.last(matches) do
          [name, body] ->
            if String.contains?(name, ".") do
              case parse_input_json(body) do
                {:ok, input} -> {:ok, Models.tool_call("", name, input)}
                :error -> :error
              end
            else
              :error
            end

          _ ->
            :error
        end
    end
  end

  def strip_tool_call_markup(content) do
    content = Regex.replace(~r/<tool_call\s+name="[^"]+"\s*>.*?<\/tool_call>/s, content, "")
    content = Regex.replace(~r/<tool_call_invoke>.*?<\/tool_call_invoke>/s, content, "")
    content = Regex.replace(~r/<[A-Za-z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:<\/[A-Za-z][\w.-]*>|$)/s, content, "")
    content = Regex.replace(~r/\n{3,}/, content, "\n\n")
    String.trim(content)
  end
end
