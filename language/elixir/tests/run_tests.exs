defmodule Praxo.Tests do
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

  def run do
    test_json()
    test_toolcall()
    test_jsonschema()
    test_plugin()
    test_memory()
    test_checkpoint()
    test_context()
    test_paths()
    test_pii()
    test_agent()
    test_run_ids()
    test_agent_tool()
    test_agent_tool_selection()
    test_fallback_state()
    test_custom_model()
    test_custom_model_error()
    test_agent_pii()
    test_agent_structured()
    test_agent_limits()
    IO.puts("elixir tests passed")
  end

  defp check(true, _message), do: :ok
  defp check(false, message), do: raise(message)

  defp test_json do
    value = Json.parse!(~s({"name":"echo","input":{"text":"hi"}}))
    check(Json.get_string(value, "name") == "echo", "json name")
    other = Json.parse!(~s({"input":{"text":"hi"},"name":"echo"}))
    check(Json.equals?(value, other), "json object equality")
    check(Json.equals?(value, Json.parse!(Json.encode(value))), "json roundtrip")
  end

  defp test_toolcall do
    {:ok, call} = ToolCallParser.parse_tool_call(~s({"name":"echo","input":{"text":"hi"}}))
    check(call.name == "echo", "json tool call")
    check(ToolCallParser.parse_tool_call("plain text") == :error, "plain text")
    {:ok, xml} = ToolCallParser.parse_tool_call(~s(<tool_call name="echo">{"text":"hi"}</tool_call>))
    check(xml.name == "echo", "xml tool call")
    {:ok, tag} = ToolCallParser.parse_tool_call(~s(<echo.echo>{"text":"hi"}</echo.echo>))
    check(tag.name == "echo.echo", "tag tool call")
    {:ok, plain} = ToolCallParser.parse_tool_call(~s(echo.run {"text":"hi"}))
    check(plain.name == "echo.run", "plain tool call")
    stripped = ToolCallParser.strip_tool_call_markup(~s(hello<tool_call name="echo">{"text":"hi"}</tool_call>world))
    check(stripped == "helloworld", "strip markup")
  end

  defp test_jsonschema do
    schema = Json.parse!(~s({"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}))
    check(JsonSchema.validate(schema, Json.parse!(~s({"name":"ok"}))) == [], "schema valid")
    errors = JsonSchema.validate(schema, Json.parse!("{}"))
    check(length(errors) == 1 and hd(errors).path == "$.name", "schema required")
    pattern = Json.parse!(~s({"type":"string","pattern":"^a+$"}))
    check(JsonSchema.validate(pattern, "aaa") == [], "schema pattern valid")
    check(length(JsonSchema.validate(pattern, "b")) == 1, "schema pattern invalid")
    unicode = Json.parse!(~s({"type":"string","minLength":2,"maxLength":2}))
    check(JsonSchema.validate(unicode, "你好") == [], "schema unicode two")
    check(length(JsonSchema.validate(unicode, "你")) == 1, "schema unicode one")
    integer = Json.parse!(~s({"type":"integer"}))
    check(JsonSchema.validate(integer, 2) == [], "schema integer")
    check(length(JsonSchema.validate(integer, 2.5)) == 1, "schema integer fraction")
  end

  defp test_plugin do
    raw = ~s({"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":["echo"],"permissions":{},"limits":{},"health":{},"isolation":"process"})
    {:ok, manifest} = Plugin.parse_manifest(raw)
    check(manifest.id == "com.example.echo", "plugin id")
    check(match?({:error, _}, Plugin.parse_manifest(raw <> "{}")), "plugin trailing data")
  end

  defp test_memory do
    store = MemoryStore.new()
    {store, _} = MemoryStore.put(store, "s1", Models.memory_record("m1", "event", "Alpha", "2026-01-01T00:00:00Z"))
    {store, _} = MemoryStore.put(store, "s1", Models.memory_record("m2", "event", "beta", "2026-01-02T00:00:00Z"))
    {store, _} = MemoryStore.put(store, "s1", Models.memory_record("m3", "decision", "ALPHABET", "2026-01-03T00:00:00Z"))
    records = MemoryStore.search(store, "s1", "alpha", 10)
    check(Enum.map(records, & &1.id) == ["m3", "m1"], "memory ordering")
    check(Enum.map(MemoryStore.search(store, "s1", "alpha", 1), & &1.id) == ["m3"], "memory limit")
    check(MemoryStore.search(store, "s2", "alpha", 10) == [], "memory session isolation")
  end

  defp test_checkpoint do
    allow = CheckpointAllowlist.register(CheckpointAllowlist.new(), "spec.payload")
    value = Json.parse!(~s({"value":"x"}))
    {:ok, data} = CheckpointAllowlist.marshal(allow, "spec.payload", value)
    {:ok, decoded} = CheckpointAllowlist.unmarshal(allow, data)
    check(Json.equals?(decoded, value), "checkpoint roundtrip")
    check(CheckpointAllowlist.marshal(allow, "spec.missing", :null) == {:error, "CHECKPOINT_TYPE_NOT_ALLOWED"}, "checkpoint allowlist")
  end

  defp test_context do
    messages = [
      Models.message("system", "sys"),
      Models.message("user", "message 0"),
      Models.message("user", "message 1")
    ]

    check(Runtime.estimate_tokens(messages) == 16, "context estimate")
    {output, ok} = Runtime.compact_context(Models.context_budget(0, 0), messages)
    check(ok and length(output) == 3, "context disabled")
  end

  defp test_pii do
    check(Middleware.pii_redact("email a@b.com") == "email [REDACTED:email]", "pii email")
    check(Middleware.pii_redact("ssn 123-45-6789") == "ssn [REDACTED:ssn]", "pii ssn")
    check(Middleware.pii_redact("call 415-555-2671") == "call [REDACTED:phone]", "pii phone")
    check(Middleware.pii_redact("version 1.2.3") == "version 1.2.3", "pii phone boundary")
  end

  defp test_paths do
    checker = Runtime.path_checker([Models.path_grant("allowed", "read")])
    for path <- ["../allowed/secret", "../../allowed/secret", "x/../../allowed/secret", "..\\allowed\\secret"] do
      check(not Runtime.path_allowed(checker, path, "read"), "relative traversal: #{path}")
    end
    check(Runtime.path_allowed(checker, "allowed/sub/../secret", "read"), "relative path within grant")
    check(Runtime.normalize_path("../../a/../b") == "../../b", "leading parent segments")
    check(Runtime.normalize_path("/../../allowed") == "/allowed", "absolute root traversal")
    check(Runtime.normalize_path("C:../allowed") != Runtime.normalize_path("C:/allowed"), "drive relative traversal")
    parent = Runtime.path_checker([Models.path_grant("../allowed", "read")])
    check(Runtime.path_allowed(parent, "../allowed/secret", "read"), "relative parent grant")
    check(not Runtime.path_allowed(parent, "allowed/secret", "read"), "relative parent grant isolation")
  end

  defp test_agent do
    model = Agent.scripted_model([
      Models.response(Models.message_assistant("hello"), Models.usage(0, 0))
    ])

    options = Agent.new_agent_options(model)
    options = %{options | events: Sink.new()}
    {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "hello")
    check(result.output == "hello", "agent output")
    check(result.steps == 1, "agent steps")
    check(options.events.kinds == ["run.started", "run.completed"], "agent events")
  end

  defp test_run_ids do
    model = Agent.static_model("ok")

    {:ok, first, _} = Agent.run_agent(Agent.new_agent_options(model), Models.session("s1"), "hi")
    {:ok, second, _} = Agent.run_agent(Agent.new_agent_options(model), Models.session("s1"), "hi")
    check(first.run_id != second.run_id, "run ids are distinct")
  end

  defp test_agent_tool do
    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [Models.tool_call("c1", "echo", %{"text" => "hi"})]), Models.usage(0, 0)),
      Models.response(Models.message_assistant("done"), Models.usage(0, 0))
    ])

    tool = Agent.new_tool("echo", "Echo")
    options = Agent.new_agent_options(model)
    options = %{options | tools: [tool], events: Sink.new()}
    {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "use")
    check(result.output == "done", "agent tool output")
    check(hd(options.tools).calls == 1, "agent tool calls")
    check(options.events.kinds == ["run.started", "tool.call", "run.completed"], "agent tool events")
  end

  defp test_agent_tool_selection do
    parent = self()
    tools = [Agent.new_tool("echo", "Echo"), Agent.new_tool("secret", "Secret", fn _ -> send(parent, :invoked); :null end)]

    model = fn request ->
      send(parent, {:specs, Enum.map(request.tools, & &1.name)})
      if length(request.messages) == 1 do
        {:ok, Models.response(Models.message_assistant("", [Models.tool_call("c1", "echo", %{})]))}
      else
        {:ok, Models.response(Models.message_assistant("done"))}
      end
    end

    options = %{Agent.new_agent_options(model) | tools: tools, tool_selection: Middleware.tool_selection(["echo"])}
    {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "use")
    check(result.output == "done" and hd(options.tools).calls == 1, "selected tool invoked")
    for _ <- 1..2 do
      receive do
        {:specs, names} -> check(names == ["echo"], "selected specs on every step")
      after
        0 -> raise "missing selected specs"
      end
    end

    denied_model = fn request ->
      send(parent, {:specs, Enum.map(request.tools, & &1.name)})
      {:ok, Models.response(Models.message_assistant("", [Models.tool_call("c2", "secret", %{})]))}
    end

    options = %{Agent.new_agent_options(denied_model) | tools: tools, tool_selection: Middleware.tool_selection([]), events: Sink.new()}
    {:error, "AGENT_TOOL_NOT_SELECTED", options} = Agent.run_agent(options, Models.session("s1"), "use")
    receive do
      {:specs, names} -> check(names == [], "empty selection filters specs")
    after
      0 -> raise "missing empty specs"
    end
    receive do
      :invoked -> raise "unselected tool invoked"
    after
      0 -> :ok
    end
    check(Enum.all?(options.tools, &(&1.calls == 0)), "unselected tool call count")
    check(options.events.kinds == ["run.started", "run.failed"], "unselected tool failure events")

    options = %{Agent.new_agent_options(denied_model) | tools: tools, max_steps: 1}
    {:error, "AGENT_MAX_STEPS", options} = Agent.run_agent(options, Models.session("s1"), "use")
    receive do
      {:specs, names} -> check(names == ["echo", "secret"], "default advertises all tools")
    after
      0 -> raise "missing default specs"
    end
    receive do
      :invoked -> :ok
    after
      0 -> raise "default tool not invoked"
    end
    check(Enum.at(options.tools, 1).calls == 1, "default permits tool")
  end

  defp test_fallback_state do
    steps = [
      Models.response(Models.message_assistant("", [Models.tool_call("c1", "echo", %{})])),
      Models.response(Models.message_assistant("done"))
    ]

    for model <- [
      Agent.fallback_model(Agent.scripted_model(steps), Agent.failing_model()),
      Agent.fallback_model(Agent.failing_model(), Agent.scripted_model(steps))
    ] do
      options = %{Agent.new_agent_options(model) | tools: [Agent.new_tool("echo", "Echo")]}
      {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "use")
      check(result.output == "done" and result.steps == 2, "fallback model advances across tool calls")
      child = if model.primary.mode == :scripted, do: options.model.primary, else: options.model.fallback
      check(child.index == 2, "fallback child state retained")
    end

    nested = Agent.fallback_model(Agent.scripted_model([]), Agent.scripted_model([]))
    model = Agent.fallback_model(nested, nil)
    {:error, "MODEL_ERROR", updated} = Agent.generate(model, Models.request([], []))
    check(updated.primary == nested, "nested failure state retained")
  end

  defp test_custom_model do
    model = fn request ->
      check(Enum.map(request.tools, & &1.name) == ["echo"], "custom model tool specs")

      case request.messages do
        [%{role: "system", content: "system"}, %{role: "user", content: "use"}] ->
          {:ok, Models.response(Models.message_assistant("", [Models.tool_call("c1", "echo", %{"text" => "hi"})]), Models.usage(1, 2))}

        [%{role: "system"}, %{role: "user"}, %{role: "assistant"}, %{role: "tool", tool_id: "c1", content: content}] ->
          check(Json.parse!(content) == %{"text" => "hi"}, "custom model tool result")
          {:ok, Models.response(Models.message_assistant("done"), Models.usage(3, 4))}
      end
    end

    for model <- [model, Agent.fallback_model(Agent.failing_model(), model), Agent.fallback_model(model, nil)] do
      options = %{Agent.new_agent_options(model) | tools: [Agent.new_tool("echo", "Echo")], system_prompt: "system", events: Sink.new()}
      {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "use")
      check(result.output == "done" and result.steps == 2, "custom model multi-step")
      check(result.usage == Models.usage(4, 6), "custom model usage")
      check(hd(options.tools).calls == 1, "custom model tool invocation")
      check(options.events.kinds == ["run.started", "tool.call", "run.completed"], "custom model events")
    end
  end

  defp test_custom_model_error do
    model = fn _request -> {:error, "PROVIDER_ERROR"} end
    options = %{Agent.new_agent_options(model) | events: Sink.new()}
    {:error, "PROVIDER_ERROR", options} = Agent.run_agent(options, Models.session("s1"), "use")
    check(options.model == model, "custom model retained on error")
    check(options.events.kinds == ["run.started", "run.failed"], "custom model failure event")

    fallback = Agent.fallback_model(model, Agent.static_model("recovered"))
    {:ok, result, options} = Agent.run_agent(Agent.new_agent_options(fallback), Models.session("s1"), "use")
    check(result.output == "recovered" and options.model.primary == model, "custom model fallback on error")
  end

  defp test_agent_pii do
    parent = self()
    tool = Agent.new_tool("echo", "Echo", fn args ->
      send(parent, {:arguments, args})
      %{"nested" => ["a@b.com", %{"ssn" => "123-45-6789"}]}
    end)
    model = fn request ->
      send(parent, {:request, request})
      if length(request.messages) == 3 do
        {:ok, Models.response(Models.message_assistant("a@b.com", [Models.tool_call("c", "echo", %{"email" => "a@b.com"})]))}
      else
        {:ok, Models.response(Models.message_assistant("a@b.com"))}
      end
    end
    history = %{Models.message("user", "a@b.com") | content_blocks: [Models.content_block("text", "123-45-6789")]}
    session = Models.session("s1", [history])
    options = %{Agent.new_agent_options(model) | tools: [tool], system_prompt: "a@b.com", pii: true}
    {:ok, result, _} = Agent.run_agent(options, session, "a@b.com")
    check(result.output == "a@b.com", "pii does not redact final output")
    receive do
      {:request, request} ->
        [system, past, prompt] = request.messages
        check(system.content == "[REDACTED:email]" and past.content == system.content and prompt.content == system.content, "pii model inputs")
        check(hd(past.content_blocks).text == "[REDACTED:ssn]", "pii content blocks")
    after 0 -> raise "missing pii request" end
    receive do
      {:arguments, args} -> check(args["email"] == "a@b.com", "pii preserves tool arguments")
    after 0 -> raise "missing tool arguments" end
    receive do
      {:request, request} ->
        assistant = Enum.at(request.messages, 3)
        value = request.messages |> List.last() |> Map.fetch!(:content) |> Json.parse!()
        check(assistant.content == "[REDACTED:email]", "pii assistant history")
        check(hd(assistant.tool_calls).arguments["email"] == "[REDACTED:email]", "pii assistant tool call")
        check(value == %{"nested" => ["[REDACTED:email]", %{"ssn" => "[REDACTED:ssn]"}]}, "pii nested result")
    after 0 -> raise "missing second pii request" end
    check(history.content == "a@b.com", "pii session unchanged")
    plain = fn request -> send(parent, {:plain, hd(request.messages).content}); {:ok, Models.response(Models.message_assistant("ok"))} end
    {:ok, _, _} = Agent.run_agent(Agent.new_agent_options(plain), Models.session("s1"), "a@b.com")
    receive do {:plain, text} -> check(text == "a@b.com", "pii default disabled") after 0 -> raise "missing plain request" end
  end

  defp test_agent_structured do
    schema = %{"type" => "object", "required" => ["name"], "properties" => %{"name" => %{"type" => "string"}}}
    config = Middleware.structured_output(schema, 1, fn _ -> ~s({"name":"fixed"}) end)
    options = %{Agent.new_agent_options(Agent.static_model("bad")) | structured_output: config, events: Sink.new()}
    {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "x")
    check(result.output == ~s({"name":"fixed"}), "structured repaired output")
    check(options.events.kinds == ["run.started", "run.completed"], "structured success event")
    for {text, repairer, repairs} <- [{"{}", nil, 0}, {"bad", fn _ -> "" end, 1}, {"bad", fn _ -> "{}" end, 1}, {"bad", fn _ -> nil end, 1}, {"bad", fn _ -> "{}" end, -1}] do
      config = Middleware.structured_output(schema, repairs, repairer)
      options = %{Agent.new_agent_options(Agent.static_model(text)) | structured_output: config, events: Sink.new()}
      {:error, "AGENT_STRUCTURED_OUTPUT", options} = Agent.run_agent(options, Models.session("s1"), "x")
      check(options.events.kinds == ["run.started", "run.failed"], "structured failure event")
    end
    error = ArgumentError.exception("repair failed")
    repairer = fn _ -> raise error end
    config = Middleware.structured_output(schema, 1, repairer)
    check(Middleware.apply_structured(config, "bad") == {:error, error}, "structured helper preserves repair exception")
    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [Models.tool_call("c", "echo", %{})])),
      Models.response(Models.message_assistant("bad"))
    ])
    options = %{Agent.new_agent_options(model) | structured_output: config, tools: [Agent.new_tool("echo", "Echo")], events: Sink.new()}
    {:error, ^error, returned} = Agent.run_agent(options, Models.session("s1"), "x")
    check(returned.events.kinds == ["run.started", "tool.call", "run.failed"], "repair exception failure lifecycle")
    check(returned.model.index == 2 and hd(returned.tools).calls == 1, "repair exception retains run state")
    options = %{Agent.new_agent_options(Agent.static_model("bad")) | structured_output: config}
    {:error, ^error, returned} = Agent.run_agent(options, Models.session("s1"), "x")
    check(returned.events == nil, "repair exception without event sink")
    config = Middleware.structured_output(schema, 0)
    options = %{Agent.new_agent_options(Agent.static_model(~s({"name":"ok"}))) | structured_output: config}
    {:ok, result, _} = Agent.run_agent(options, Models.session("s1"), "x")
    check(result.output == ~s({"name":"ok"}), "structured valid output")
    model = Agent.scripted_model([
      Models.response(Models.message_assistant("not json", [Models.tool_call("c", "echo", %{})])),
      Models.response(Models.message_assistant(~s({"name":"ok"})))
    ])
    options = %{Agent.new_agent_options(model) | structured_output: config, tools: [Agent.new_tool("echo", "Echo")]}
    {:ok, result, _} = Agent.run_agent(options, Models.session("s1"), "x")
    check(result.steps == 2, "structured validates only final response")
    {:ok, result, _} = Agent.run_agent(Agent.new_agent_options(Agent.static_model("bad")), Models.session("s1"), "x")
    check(result.output == "bad", "structured default disabled")
  end

  defp test_agent_limits do
    parent = self()
    tool = Agent.new_tool("echo", "Echo", fn _ -> send(parent, :tool_invoked); "ok" end)
    calls = [Models.tool_call("1", "echo", %{}), Models.tool_call("2", "echo", %{})]
    model = fn _ -> send(parent, :model_invoked); {:ok, Models.response(Models.message_assistant("", calls))} end
    options = %{Agent.new_agent_options(model) | tools: [tool], call_limit: Middleware.call_limit(0, 1), events: Sink.new()}
    for _ <- 1..2 do
      {:error, "AGENT_TOOL_CALL_LIMIT", returned} = Agent.run_agent(options, Models.session("s1"), "x")
      check(hd(returned.tools).calls == 1, "tool budget blocks second invocation")
      check(returned.events.kinds == ["run.started", "tool.call", "run.failed"], "tool budget events")
      receive do :model_invoked -> :ok after 0 -> raise "model not invoked" end
      receive do :tool_invoked -> :ok after 0 -> raise "tool not invoked" end
      receive do :tool_invoked -> raise "tool exceeded limit" after 0 -> :ok end
    end
    one_call = fn _ -> send(parent, :model_invoked); {:ok, Models.response(Models.message_assistant("", [hd(calls)]))} end
    options = %{Agent.new_agent_options(one_call) | tools: [tool], call_limit: Middleware.call_limit(1, 0), events: Sink.new()}
    {:error, "AGENT_MODEL_CALL_LIMIT", returned} = Agent.run_agent(options, Models.session("s1"), "x")
    check(returned.events.kinds == ["run.started", "tool.call", "run.failed"], "model budget events")
    receive do :model_invoked -> :ok after 0 -> raise "model not invoked" end
    receive do :model_invoked -> raise "model exceeded limit" after 0 -> :ok end
    receive do :tool_invoked -> :ok after 0 -> raise "tool not invoked" end
    {:error, "AGENT_MODEL_CALL_LIMIT", _} = Agent.run_agent(returned, Models.session("s1"), "x")
    receive do :model_invoked -> :ok after 0 -> raise "model budget not reset after limit failure" end
    receive do :tool_invoked -> :ok after 0 -> raise "tool not invoked on reused options" end
    success = %{Agent.new_agent_options(Agent.static_model("ok")) | call_limit: Middleware.call_limit(1, 1)}
    {:ok, _, success} = Agent.run_agent(success, Models.session("s1"), "x")
    {:ok, _, _} = Agent.run_agent(success, Models.session("s1"), "x")
    failed = %{Agent.new_agent_options(Agent.failing_model()) | call_limit: Middleware.call_limit(1, 0)}
    {:error, "MODEL_ERROR", failed} = Agent.run_agent(failed, Models.session("s1"), "x")
    {:error, "MODEL_ERROR", _} = Agent.run_agent(failed, Models.session("s1"), "x")
  end
end

Praxo.Tests.run()
