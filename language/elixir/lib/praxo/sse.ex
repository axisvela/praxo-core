defmodule Praxo.SSE do
  alias Praxo.Json

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
