defmodule Praxo.ValidationError do
  defstruct path: "$", message: ""
end

defmodule Praxo.JsonSchema do
  alias Praxo.{Json, ValidationError}

  def validate(schema, data) do
    visit(schema, data, "$", [])
  end

  defp visit(schema, data, path, errors) when is_map(schema) do
    kind = Json.get_string(schema, "type") || ""

    cond do
      Json.is_null(data) ->
        if kind == "", do: errors, else: add(errors, path, "expected #{kind}, got null")

      kind == "object" ->
        visit_object(schema, data, path, errors)

      kind == "array" ->
        visit_array(schema, data, path, errors)

      kind == "string" ->
        visit_string(schema, data, path, errors)

      kind == "number" or kind == "integer" ->
        visit_number(schema, kind, data, path, errors)

      kind == "boolean" ->
        visit_boolean(schema, data, path, errors)

      true ->
        errors
    end
  end

  defp visit(_, _, _, errors), do: errors

  defp visit_object(schema, data, path, errors) do
    if not is_map(data) do
      add(errors, path, "expected object")
    else
      errors =
        Enum.reduce(Json.get_array(schema, "required"), errors, fn name, acc ->
          if is_binary(name) and not Map.has_key?(data, name) do
            add(acc, path <> "." <> name, "required field missing")
          else
            acc
          end
        end)

      properties = Json.get_object(schema, "properties")

      Enum.reduce(properties, errors, fn {name, child}, acc ->
        if Map.has_key?(data, name) and is_map(child) do
          visit(child, Map.get(data, name), path <> "." <> name, acc)
        else
          acc
        end
      end)
    end
  end

  defp visit_array(schema, data, path, errors) do
    if not is_list(data) do
      add(errors, path, "expected array")
    else
      items = Json.get(schema, "items")

      if is_map(items) do
        data
        |> Enum.with_index()
        |> Enum.reduce(errors, fn {value, index}, acc ->
          visit(items, value, path <> "[#{index}]", acc)
        end)
      else
        errors
      end
    end
  end

  defp visit_string(schema, data, path, errors) do
    if not is_binary(data) do
      add(errors, path, "expected string")
    else
      length = data |> String.codepoints() |> length()
      minimum = Json.get_int(schema, "minLength", 0)
      maximum = Json.get_int(schema, "maxLength", 0)

      errors =
        if minimum > 0 and length < minimum do
          add(errors, path, "min length #{minimum}, got #{length}")
        else
          errors
        end

      errors =
        if maximum > 0 and length > maximum do
          add(errors, path, "max length #{maximum}, got #{length}")
        else
          errors
        end

      errors =
        case Json.get_string(schema, "pattern") do
          nil ->
            errors

          pattern ->
            case Regex.compile(pattern) do
              {:ok, expression} ->
                if Regex.match?(expression, data) do
                  errors
                else
                  add(errors, path, "pattern '#{pattern}' not matched")
                end

              {:error, _} ->
                add(errors, path, "invalid pattern '#{pattern}'")
            end
        end

      check_enum(schema, data, path, errors)
    end
  end

  defp visit_number(schema, kind, data, path, errors) do
    if not (is_integer(data) or is_float(data)) do
      add(errors, path, "expected number")
    else
      if kind == "integer" and is_float(data) and data != Float.round(data) do
        add(errors, path, "expected integer, got #{data}")
      else
        errors = check_enum(schema, data, path, errors)

        errors =
          case Json.get(schema, "minimum") do
            minimum when is_integer(minimum) or is_float(minimum) ->
              if minimum != 0 and data < minimum do
                add(errors, path, "value below minimum")
              else
                errors
              end

            _ ->
              errors
          end

        case Json.get(schema, "maximum") do
          maximum when is_integer(maximum) or is_float(maximum) ->
            if maximum != 0 and data > maximum do
              add(errors, path, "value above maximum")
            else
              errors
            end

          _ ->
            errors
        end
      end
    end
  end

  defp visit_boolean(schema, data, path, errors) do
    if not is_boolean(data) do
      add(errors, path, "expected boolean")
    else
      check_enum(schema, data, path, errors)
    end
  end

  defp check_enum(schema, data, path, errors) do
    values = Json.get_array(schema, "enum")

    cond do
      values == [] ->
        errors

      Enum.any?(values, &Json.equals?(&1, data)) ->
        errors

      true ->
        add(errors, path, "value not in enum")
    end
  end

  defp add(errors, path, message), do: errors ++ [%ValidationError{path: path, message: message}]
end
