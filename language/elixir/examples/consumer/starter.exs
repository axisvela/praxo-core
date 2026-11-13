defmodule ConsumerStarter do
  alias Praxo.{Agent, Models}

  def run_scenario(target) do
    counter = :counters.new(1, [:atomics])

    model = fn request ->
      last = List.last(request.messages)

      if last.role == "tool" do
        {:ok, Models.response(Models.message_assistant("recorded"))}
      else
        call = Models.tool_call("record-1", "record", %{"target" => target})
        {:ok, Models.response(Models.message_assistant("", [call]))}
      end
    end

    tool =
      Agent.new_tool("record", "Record a target in an in-memory counter.", fn _arguments ->
        :counters.add(counter, 1, 1)
        "recorded"
      end)

    policy = fn action ->
      case action.kind do
        "model.generate" ->
          Models.decision(true, "model generation")

        "tool.invoke" ->
          Models.decision(
            action.tool_name == "record" and action.arguments["target"] == "public",
            "only the public target is permitted"
          )

        _ ->
          Models.decision(false, "unsupported action")
      end
    end

    options = %{Agent.new_agent_options(model) |
      tools: [tool],
      allowed_tools: ["record"],
      policy: policy}

    case Agent.run_agent(options, Models.session("consumer-#{target}"), "Record the requested target.") do
      {:ok, result, _} -> {result.output, :counters.get(counter, 1), nil}
      {:error, code, _} -> {"", :counters.get(counter, 1), code}
    end
  end

  def run do
    {"recorded", 1, nil} = run_scenario("public")
    IO.puts("allow: recorded; effects=1")

    {"", 0, code} = run_scenario("private")
    if code != "AGENT_POLICY_DENIED" do
      raise "deny verification failed: code=#{inspect(code)}"
    end

    IO.puts("deny: policy rejected; effects=0")
  end
end
