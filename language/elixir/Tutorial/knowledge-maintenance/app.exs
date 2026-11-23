defmodule KnowledgeMaintenance do
  alias Praxo.{Agent, Json, Models}

  def run_scenario(workspace, simulate_failure \\ false) do
    reads = :counters.new(1, [:atomics])
    drafts = :counters.new(1, [:atomics])

    model = fn request ->
      tools = Enum.filter(request.messages, &(&1.role == "tool"))

      case tools do
        [] ->
          call = Models.tool_call("diff-1", "diff_knowledge", %{"workspace" => workspace})
          {:ok, Models.response(Models.message_assistant("", [call]))}

        [first | _] ->
          case Json.parse(first.content) do
            {:ok, %{"error" => code}} when is_binary(code) ->
              {:ok, Models.response(Models.message_assistant(code))}

            _ when length(tools) == 1 ->
              call =
                Models.tool_call("revision-1", "draft_revision", %{
                  "workspace" => workspace,
                  "action" => "propose_revision"
                })

              {:ok, Models.response(Models.message_assistant("", [call]))}

            _ ->
              last = List.last(tools)
              {:ok, change} = Json.parse(first.content)
              {:ok, revision} = Json.parse(last.content)

              report = %{
                "stage" => "revision_drafted",
                "change" => change,
                "revision" => revision,
                "wiki_writes" => 0
              }

              {:ok, Models.response(Models.message_assistant(Json.encode(report)))}
          end
      end
    end

    diff_tool =
      Agent.new_tool("diff_knowledge", "Diff fixed knowledge versions; no arbitrary files.", fn _arguments ->
        :counters.add(reads, 1, 1)

        if simulate_failure do
          %{"error" => "KNOWLEDGE_INDEX_UNAVAILABLE"}
        else
          %{
            "workspace" => "workspace-100",
            "changed_sections" => ["retention", "contact"],
            "duplicates_removed" => 1,
            "source" => "knowledge_fixture"
          }
        end
      end)

    draft_tool =
      Agent.new_tool("draft_revision", "Draft a review-only Wiki revision; never writes.", fn arguments ->
        :counters.add(drafts, 1, 1)

        %{
          "revision_id" => "revision-100",
          "workspace" => arguments["workspace"],
          "action" => arguments["action"],
          "status" => "draft_only",
          "review_required" => true,
          "wiki_writes" => 0
        }
      end)

    policy = fn action ->
      case action.kind do
        "model.generate" ->
          Models.decision(true)

        "tool.invoke" ->
          in_scope = action.arguments["workspace"] == "workspace-100"

          cond do
            not in_scope ->
              Models.decision(false, "only workspace-100 is in maintenance scope")

            action.tool_name == "diff_knowledge" ->
              Models.decision(true)

            action.tool_name == "draft_revision" ->
              Models.decision(
                action.arguments["action"] == "propose_revision",
                "only a propose_revision draft is allowed"
              )

            true ->
              Models.decision(false, "unknown tool")
          end

        _ ->
          Models.decision(false, "unsupported action")
      end
    end

    options = %{
      Agent.new_agent_options(model)
      | tools: [diff_tool, draft_tool],
        allowed_tools: ["diff_knowledge", "draft_revision"],
        policy: policy,
        max_steps: 4,
        require_policy: true,
        require_tool_scope: true
    }

    case Agent.run_agent(options, Models.session("knowledge-maintenance"),
           "Diff the fixed knowledge base and draft a review-only revision.") do
      {:ok, result, _} ->
        {result.output, :counters.get(reads, 1), :counters.get(drafts, 1), nil}

      {:error, code, _} ->
        {"", :counters.get(reads, 1), :counters.get(drafts, 1), code}
    end
  end

  def test do
    success = run_scenario("workspace-100")
    {output, 1, 1, nil} = success
    {:ok, report} = Json.parse(output)
    change = report["change"]
    revision = report["revision"]

    unless report["stage"] == "revision_drafted" and
             change["changed_sections"] == ["retention", "contact"] and
             change["duplicates_removed"] == 1 and
             revision["status"] == "draft_only" and
             report["wiki_writes"] == 0 do
      raise "unexpected report: #{output}"
    end

    IO.puts("success: workspace-100 changed=2 status=draft_only wiki_writes=0 reads=1")

    {"", 0, 0, denied_code} = run_scenario("workspace-200")

    unless denied_code == "AGENT_POLICY_DENIED" do
      raise "deny verification failed: #{inspect(denied_code)}"
    end

    IO.puts("deny: AGENT_POLICY_DENIED reads=0")

    failure = run_scenario("workspace-100", true)
    {"KNOWLEDGE_INDEX_UNAVAILABLE", 1, 0, nil} = failure
    IO.puts("failure: KNOWLEDGE_INDEX_UNAVAILABLE reads=1")
  end
end

case System.argv() do
  ["--test"] ->
    KnowledgeMaintenance.test()

  args ->
    workspace =
      case Enum.find_index(args, &(&1 == "--workspace")) do
        nil -> "workspace-100"
        index -> Enum.at(args, index + 1, "workspace-100")
      end

    simulate_failure = "--simulate-failure" in args
    {output, _reads, _drafts, error} = KnowledgeMaintenance.run_scenario(workspace, simulate_failure)

    cond do
      error != nil ->
        IO.puts(:stderr, "knowledge maintenance failed: #{error}")
        System.halt(1)

      output == "KNOWLEDGE_INDEX_UNAVAILABLE" ->
        IO.puts(output)
        System.halt(1)

      true ->
        IO.puts(output)
    end
end
