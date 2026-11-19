defmodule Praxo.SSE do
  alias Praxo.{Json, Message, Response, ToolCall, Usage}

  def parse_response(text, on_delta) do
    initial = %{
      content: "",
      calls: %{},
      input: 0,
      output: 0,
      finish: nil,
      done: false
    }

    result =
      text
      |> String.split("\n")
      |> Enum.reduce_while({:ok, initial}, fn raw, {:ok, state} ->
        line = String.trim(raw)

        if String.starts_with?(line, "data:") do
          chunk = line |> String.slice(5, String.length(line) - 5) |> String.trim()

          cond do
            chunk == "" ->
              {:cont, {:ok, state}}

            chunk == "[DONE]" ->
              {:halt, {:ok, %{state | done: true}}}

            true ->
              case Json.parse(chunk) do
                {:error, _} ->
                  {:halt, {:error, "MODEL_STREAM"}}

                {:ok, event} ->
                  case collect_response(event, state, on_delta) do
                    {:ok, next} ->
                      if next.done do
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
        if state.done or state.finish != nil do
          build_response(state)
        else
          {:error, "MODEL_STREAM"}
        end

      _ ->
        {:error, "MODEL_STREAM"}
    end
  end

  defp collect_response(event, state, on_delta) when is_map(event) do
    state =
      case Map.get(event, "usage") do
        usage when is_map(usage) ->
          %{
            state
            | input: Map.get(usage, "prompt_tokens", 0),
              output: Map.get(usage, "completion_tokens", 0)
          }

        _ ->
          state
      end

    choices = Map.get(event, "choices", [])

    Enum.reduce_while(choices, {:ok, state}, fn choice, {:ok, acc} ->
      delta = if is_map(choice), do: Map.get(choice, "delta", %{}), else: %{}
      text = if is_map(delta), do: Map.get(delta, "content"), else: nil

      case append_delta(acc, text, on_delta) do
        {:ok, acc} ->
          acc = append_tool_calls(acc, delta)
          finish = if is_map(choice), do: Map.get(choice, "finish_reason"), else: nil

          acc =
            if is_map(choice) and finish != nil do
              %{acc | finish: finish, done: true}
            else
              acc
            end

          {:cont, {:ok, acc}}

        {:error, code} ->
          {:halt, {:error, code}}
      end
    end)
  end

  defp collect_response(_event, state, _on_delta), do: {:ok, state}

  defp append_delta(state, text, on_delta) when is_binary(text) and text != "" do
    case on_delta.(text) do
      {:error, code} -> {:error, code}
      _ -> {:ok, %{state | content: state.content <> text}}
    end
  end

  defp append_delta(state, _text, _on_delta), do: {:ok, state}

  defp append_tool_calls(state, delta) when is_map(delta) do
    delta
    |> Map.get("tool_calls", [])
    |> Enum.reduce(state, fn item, acc ->
      index = if is_map(item), do: Map.get(item, "index", map_size(acc.calls)), else: 0
      entry = Map.get(acc.calls, index, %{id: "", name: "", arguments: ""})
      id = if is_map(item) and is_binary(Map.get(item, "id")), do: Map.get(item, "id"), else: ""
      function = if is_map(item) and is_map(Map.get(item, "function")), do: Map.get(item, "function"), else: %{}
      name = if is_binary(Map.get(function, "name")), do: Map.get(function, "name"), else: ""
      arguments = if is_binary(Map.get(function, "arguments")), do: Map.get(function, "arguments"), else: ""

      entry = %{
        id: entry.id <> id,
        name: entry.name <> name,
        arguments: entry.arguments <> arguments
      }

      %{acc | calls: Map.put(acc.calls, index, entry)}
    end)
  end

  defp append_tool_calls(state, _delta), do: state

  defp build_response(state) do
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
            call = %ToolCall{id: call.id, name: call.name, arguments: value}
            {:cont, {:ok, acc ++ [call]}}

          {:error, code} ->
            {:halt, {:error, code}}
        end
      end)

    case calls do
      {:ok, calls} ->
        {:ok,
         %Response{
           message: %Message{role: "assistant", content: state.content, tool_calls: calls},
           usage: %Usage{input_tokens: state.input, output_tokens: state.output}
         }}

      {:error, code} ->
        {:error, code}
    end
  end

  def parse(text) do
    result =
      text
      |> String.split("\n")
      |> Enum.reduce_while({:ok, "", false}, fn raw, {:ok, content, done} ->
        line = String.trim(raw)

        if String.starts_with?(line, "data:") do
          chunk = line |> String.slice(5, String.length(line) - 5) |> String.trim()

          cond do
            chunk == "" ->
              {:cont, {:ok, content, done}}

            chunk == "[DONE]" ->
              {:halt, {:ok, content, true}}

            true ->
              case Json.parse(chunk) do
                {:error, _} ->
                  {:halt, {:error, "MODEL_STREAM"}}

                {:ok, event} ->
                  {content, done} = collect(event, content, done)

                  if done do
                    {:halt, {:ok, content, true}}
                  else
                    {:cont, {:ok, content, false}}
                  end
              end
          end
        else
          {:cont, {:ok, content, done}}
        end
      end)

    case result do
      {:ok, content, true} -> {:ok, content}
      _ -> {:error, "MODEL_STREAM"}
    end
  end

  defp collect(event, content, done) when is_map(event) do
    choices = Map.get(event, "choices", [])

    Enum.reduce(choices, {content, done}, fn choice, {acc, done} ->
      delta = if is_map(choice), do: Map.get(choice, "delta", %{}), else: %{}
      text = if is_map(delta), do: Map.get(delta, "content"), else: nil
      acc = if is_binary(text), do: acc <> text, else: acc
      finish = if is_map(choice), do: Map.get(choice, "finish_reason"), else: nil

      done =
        done or
          (is_map(choice) and Map.has_key?(choice, "finish_reason") and finish != nil)

      {acc, done}
    end)
  end

  defp collect(_event, content, done), do: {content, done}
end
