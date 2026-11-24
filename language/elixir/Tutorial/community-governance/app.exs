defmodule CommunityGovernance do
  alias Praxo.{Agent, Json, Models}

  def run_scenario(repo, simulate_failure \\ false) do
    reads = :counters.new(1, [:atomics])
    drafts = :counters.new(1, [:atomics])
    model = fn request ->
      tools = Enum.filter(request.messages, &(&1.role == "tool"))
      case tools do
        [] ->
          {:ok, Models.response(Models.message_assistant("", [
            Models.tool_call("issues-1", "read_issues", %{"repo" => repo})
          ]))}
        [first | _] ->
          case Json.parse(first.content) do
            {:ok, %{"error" => code}} when is_binary(code) ->
              {:ok, Models.response(Models.message_assistant(code))}
            _ when length(tools) == 1 ->
              {:ok, Models.response(Models.message_assistant("", [
                Models.tool_call("guidance-1", "draft_guidance", %{
                  "repo" => repo, "action" => "draft_reviewer_request"
                })
              ]))}
            _ ->
              {:ok, issues} = Json.parse(first.content)
              {:ok, guidance} = Json.parse(List.last(tools).content)
              {:ok, Models.response(Models.message_assistant(Json.encode(%{
                "stage" => "governance_drafted", "issues" => issues,
                "guidance" => guidance, "closures" => 0, "impersonations" => 0
              })))}
          end
      end
    end

    read = Agent.new_tool("read_issues", "Classify fixed synthetic issues; no GitHub API.", fn _ ->
      :counters.add(reads, 1, 1)
      if simulate_failure do
        %{"error" => "ISSUE_INDEX_UNAVAILABLE"}
      else
        %{"repo" => "repo-100", "issues" => 4,
          "categories" => %{"bug" => 2, "docs" => 1, "question" => 1},
          "unlabeled" => 1, "source" => "issue_fixture"}
      end
    end)
    draft = Agent.new_tool("draft_guidance", "Draft review-only reviewer guidance; no closures.", fn args ->
      :counters.add(drafts, 1, 1)
      %{"guidance_id" => "guidance-100", "repo" => args["repo"],
        "action" => args["action"], "requests" => 1, "status" => "draft_only",
        "review_required" => true, "closures" => 0, "impersonations" => 0}
    end)

    policy = fn action ->
      case action.kind do
        "model.generate" -> Models.decision(true)
        "tool.invoke" ->
          in_scope = action.arguments["repo"] == "repo-100"
          cond do
            not in_scope -> Models.decision(false, "only repo-100 is in scope")
            action.tool_name == "read_issues" -> Models.decision(true)
            action.tool_name == "draft_guidance" ->
              Models.decision(action.arguments["action"] == "draft_reviewer_request",
                "only a reviewer request draft is allowed")
            true -> Models.decision(false, "unknown tool")
          end
        _ -> Models.decision(false, "unsupported action")
      end
    end

    options = %{Agent.new_agent_options(model) |
      tools: [read, draft], allowed_tools: ["read_issues", "draft_guidance"],
      policy: policy, max_steps: 4, require_policy: true, require_tool_scope: true}
    case Agent.run_agent(options, Models.session("community-governance"),
           "Classify fixed issues and draft review-only reviewer guidance.") do
      {:ok, result, _} -> {result.output, :counters.get(reads, 1), :counters.get(drafts, 1), nil}
      {:error, code, _} -> {"", :counters.get(reads, 1), :counters.get(drafts, 1), code}
    end
  end

  def test do
    {output, 1, 1, nil} = run_scenario("repo-100")
    {:ok, report} = Json.parse(output)
    unless report["issues"]["issues"] == 4 and report["issues"]["unlabeled"] == 1 and
             report["guidance"]["status"] == "draft_only" and
             report["guidance"]["requests"] == 1 and
             report["closures"] == 0 and report["impersonations"] == 0 do
      raise "unexpected report: #{output}"
    end
    IO.puts("success: repo-100 issues=4 unlabeled=1 status=draft_only closures=0 reads=1")
    {"", 0, 0, "AGENT_POLICY_DENIED"} = run_scenario("repo-200")
    IO.puts("deny: AGENT_POLICY_DENIED reads=0")
    {"ISSUE_INDEX_UNAVAILABLE", 1, 0, nil} = run_scenario("repo-100", true)
    IO.puts("failure: ISSUE_INDEX_UNAVAILABLE reads=1")
  end
end

case System.argv() do
  ["--test"] -> CommunityGovernance.test()
  args ->
    repo = case Enum.find_index(args, &(&1 == "--repo")) do
      nil -> "repo-100"
      index -> Enum.at(args, index + 1, "repo-100")
    end
    {output, _reads, _drafts, error} =
      CommunityGovernance.run_scenario(repo, "--simulate-failure" in args)
    if error do
      IO.puts(:stderr, "community governance failed: #{error}")
      System.halt(1)
    end
    IO.puts(output)
end
