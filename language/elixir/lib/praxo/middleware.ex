defmodule Praxo.StructuredOutput do
  defstruct schema: %{}, max_repairs: 0, repairer: nil
end

defmodule Praxo.CallLimit do
  defstruct model_limit: 0, tool_limit: 0, models: 0, tools: 0
end

defmodule Praxo.ToolSelection do
  defstruct selected: MapSet.new()
end

defmodule Praxo.Middleware do
  alias Praxo.{CallLimit, Json, JsonSchema, StructuredOutput, ToolSelection, ToolSpec}

  @email ~r/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/
  @ssn ~r/\b\d{3}-\d{2}-\d{4}\b/
  @card ~r/\b(?:\d{4}[ -]?){3}\d{4}\b/

  def pii_redact(text) do
    text
    |> then(&Regex.replace(@email, &1, "[REDACTED:email]"))
    |> then(&Regex.replace(@ssn, &1, "[REDACTED:ssn]"))
    |> then(&Regex.replace(@card, &1, "[REDACTED:credit_card]"))
  end

  def redact_value(value) when is_binary(value), do: pii_redact(value)

  def redact_value(value) when is_list(value) do
    Enum.map(value, &redact_value/1)
  end

  def redact_value(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {key, redact_value(item)} end)
  end

  def redact_value(value), do: value

  def extract_json(text) do
    value = String.trim(text)

    value =
      if String.starts_with?(value, "```") do
        value
        |> String.replace(~r/^```[^\n]*\n/, "")
        |> String.replace(~r/```\s*$/, "")
        |> String.trim()
      else
        value
      end

    case Regex.run(~r/[\{\[]/, value, return: :index) do
      [{start, _}] ->
        try do
          Json.parse(binary_part(value, start, byte_size(value) - start))
        rescue
          _ -> {:error, :invalid_json}
        end

      _ ->
        {:error, :no_json}
    end
  end

  def structured_output(schema, max_repairs, repairer \\ nil) do
    %StructuredOutput{schema: schema, max_repairs: max_repairs, repairer: repairer}
  end

  def apply_structured(%StructuredOutput{} = config, text) do
    do_apply(config, text, 0)
  end

  defp do_apply(config, output, attempt) do
    valid =
      case extract_json(output) do
        {:ok, value} -> JsonSchema.validate(config.schema, value) == []
        _ -> false
      end

    cond do
      valid ->
        {:ok, output}

      attempt >= config.max_repairs ->
        {:error, "AGENT_STRUCTURED_OUTPUT"}

      config.repairer == nil ->
        {:error, "AGENT_STRUCTURED_OUTPUT"}

      true ->
        result = try do
          {:ok, config.repairer.(output)}
        rescue
          error -> {:error, error}
        end

        case result do
          {:error, error} -> {:error, error}
          {:ok, repaired} when is_binary(repaired) ->
            if String.trim(repaired) == "", do: {:error, "AGENT_STRUCTURED_OUTPUT"}, else: do_apply(config, repaired, attempt + 1)
          {:ok, _} -> {:error, "AGENT_STRUCTURED_OUTPUT"}
        end
    end
  end

  def call_limit(model_limit, tool_limit) do
    %CallLimit{model_limit: model_limit, tool_limit: tool_limit}
  end

  def model_call(%CallLimit{} = limit) do
    limit = %{limit | models: limit.models + 1}

    if limit.model_limit > 0 and limit.models > limit.model_limit do
      {:error, "AGENT_MODEL_CALL_LIMIT", limit}
    else
      {:ok, limit}
    end
  end

  def tool_call(%CallLimit{} = limit) do
    limit = %{limit | tools: limit.tools + 1}

    if limit.tool_limit > 0 and limit.tools > limit.tool_limit do
      {:error, "AGENT_TOOL_CALL_LIMIT", limit}
    else
      {:ok, limit}
    end
  end

  def tool_selection(selected) do
    %ToolSelection{selected: MapSet.new(selected)}
  end

  def select_tools(%ToolSelection{selected: selected}, tools) do
    Enum.filter(tools, fn %ToolSpec{name: name} -> MapSet.member?(selected, name) end)
  end

  def check_tool_selected(%ToolSelection{selected: selected}, name) do
    if MapSet.member?(selected, name) do
      :ok
    else
      {:error, "AGENT_TOOL_NOT_SELECTED"}
    end
  end
end
