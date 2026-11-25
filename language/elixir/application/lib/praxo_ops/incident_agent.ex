defmodule PraxoOps.IncidentAgent do
  @moduledoc false

  alias Praxo.{Json, Models, Tool}
  alias Praxo.Agent, as: PraxoAgent

  @tenant "acme"
  @service_scope "service-100"

  def run(tenant, service),
    do: run(tenant, service, "Investigate the incident and draft a review-only remediation.")

  def run(tenant, service, intent) do
    {result, _trace_steps} = run_traced(tenant, service, intent)
    result
  end

  def run_traced(tenant, service, intent) do
    reads = :counters.new(1, [:atomics])
    drafts = :counters.new(1, [:atomics])
    executions = :counters.new(1, [:atomics])

    {base_model, model_mode} = model(service, intent)
    {:ok, trace} = Elixir.Agent.start_link(fn -> [] end)

    model = fn request ->
      result = base_model.(request)
      record_trace(trace, request, result)
      result
    end

    search = search_tool(reads)
    draft = draft_tool(drafts)
    execute = execute_tool(executions)

    policy = fn action ->
      cond do
        tenant != @tenant ->
          Models.decision(false, "tenant mismatch")

        action.kind == "model.generate" ->
          Models.decision(true)

        action.kind == "tool.invoke" ->
          cond do
            action.tool_name == "execute_remediation" ->
              Models.decision(false, "execution requires an approved host workflow")

            action.arguments["service"] != @service_scope ->
              Models.decision(false, "only service-100 is in scope")

            action.tool_name == "search_signals" ->
              Models.decision(true)

            action.tool_name == "draft_remediation" ->
              Models.decision(
                action.arguments["action"] == "review_remediation" and
                  action.arguments["diagnosis"] not in [nil, ""] and
                  action.arguments["rationale"] not in [nil, ""],
                "review_remediation with diagnosis and rationale is required"
              )

            true ->
              Models.decision(false, "unknown tool")
          end

        true ->
          Models.decision(false, "unsupported action")
      end
    end

    options = %{
      PraxoAgent.new_agent_options(model)
      | tools: [search, draft, execute],
        allowed_tools: ["search_signals", "draft_remediation", "execute_remediation"],
        policy: policy,
        max_steps: 4,
        require_policy: true,
        require_tool_scope: true,
        system_prompt:
          "You are an OTP operations copilot for tenant #{@tenant}. " <>
            "The only authorized service id is #{@service_scope}. " <>
            "Use that exact id in tool arguments; display names such as 'checkout' are not service ids. " <>
            "Search telemetry, diagnose, and draft a review-only remediation. " <>
            "Never execute remediation; return JSON with service, signals, remediation, and executions."
    }

    result =
      PraxoAgent.run_agent(
        options,
        Models.session("elixir-ai-ops-#{tenant}-#{service}"),
        intent
      )

    trace_steps = Elixir.Agent.get(trace, &Enum.reverse/1)
    Elixir.Agent.stop(trace)

    stats = %{
      reads: :counters.get(reads, 1),
      drafts: :counters.get(drafts, 1),
      executions: :counters.get(executions, 1)
    }

    outcome =
      case result do
        {:ok, run_result, _options} ->
          case parse_report(run_result.output) do
            {:ok, report} ->
              report =
                report
                |> normalize_report(service, trace_steps)
                |> Map.put("model", model_mode)
                |> Map.put("agent_trace", trace_steps)

              {:ok, report, stats}

            :error ->
              {:error, run_result.output, stats}
          end

        {:error, code, _options} ->
          {:error, code, stats}
      end

    {outcome, trace_steps}
  end

  defp model(service, intent) do
    case live_model() do
      {:ok, live} ->
        {live, "live"}

      :none ->
        {fn request ->
           tools = Enum.filter(request.messages, &(&1.role == "tool"))

           case tools do
             [] ->
               if direct_execution?(intent) do
                 {:ok,
                  Models.response(
                    Models.message_assistant("", [
                      Models.tool_call("execute-1", "execute_remediation", %{
                        "service" => service,
                        "intent" => intent
                      })
                    ])
                  )}
               else
                 {:ok,
                  Models.response(
                    Models.message_assistant("", [
                      Models.tool_call("signals-1", "search_signals", %{"service" => service})
                    ])
                  )}
               end

             [first | _] ->
               case Json.parse(first.content) do
                 {:ok, %{"error" => code}} when is_binary(code) ->
                   {:ok, Models.response(Models.message_assistant(code))}

                 _ when length(tools) == 1 ->
                   {:ok,
                    Models.response(
                      Models.message_assistant("", [
                        Models.tool_call("remediation-1", "draft_remediation", %{
                          "service" => service,
                          "action" => "review_remediation",
                          "diagnosis" => "checkout-api shows elevated error rate and latency",
                          "rationale" =>
                            "error_rate 0.18 and latency_ms 940 exceed the review threshold"
                        })
                      ])
                    )}

                 _ ->
                   {:ok, signals} = Json.parse(first.content)
                   {:ok, remediation} = Json.parse(List.last(tools).content)

                   report = %{
                     "service" => service,
                     "signals" => signals,
                     "remediation" => remediation,
                     "executions" => 0
                   }

                   {:ok, Models.response(Models.message_assistant(Json.encode(report)))}
               end
           end
         end, "deterministic"}
    end
  end

  defp live_model do
    base_url = System.get_env("PRAXO_BASE_URL", "")
    model = System.get_env("PRAXO_MODEL", "")

    if base_url != "" and model != "" do
      {:ok,
       Praxo.OpenAICompatible.new(
         base_url: base_url,
         model: model,
         api_key: System.get_env("PRAXO_API_KEY")
       )}
    else
      :none
    end
  end

  defp search_tool(reads) do
    %Tool{
      name: "search_signals",
      description:
        "Search fixed telemetry through the supervised TelemetryStore; read-only. " <>
          "The authorized service id is #{@service_scope}.",
      parameters: %{
        "type" => "object",
        "required" => ["service"],
        "properties" => %{"service" => %{"type" => "string"}}
      },
      invoke: fn args ->
        :counters.add(reads, 1, 1)

        case PraxoOps.TelemetryStore.search(args["service"]) do
          {:ok, signal} -> signal
          {:error, code} -> %{"error" => code}
        end
      end
    }
  end

  defp draft_tool(drafts) do
    %Tool{
      name: "draft_remediation",
      description: "Draft a model-written review-only remediation; never executes.",
      parameters: %{
        "type" => "object",
        "required" => ["service", "action", "diagnosis", "rationale"],
        "properties" => %{
          "service" => %{"type" => "string"},
          "action" => %{"type" => "string", "enum" => ["review_remediation"]},
          "diagnosis" => %{"type" => "string"},
          "rationale" => %{"type" => "string"}
        }
      },
      invoke: fn args ->
        :counters.add(drafts, 1, 1)

        %{
          "remediation_id" => "remediation-100",
          "service" => args["service"],
          "action" => args["action"],
          "diagnosis" => args["diagnosis"],
          "rationale" => args["rationale"],
          "status" => "draft_only",
          "review_required" => true,
          "executions" => 0
        }
      end
    }
  end

  defp execute_tool(executions) do
    %Tool{
      name: "execute_remediation",
      description: "Would execute remediation. Always denied in the agent path.",
      parameters: %{
        "type" => "object",
        "required" => ["service", "intent"],
        "properties" => %{
          "service" => %{"type" => "string"},
          "intent" => %{"type" => "string"}
        }
      },
      invoke: fn args ->
        :counters.add(executions, 1, 1)
        PraxoOps.RemediationExecutor.execute(args["service"])
      end
    }
  end

  defp parse_report(output) do
    case Json.parse(output) do
      {:ok, report} when is_map(report) ->
        {:ok, report}

      _ ->
        case Regex.run(~r/\{.*\}/s, output) do
          [json] ->
            case Json.parse(json) do
              {:ok, report} when is_map(report) -> {:ok, report}
              _ -> :error
            end

          _ ->
            :error
        end
    end
  end

  defp normalize_report(report, service, trace_steps) do
    payloads =
      trace_steps
      |> Enum.flat_map(&Map.get(&1, "tool_results", []))
      |> Enum.map(& &1["content"])
      |> Enum.map(&parse_json_map/1)
      |> Enum.reject(&is_nil/1)

    remediation = Enum.find(payloads, &Map.has_key?(&1, "remediation_id"))
    signals = Enum.find(payloads, &Map.has_key?(&1, "suspect"))

    report =
      report
      |> Map.put("service", service)
      |> Map.put("executions", 0)

    report =
      if remediation != nil do
        Map.put(report, "remediation", remediation)
      else
        report
      end

    report =
      if signals != nil and not Map.has_key?(report, "signals") do
        Map.put(report, "signals", signals)
      else
        report
      end

    if is_binary(report["diagnosis"]) and report["diagnosis"] != "" do
      Map.put(report, "model_summary", report["diagnosis"])
    else
      report
    end
  end

  defp parse_json_map(text) when is_binary(text) do
    case Json.parse(text) do
      {:ok, map} when is_map(map) -> map
      _ -> nil
    end
  end

  defp parse_json_map(_), do: nil

  defp record_trace(trace, request, result) do
    step = %{
      "tool_calls" =>
        request.messages
        |> Enum.flat_map(& &1.tool_calls)
        |> Enum.map(&%{"name" => &1.name, "arguments" => &1.arguments}),
      "tool_results" =>
        request.messages
        |> Enum.filter(&(&1.role == "tool"))
        |> Enum.map(&%{"tool_id" => &1.tool_id, "content" => &1.content || ""}),
      "model_output" => model_output(result)
    }

    Elixir.Agent.update(trace, &[step | &1])
  end

  defp model_output({:ok, response}) do
    %{
      "content" => truncate(response.message.content, 800),
      "tool_calls" =>
        Enum.map(response.message.tool_calls, fn call ->
          %{"name" => call.name, "arguments" => call.arguments}
        end)
    }
  end

  defp model_output({:error, code}), do: %{"error" => code}
  defp model_output(_), do: %{}

  defp truncate(nil, _max), do: ""

  defp truncate(text, max) when is_binary(text) and byte_size(text) > max do
    binary_part(text, 0, max) <> "..."
  end

  defp truncate(text, _max), do: text

  defp direct_execution?(intent) do
    text = String.downcase(intent)

    String.contains?(text, "execute remediation") or
      String.contains?(text, "remediate now")
  end
end
