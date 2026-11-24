defmodule SocCorrelation do
  alias Praxo.{Agent, Json, Models}

  def run_scenario(service, clean \\ false, simulate_failure \\ false) do
    reads = :counters.new(1, [:atomics])
    drafts = :counters.new(1, [:atomics])
    model = fn request ->
      tools = Enum.filter(request.messages, &(&1.role == "tool"))
      case tools do
        [] ->
          {:ok, Models.response(Models.message_assistant("", [
            Models.tool_call("events-1", "read_events", %{"service" => service})
          ]))}
        [first | _] ->
          case Json.parse(first.content) do
            {:ok, %{"error" => code}} when is_binary(code) ->
              {:ok, Models.response(Models.message_assistant(code))}
            {:ok, evidence} when length(tools) == 1 ->
              action = if evidence["critical"] > 0, do: "review_isolation", else: "review_monitor"
              {:ok, Models.response(Models.message_assistant("", [
                Models.tool_call("review-1", "draft_review",
                  %{"service" => service, "action" => action})
              ]))}
            _ ->
              {:ok, evidence} = Json.parse(first.content)
              {:ok, review} = Json.parse(List.last(tools).content)
              {:ok, Models.response(Models.message_assistant(Json.encode(%{
                "stage" => "soc_review_drafted", "events" => evidence,
                "review" => review, "host_blocks" => 0
              })))}
          end
      end
    end

    read = Agent.new_tool("read_events", "Correlate fixed EDR/firewall events; no blocking.", fn _ ->
      :counters.add(reads, 1, 1)
      cond do
        simulate_failure -> %{"error" => "EVENTS_UNAVAILABLE"}
        clean -> %{"service" => "service-100", "critical" => 0, "suspect" => "edge-2",
                   "events" => [%{"severity" => "low", "host" => "edge-2"}], "source" => "event_fixture"}
        true -> %{"service" => "service-100", "critical" => 1, "suspect" => "edge-1",
                  "events" => [%{"severity" => "critical", "host" => "edge-1"},
                               %{"severity" => "high", "host" => "edge-1"}],
                  "source" => "event_fixture"}
      end
    end)
    draft = Agent.new_tool("draft_review", "Draft a review-only action; never blocks a host.", fn args ->
      :counters.add(drafts, 1, 1)
      %{"review_id" => "soc-review-100", "service" => args["service"],
        "action" => args["action"], "status" => "draft_only",
        "review_required" => true, "host_blocks" => 0}
    end)

    policy = fn action ->
      case action.kind do
        "model.generate" -> Models.decision(true)
        "tool.invoke" ->
          in_scope = action.arguments["service"] == "service-100"
          cond do
            not in_scope -> Models.decision(false, "only service-100 is in scope")
            action.tool_name == "read_events" -> Models.decision(true)
            action.tool_name == "draft_review" ->
              allowed = action.arguments["action"] in ["review_isolation", "review_monitor"]
              Models.decision(allowed, "only review-only actions are allowed")
            true -> Models.decision(false, "unknown tool")
          end
        _ -> Models.decision(false, "unsupported action")
      end
    end

    options = %{Agent.new_agent_options(model) |
      tools: [read, draft], allowed_tools: ["read_events", "draft_review"],
      policy: policy, max_steps: 4, require_policy: true, require_tool_scope: true}
    case Agent.run_agent(options, Models.session("soc-correlation"),
           "Correlate fixed events and draft a review-only action.") do
      {:ok, result, _} -> {result.output, :counters.get(reads, 1), :counters.get(drafts, 1), nil}
      {:error, code, _} -> {"", :counters.get(reads, 1), :counters.get(drafts, 1), code}
    end
  end

  def test do
    {output, 1, 1, nil} = run_scenario("service-100")
    {:ok, report} = Json.parse(output)
    unless report["events"]["critical"] == 1 and
             report["review"]["action"] == "review_isolation" and
             report["host_blocks"] == 0 do
      raise "unexpected report: #{output}"
    end
    IO.puts("success: service-100 critical=1 action=review_isolation status=draft_only reads=1")
    {clean, 1, 1, nil} = run_scenario("service-100", true)
    {:ok, clean_report} = Json.parse(clean)
    unless clean_report["events"]["critical"] == 0 and
             clean_report["review"]["action"] == "review_monitor" do
      raise "clean branch failed"
    end
    IO.puts("success: clean critical=0 action=review_monitor reads=1")
    {"", 0, 0, "AGENT_POLICY_DENIED"} = run_scenario("service-200")
    IO.puts("deny: AGENT_POLICY_DENIED reads=0")
    {"EVENTS_UNAVAILABLE", 1, 0, nil} = run_scenario("service-100", false, true)
    IO.puts("failure: EVENTS_UNAVAILABLE reads=1")
  end
end

case System.argv() do
  ["--test"] -> SocCorrelation.test()
  args ->
    service = case Enum.find_index(args, &(&1 == "--service")) do
      nil -> "service-100"
      index -> Enum.at(args, index + 1, "service-100")
    end
    {output, _reads, _drafts, error} =
      SocCorrelation.run_scenario(service, "--clean" in args, "--simulate-failure" in args)
    if error do
      IO.puts(:stderr, "soc correlation failed: #{error}")
      System.halt(1)
    end
    IO.puts(output)
end
