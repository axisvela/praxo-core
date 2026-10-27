defmodule Praxo.Json do
  @moduledoc "JSON helpers over the OTP 27+ `:json` module."

  def parse(text) when is_binary(text) do
    try do
      {:ok, :json.decode(text)}
    rescue
      _ -> {:error, :invalid_json}
    catch
      _, _ -> {:error, :invalid_json}
    end
  end

  def parse(_), do: {:error, :invalid_json}

  def parse!(text) do
    case parse(text) do
      {:ok, value} -> value
      {:error, _} -> raise Praxo.Error, code: "JSON_ERROR", message: "invalid JSON"
    end
  end

  def encode(value) do
    value
    |> normalize()
    |> :json.encode()
    |> IO.iodata_to_binary()
  end

  defp normalize(%{} = map) do
    Map.new(map, fn {key, item} -> {key, normalize(item)} end)
  end

  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(nil), do: :null
  defp normalize(value), do: value

  def is_null(:null), do: true
  def is_null(_), do: false

  def is_object(value), do: is_map(value)
  def is_array(value), do: is_list(value)

  def as_object(value) when is_map(value), do: value
  def as_object(_), do: %{}

  def as_array(value) when is_list(value), do: value
  def as_array(_), do: []

  def get(value, key) when is_map(value), do: Map.get(value, key)
  def get(_, _), do: nil

  def get_string(value, key) do
    case get(value, key) do
      item when is_binary(item) -> item
      _ -> nil
    end
  end

  def get_bool(value, key, fallback \\ false) do
    case get(value, key) do
      item when is_boolean(item) -> item
      _ -> fallback
    end
  end

  def get_int(value, key, fallback \\ 0) do
    case get(value, key) do
      item when is_integer(item) -> item
      item when is_float(item) ->
        if item == Float.round(item), do: trunc(item), else: fallback
      _ -> fallback
    end
  end

  def get_array(value, key) do
    case get(value, key) do
      item when is_list(item) -> item
      _ -> []
    end
  end

  def get_object(value, key) do
    case get(value, key) do
      item when is_map(item) -> item
      _ -> %{}
    end
  end

  def equals?(left, right), do: left == right

  def from_strings(values), do: values
  def from_ints(values), do: values
end
