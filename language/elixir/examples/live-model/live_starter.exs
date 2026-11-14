defmodule LiveModel do
  alias Praxo.{Agent, Models}

  defp env_or(name, fallback) do
    case System.get_env(name) do
      nil -> fallback
      "" -> fallback
      value -> value
    end
  end

  defp get_time(_arguments) do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  def run do
    base_url = env_or("PRAXO_BASE_URL", "http://localhost:11434/v1")
    model_name = env_or("PRAXO_MODEL", "qwen3.5:4b")

    prompt =
      env_or(
        "PRAXO_PROMPT",
        "What time is it? Use get_time with zone set to utc and reply with the time."
      )

    model =
      Praxo.OpenAICompatible.new(
        base_url: base_url,
        model: model_name,
        api_key: System.get_env("PRAXO_API_KEY")
      )

    tool = %{
      Agent.new_tool("get_time", "Return the current time in ISO 8601 format for the requested zone.", &get_time/1)
      | parameters: %{
          "type" => "object",
          "properties" => %{
            "zone" => %{
              "type" => "string",
              "enum" => ["utc", "local"],
              "description" => "utc or local; defaults to utc"
            }
          }
        }
    }

    policy = fn action ->
      case action.kind do
        "model.generate" ->
          Models.decision(true, "model generation")

        "tool.invoke" ->
          Models.decision(
            action.tool_name == "get_time",
            "only get_time is permitted"
          )

        _ ->
          Models.decision(false, "unsupported action")
      end
    end

    options = %{
      Agent.new_agent_options(model)
      | tools: [tool],
        system_prompt: "You are a concise assistant. Use the provided tools when they help.",
        max_steps: 4,
        allowed_tools: ["get_time"],
        policy: policy
    }

    case Agent.run_agent(options, Models.session("live-model"), prompt) do
      {:ok, result, _} ->
        IO.puts(result.output)

      {:error, code, reason} ->
        IO.puts(:stderr, "live model run failed: #{code} #{inspect(reason)}\n\n" <>
          "Check PRAXO_BASE_URL (#{base_url}), PRAXO_MODEL (#{model_name}), and PRAXO_API_KEY")

        System.halt(1)
    end
  end
end

LiveModel.run()
