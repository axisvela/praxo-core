defmodule Praxo.Conformance do
  alias Praxo.{
    Agent,
    CheckpointAllowlist,
    Json,
    JsonSchema,
    MemoryStore,
    Middleware,
    Models,
    Plugin,
    Runtime,
    Sink,
    ToolCallParser
  }

  @groups [
    "agent-loop",
    "checkpoint",
    "context",
    "event",
    "jsonschema",
    "memory",
    "middleware",
    "plugin",
    "policy",
    "stream",
    "toolcall"
  ]

  def main do
    version = "spec/SPEC_VERSION" |> File.read!() |> String.trim()
    {failures, _seen} = Enum.reduce(@groups, {[], MapSet.new()}, fn group, {failures, seen} ->
      content = File.read!("spec/vectors/#{group}.json")
      file = Json.parse!(content)
      failures = check_meta(failures, group, file, version)
      vectors = Json.get_array(file, "vectors")
      failures =
        if vectors == [] do
          failures ++ ["#{group}: empty vector group"]
        else
          failures
        end

      Enum.reduce(vectors, {failures, seen}, fn vector, {failures, seen} ->
        id = Json.get_string(vector, "id") || ""
        failures = if MapSet.member?(seen, id), do: failures ++ ["#{group}/#{id}: duplicate id"], else: failures
        seen = MapSet.put(seen, id)

        result =
          try do
            run_vector(group, vector)
            :ok
          rescue
            error -> :erlang.iolist_to_binary(Exception.message(error))
          end

        case result do
          :ok -> {failures, seen}
          message -> {failures ++ ["#{group}/#{id}: #{message}"], seen}
        end
      end)
    end)

    if failures == [] do
      IO.puts("all spec vectors passed")
    else
      Enum.each(failures, &IO.puts(:stderr, &1))
      System.halt(1)
    end
  end

  defp check_meta(failures, group, file, version) do
    failures =
      if Json.get_string(file, "group") == group do
        failures
      else
        failures ++ ["#{group}: group mismatch"]
      end

    if Json.get_string(file, "specVersion") == version do
      failures
    else
      failures ++ ["#{group}: specVersion mismatch"]
    end
  end

  defp check(condition, message) do
    if not condition, do: raise(message)
  end

  defp node_or(node, key, fallback) do
    case Map.fetch(node, key) do
      {:ok, value} -> value
      :error -> fallback
    end
  end

  defp run_vector(group, vector) do
    input = node_or(vector, "input", %{})
    expect = node_or(vector, "expect", %{})

    case group do
      "toolcall" -> run_toolcall(input, expect)
      "jsonschema" -> run_jsonschema(input, expect)
      "plugin" -> run_plugin(input, expect)
      "memory" -> run_memory(input, expect)
      "event" -> run_event(input, expect)
      "stream" -> run_stream(expect)
      "checkpoint" -> run_checkpoint(input, expect)
      "policy" -> run_policy(input, expect)
      "context" -> run_context(input, expect)
      "middleware" -> run_middleware(input, expect)
      "agent-loop" -> run_agent_loop(input, expect)
      _ -> raise("no runner for group #{group}")
    end
  end

  defp run_toolcall(input, expect) do
    operation = Json.get_string(input, "operation") || ""
    content = Json.get_string(input, "content") || ""

    if operation == "strip" do
      check(ToolCallParser.strip_tool_call_markup(content) == (Json.get_string(expect, "text") || ""),
        "strip mismatch")
    else
      case ToolCallParser.parse_tool_call(content) do
        {:ok, call} ->
          check(not Json.get_bool(expect, "nil"), "expected nil")
          check(call.name == (Json.get_string(expect, "name") || ""), "name mismatch")
          expected = node_or(expect, "input", %{})
          check(Json.equals?(call.arguments, expected), "input mismatch")

        :error ->
          check(Json.get_bool(expect, "nil"), "expected a tool call")
      end
    end
  end

  defp run_jsonschema(input, expect) do
    schema = node_or(input, "schema", :null)
    data = node_or(input, "data", :null)
    errors = JsonSchema.validate(schema, data)
    paths = errors |> Enum.map(& &1.path) |> Enum.sort()
    expected = Json.get_array(expect, "errorPaths") |> Enum.sort()
    check((errors == []) == Json.get_bool(expect, "valid"), "valid mismatch")
    check(Json.equals?(paths, expected), "errorPaths mismatch")
  end

  defp run_plugin(input, expect) do
    raw =
      case Json.get_string(input, "raw") do
        nil -> Json.encode(node_or(input, "manifest", :null))
        value -> value
      end

    case Plugin.parse_manifest(raw) do
      {:ok, manifest} ->
        check(Json.get_bool(expect, "valid"), "valid mismatch")

        if id = Json.get_string(expect, "id") do
          check(manifest.id == id, "id mismatch")
        end

        if kind = Json.get_string(expect, "kind") do
          check(manifest.kind == kind, "kind mismatch")
        end

      {:error, _} ->
        check(not Json.get_bool(expect, "valid"), "valid mismatch")
    end
  end

  defp run_memory(input, expect) do
    store = MemoryStore.new()

    store =
      Enum.reduce(Json.get_array(input, "puts"), store, fn put, store ->
        record = node_or(put, "record", %{})
        value = Models.memory_record(
          Json.get_string(record, "id") || "",
          Json.get_string(record, "frame") || "",
          Json.get_string(record, "content") || "",
          Json.get_string(record, "createdAt")
        )
        {store, _} = MemoryStore.put(store, Json.get_string(put, "session") || "", value)
        store
      end)

    records = MemoryStore.search(
      store,
      Json.get_string(input, "session") || "",
      Json.get_string(input, "query") || "",
      Json.get_int(input, "limit")
    )

    ids = if records == [], do: :null, else: Enum.map(records, & &1.id)
    contents = if records == [], do: :null, else: Enum.map(records, & &1.content)
    check(Json.equals?(ids, node_or(expect, "ids", :null)), "ids mismatch")
    check(Json.equals?(contents, node_or(expect, "contents", :null)), "contents mismatch")
  end

  defp run_event(input, expect) do
    events =
      Enum.map(Json.get_array(input, "events"), fn kind -> Models.event(kind, "s1") end)

    if (Json.get_string(input, "sink") || "filter") == "multi" do
      count = max(1, Json.get_int(input, "sinkCount", 1))
      sinks = List.duplicate(nil, count) |> Enum.map(fn _ -> Sink.new() end)
      multi = Sink.multi(sinks)
      final = Enum.reduce(events, multi, fn event, sink -> Sink.emit(sink, event) end)
      per_sink = Enum.map(final.sinks, & &1.kinds)
      check(Json.equals?(per_sink, node_or(expect, "perSink", :null)), "perSink mismatch")
    else
      base = Sink.new()
      predicate = Json.get_array(input, "predicateTypes")
      filter = Sink.filter(base, predicate)
      final = Enum.reduce(events, filter, fn event, sink -> Sink.emit(sink, event) end)
      delivered = if final.target.kinds == [], do: :null, else: final.target.kinds
      check(Json.equals?(delivered, node_or(expect, "delivered", :null)), "delivered mismatch")
    end
  end

  defp run_stream(expect) do
    check(Json.equals?(Models.stream_kinds(), node_or(expect, "kinds", :null)), "kinds mismatch")
  end

  defp run_checkpoint(input, expect) do
    allow =
      Enum.reduce(Json.get_array(input, "registered"), CheckpointAllowlist.new(), fn kind, allow ->
        CheckpointAllowlist.register(allow, kind)
      end)

    operation = Json.get_string(input, "operation") || "roundtrip"
    kind = Json.get_string(input, "type") || ""
    value = node_or(input, "value", :null)

    case operation do
      "roundtrip" ->
        {:ok, data} = CheckpointAllowlist.marshal(allow, kind, value)
        {:ok, decoded} = CheckpointAllowlist.unmarshal(allow, data)
        check(Json.equals?(decoded, node_or(expect, "value", :null)), "value mismatch")

      "marshal" ->
        code =
          case CheckpointAllowlist.marshal(allow, kind, value) do
            {:ok, _} -> ""
            {:error, code} -> code
          end

        check(code == (Json.get_string(expect, "errorCode") || ""), "errorCode mismatch")

      "unmarshal" ->
        envelope = Json.encode(%{"type" => kind, "data" => value})

        code =
          case CheckpointAllowlist.unmarshal(allow, envelope) do
            {:ok, _} -> ""
            {:error, code} -> code
          end

        check(code == (Json.get_string(expect, "errorCode") || ""), "errorCode mismatch")
    end
  end

  defp run_policy(input, expect) do
    grants =
      Enum.map(Json.get_array(input, "grants"), fn item ->
        Models.path_grant(
          Json.get_string(item, "root") || "",
          Json.get_string(item, "access") || "read"
        )
      end)

    checker = Runtime.path_checker(grants)
    target = Json.get_string(input, "target") || ""
    need = Json.get_string(input, "need") || "read"

    if Json.get_bool(expect, "error") do
      failed =
        try do
          Runtime.check(checker, target, need)
          false
        rescue
          Praxo.Error -> true
        end

      check(failed, "expected a policy error")
    else
      decision = Runtime.check(checker, target, need)
      check(decision.allowed == Json.get_bool(expect, "allowed"), "allowed mismatch")
    end
  end

  defp run_context(input, expect) do
    messages =
      Enum.map(Json.get_array(input, "messages"), fn item ->
        Models.message(
          Json.get_string(item, "role") || "",
          Json.get_string(item, "content") || ""
        )
      end)

    if (Json.get_string(input, "operation") || "") == "estimate" do
      check(Runtime.estimate_tokens(messages) == Json.get_int(expect, "tokens"), "tokens mismatch")
    else
      budget_value = node_or(input, "budget", %{})
      budget = Models.context_budget(
        Json.get_int(budget_value, "maxTokens"),
        Json.get_int(budget_value, "keepRecent")
      )

      {output, ok} = Runtime.compact_context(budget, messages)
      check(ok == Json.get_bool(expect, "ok"), "ok mismatch")

      if ok do
        check(Runtime.estimate_tokens(output) == Json.get_int(expect, "tokens"), "tokens mismatch")
        wire = Enum.map(output, &Models.message_wire/1)
        check(Json.equals?(wire, node_or(expect, "messages", :null)), "messages mismatch")
      end
    end
  end

  defp run_middleware(input, expect) do
    case Json.get_string(input, "operation") || "" do
      "pii" ->
        check(
          Middleware.pii_redact(Json.get_string(input, "text") || "") ==
            (Json.get_string(expect, "text") || ""),
          "text mismatch"
        )

      "pii-value" ->
        check(
          Json.equals?(
            Middleware.redact_value(node_or(input, "value", :null)),
            node_or(expect, "value", :null)
          ),
          "value mismatch"
        )

      "structured" ->
        repair = Json.get_string(input, "repairOutput")
        repairer = if repair == nil, do: nil, else: fn _text -> repair end
        config = Middleware.structured_output(node_or(input, "schema", %{}), Json.get_int(input, "maxRepairs"), repairer)

        case Middleware.apply_structured(config, Json.get_string(input, "output") || "") do
          {:ok, output} ->
            check(Json.get_bool(expect, "ok"), "expected error")
            check(output == (Json.get_string(expect, "output") || ""), "output mismatch")

          {:error, code} ->
            check(not Json.get_bool(expect, "ok"), "expected success")
            check(code == (Json.get_string(expect, "errorCode") || ""), "errorCode mismatch")
        end

      "call-limit" ->
        limit = Middleware.call_limit(Json.get_int(input, "modelLimit"), Json.get_int(input, "toolLimit"))

        {outcomes, _limit} =
          Enum.reduce(Json.get_array(input, "calls"), {[], limit}, fn call, {outcomes, limit} ->
            {code, limit} =
              case call do
                "model" ->
                  case Middleware.model_call(limit) do
                    {:ok, limit} -> {"ok", limit}
                    {:error, code, limit} -> {code, limit}
                  end

                _ ->
                  case Middleware.tool_call(limit) do
                    {:ok, limit} -> {"ok", limit}
                    {:error, code, limit} -> {code, limit}
                  end
              end

            {outcomes ++ [code], limit}
          end)

        check(Json.equals?(outcomes, node_or(expect, "outcomes", :null)), "outcomes mismatch")

      "tool-selection" ->
        selected = Json.get_array(input, "selected")
        selection = Middleware.tool_selection(selected)
        tools = Enum.map(Json.get_array(input, "tools"), &Models.tool_spec(&1, ""))
        advertised = Middleware.select_tools(selection, tools) |> Enum.map(& &1.name)
        check(Json.equals?(advertised, node_or(expect, "advertised", :null)), "advertised mismatch")

        reject =
          case Middleware.check_tool_selected(selection, Json.get_string(input, "requested") || "") do
            :ok -> "ok"
            {:error, code} -> code
          end

        check(reject == (Json.get_string(expect, "reject") || ""), "reject mismatch")

      "fallback" ->
        content = Json.get_string(input, "fallbackContent") || ""
        model = Agent.fallback_model(Agent.failing_model(), Agent.static_model(content))
        {:ok, response, _} = Agent.generate(model, Models.request([]))
        check(response.message.content == content, "output mismatch")

      _ ->
        raise("unknown middleware operation")
    end
  end

  defp run_agent_loop(input, expect) do
    tools =
      Enum.map(Json.get_array(input, "tools"), fn item ->
        Agent.new_tool(Json.get_string(item, "name") || "", Json.get_string(item, "description") || "")
      end)

    script =
      Enum.map(Json.get_array(input, "script"), fn item ->
        calls =
          Enum.map(Json.get_array(item, "toolCalls"), fn call ->
            Models.tool_call(
              Json.get_string(call, "id") || "",
              Json.get_string(call, "name") || "",
              node_or(call, "arguments", %{})
            )
          end)

        Models.response(
          Models.message_assistant(Json.get_string(item, "content") || "", calls),
          Models.usage(Json.get_int(item, "inputTokens"), Json.get_int(item, "outputTokens"))
        )
      end)

    model = Agent.scripted_model(script)
    options = Agent.new_agent_options(model)
    options = %{options | tools: tools, max_steps: Json.get_int(input, "maxSteps"), max_tokens: Json.get_int(input, "maxTokens"), events: Sink.new()}
    session = Models.session("s1")

    case Agent.run_agent(options, session, Json.get_string(input, "prompt") || "") do
      {:ok, result, options} ->
        check(not Json.get_bool(expect, "error"), "unexpected error")
        check(result.output == (Json.get_string(expect, "output") || ""), "output mismatch")
        check(result.steps == Json.get_int(expect, "steps"), "steps mismatch")
        check_agent_events(options, tools, expect)

      {:error, code, options} ->
        check(Json.get_bool(expect, "error"), "unexpected success")

        if expected = Json.get_string(expect, "errorCode") do
          check(code == expected, "errorCode mismatch")
        end

        check_agent_events(options, tools, expect)
    end
  end

  defp check_agent_events(options, _tools, expect) do
    invocations = Enum.reduce(options.tools, 0, fn tool, total -> total + tool.calls end)
    check(invocations == Json.get_int(expect, "toolInvocations"), "tool invocations mismatch")

    events =
      case options.events do
        nil -> :null
        sink -> if sink.kinds == [], do: :null, else: sink.kinds
      end

    check(Json.equals?(events, node_or(expect, "events", :null)), "events mismatch")
  end
end

Praxo.Conformance.main()
