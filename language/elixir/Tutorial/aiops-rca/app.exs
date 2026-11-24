defmodule AiopsRca do
  alias Praxo.{Agent, Json, Models}

  def run_scenario(service, simulate_failure \\ false) do
    reads = :counters.new(1, [:atomics])
    drafts = :counters.new(1, [:atomics])
    model = fn request ->
      tools = Enum.filter(request.messages, &(&1.role == "tool"))
      case tools do
        [] ->
          {:ok, Models.response(Models.message_assistant("", [
            Models.tool_call("signals-1", "read_signals", %{"service" => service})
          ]))}
        [first | _] ->
          case Json.parse(first.content) do
            {:ok, %{"error" => code}} when is_binary(code) ->
              {:ok, Models.response(Models.message_assistant(code))}
            _ when length(tools) == 1 ->
              {:ok, Models.response(Models.message_assistant("", [
                Models.tool_call("rollback-1", "draft_rollback", %{
                  "service" => service, "action" => "review_rollback"
                })
              ]))}
            _ ->
              {:ok, signals} = Json.parse(first.content)
              {:ok, rollback} = Json.parse(List.last(tools).content)
              {:ok, Models.response(Models.message_assistant(Json.encode(%{
                "stage" => "rollback_drafted", "signals" => signals,
                "rollback" => rollback, "actions" => 0
              })))}
          end
      end
    end

    read = Agent.new_tool("read_signals", "Correlate fixed trace/metric/log signals; no live telemetry.", fn _ ->
      :counters.add(reads, 1, 1)
      if simulate_failure do
        %{"error" => "TELEMETRY_UNAVAILABLE"}
      else
        %{"service" => "service-100", "error_rate" => 0.18, "latency_ms" => 940,
          "suspect" => "checkout-api", "trace" => "trace-100", "source" => "signal_fixture"}
      end
    end)
    draft = Agent.new_tool("draft_rollback", "Draft a review-only rollback; never remediates.", fn args ->
      :counters.add(drafts, 1, 1)
      %{"rollback_id" => "rollback-100", "service" => args["service"],
        "action" => args["action"], "status" => "draft_only",
        "review_required" => true, "actions" => 0}
    end)

    policy = fn action ->
      case action.kind do
        "model.generate" -> Models.decision(true)
        "tool.invoke" ->
          in_scope = action.arguments["service"] == "service-100"
          cond do
            not in_scope -> Models.decision(false, "only service-100 is in scope")
            action.tool_name == "read_signals" -> Models.decision(true)
            action.tool_name == "draft_rollback" ->
              Models.decision(action.arguments["action"] == "review_rollback",
                "only review_rollback is allowed")
            true -> Models.decision(false, "unknown tool")
          end
        _ -> Models.decision(false, "unsupported action")
      end
    end

    options = %{Agent.new_agent_options(model) |
      tools: [read, draft], allowed_tools: ["read_signals", "draft_rollback"],
      policy: policy, max_steps: 4, require_policy: true, require_tool_scope: true}
    case Agent.run_agent(options, Models.session("aiops-rca"),
           "Correlate fixed signals and draft a review-only rollback.") do
      {:ok, result, _} -> {result.output, :counters.get(reads, 1), :counters.get(drafts, 1), nil}
      {:error, code, _} -> {"", :counters.get(reads, 1), :counters.get(drafts, 1), code}
    end
  end

  def test do
    {output, 1, 1, nil} = run_scenario("service-100")
    {:ok, report} = Json.parse(output)
    unless report["stage"] == "rollback_drafted" and
             report["signals"]["suspect"] == "checkout-api" and
             report["rollback"]["status"] == "draft_only" and report["actions"] == 0 do
      raise "unexpected report: #{output}"
    end
    IO.puts("success: service-100 suspect=checkout-api status=draft_only actions=0 reads=1")
    {"", 0, 0, "AGENT_POLICY_DENIED"} = run_scenario("service-200")
    IO.puts("deny: AGENT_POLICY_DENIED reads=0")
    {"TELEMETRY_UNAVAILABLE", 1, 0, nil} = run_scenario("service-100", true)
    IO.puts("failure: TELEMETRY_UNAVAILABLE reads=1")
  end
end

case System.argv() do
  ["--test"] -> AiopsRca.test()
  args ->
    service = case Enum.find_index(args, &(&1 == "--service")) do
      nil -> "service-100"
      index -> Enum.at(args, index + 1, "service-100")
    end
    {output, _reads, _drafts, error} = AiopsRca.run_scenario(service, "--simulate-failure" in args)
    if error do
      IO.puts(:stderr, "aiops rca failed: #{error}")
      System.halt(1)
    end
    IO.puts(output)
end
