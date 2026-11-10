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
    test_agent_capacity()
    test_agent_authorization()
    test_agent_lifecycle()
    test_agent_cancellation()
    test_agent_stream()
    test_agent_parallel()
    test_agent_hitl()
    test_sse()
    test_openai_adapter()
    test_harmovela_sink()
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


  defp tool_model do
    Agent.scripted_model([
      Models.response(Models.message_assistant("", [Models.tool_call("c1", "echo", %{"text" => "hi"})]), Models.usage(0, 0)),
      Models.response(Models.message_assistant("done"), Models.usage(0, 0))
    ])
  end

  defp test_agent_authorization do
    parent = self()
    Process.put(:actions, [])

    options =
      %{Agent.new_agent_options(tool_model()) |
        tools: [Agent.new_tool("echo", "Echo", fn args -> send(parent, {:tool, args}); args end)],
        policy: fn action ->
          Process.put(:actions, Process.get(:actions) ++ [action])
          Models.decision(true)
        end,
        middleware: [%{before_tool: fn call -> %{call | arguments: %{"text" => "mutated"}} end}]}

    {:ok, result, _} = Agent.run_agent(options, Models.session("s1"), "go")
    check(result.output == "done", "elixir final arguments output")
    actions = Process.get(:actions) |> Enum.filter(&(&1.kind == "tool.invoke"))
    check(length(actions) == 2, "elixir final arguments reauthorized")
    check(Enum.at(actions, 0).arguments["text"] == "hi", "elixir original arguments")
    check(Enum.at(actions, 1).arguments["text"] == "mutated", "elixir final arguments")
    receive do
      {:tool, arguments} -> check(arguments["text"] == "mutated", "elixir final arguments effect")
    after
      1000 -> raise "elixir final arguments effect missing"
    end

    options =
      %{Agent.new_agent_options(tool_model()) |
        tools: [
          Agent.new_tool("echo", "Echo"),
          Agent.new_tool("other", "Other", fn args -> send(parent, {:other, args}); args end)
        ],
        allowed_tools: ["echo", "other"],
        middleware: [%{before_tool: fn call -> %{call | name: "other"} end}]}

    {:ok, _, _} = Agent.run_agent(options, Models.session("s1"), "go")
    receive do
      {:other, _} -> :ok
    after
      1000 -> raise "elixir final name effect missing"
    end

    options =
      %{Agent.new_agent_options(tool_model()) |
        tools: [Agent.new_tool("echo", "Echo")],
        allowed_tools: ["echo"],
        middleware: [%{before_tool: fn call -> %{call | name: "other"} end}]}

    check(match?({:error, "AGENT_TOOL_NOT_ALLOWED", _}, Agent.run_agent(options, Models.session("s1"), "go")),
      "elixir final name allowlist")

    Process.put(:actions, [])
    options =
      %{Agent.new_agent_options(tool_model()) |
        tools: [Agent.new_tool("echo", "Echo")],
        policy: fn action ->
          Process.put(:actions, Process.get(:actions) ++ [action])
          Models.decision(true)
        end,
        middleware: [%{}]}

    {:ok, _, _} = Agent.run_agent(options, Models.session("s1"), "go")
    actions = Process.get(:actions) |> Enum.filter(&(&1.kind == "tool.invoke"))
    check(length(actions) == 1, "elixir unchanged single authorization")

    parent = self()
    options =
      %{Agent.new_agent_options(tool_model()) |
        tools: [Agent.new_tool("echo", "Echo")],
        policy: fn action ->
          if action.kind == "tool.invoke", do: Models.decision(false), else: Models.decision(true)
        end,
        middleware: [%{before_tool: fn call -> send(parent, :middleware); call end}]}

    check(match?({:error, "AGENT_POLICY_DENIED", _}, Agent.run_agent(options, Models.session("s1"), "go")),
      "elixir initial denial")
    receive do
      :middleware -> raise "elixir initial denial ran middleware"
    after
      100 -> :ok
    end
  end

  defp test_agent_lifecycle do
    parent = self()
    options =
      %{Agent.new_agent_options(Agent.static_model("done")) |
        middleware: [
          %{before_run: fn _ -> send(parent, :first_before) end,
            after_run: fn _, _ -> send(parent, :first_after) end},
          %{before_run: fn _ -> raise "startup failed" end,
            after_run: fn _, _ -> send(parent, :second_after) end}
        ]}

    check(match?({:error, message, _} when is_binary(message), Agent.run_agent(options, Models.session("s1"), "go")),
      "elixir startup failure")
    check(receive_messages() == [:first_before, :first_after, :second_after], "elixir startup cleanup")

    parent = self()
    options =
      %{Agent.new_agent_options(Agent.failing_model()) |
        middleware: [
          %{after_run: fn _, _ -> send(parent, :first_after); raise "cleanup failed" end},
          %{after_run: fn _, _ -> send(parent, :second_after) end}
        ]}

    check(match?({:error, "MODEL_ERROR", _}, Agent.run_agent(options, Models.session("s1"), "go")),
      "elixir after-run preserves run error")
    check(receive_messages() == [:first_after, :second_after], "elixir after-run continues")

    parent = self()
    options =
      %{Agent.new_agent_options(Agent.static_model("done")) |
        middleware: [
          %{after_run: fn _, _ -> send(parent, :first_after); raise "cleanup failed" end},
          %{after_run: fn _, _ -> send(parent, :second_after) end}
        ]}

    check(match?({:error, "cleanup failed", _}, Agent.run_agent(options, Models.session("s1"), "go")),
      "elixir cleanup fail closed")
    check(receive_messages() == [:first_after, :second_after], "elixir cleanup continues")
  end

  defp test_agent_cancellation do
    ref = :atomics.new(1, [])
    model = fn _request ->
      :atomics.put(ref, 1, 1)
      {:ok, Models.response(Models.message_assistant("done"))}
    end

    options = %{
      Agent.new_agent_options(model) |
        cancellation: fn -> :atomics.get(ref, 1) == 1 end,
        events: Sink.new()
    }

    {:error, "AGENT_CANCELLED", options} =
      Agent.run_agent(options, Models.session("s1"), "go")

    check(options.events.kinds == ["run.started", "run.failed"], "elixir model cancellation events")

    tool_ref = :atomics.new(1, [])
    tool = Agent.new_tool("wait", "wait", fn _args ->
      :atomics.put(tool_ref, 1, 1)
      "ok"
    end)

    tool_model = fn request ->
      if length(request.messages) == 1 do
        {:ok, Models.response(Models.message_assistant("", [Models.tool_call("c1", "wait", %{})]))}
      else
        {:ok, Models.response(Models.message_assistant("done"))}
      end
    end

    tool_options = %{
      Agent.new_agent_options(tool_model) |
        tools: [tool],
        cancellation: fn -> :atomics.get(tool_ref, 1) == 1 end,
        events: Sink.new()
    }

    {:error, "AGENT_CANCELLED", tool_options} =
      Agent.run_agent(tool_options, Models.session("s1"), "go")

    check(tool_options.events.kinds == ["run.started", "tool.call", "run.failed"], "elixir tool cancellation events")
  end

  defp test_agent_stream do
    parent = self()

    options = %{
      Agent.new_agent_options(Agent.static_model("done")) |
        on_stream: fn part ->
          send(parent, {:stream, part.kind})
          if part.kind == "messages", do: raise("stream failed")
        end,
        events: Sink.new()
    }

    {:error, "STREAM_ERROR", options} =
      Agent.run_agent(options, Models.session("s1"), "go")

    check(stream_messages() == ["values", "messages"], "elixir stream parts")
    check(options.events.kinds == ["run.started", "run.failed"], "elixir stream failure events")
  end

  defp test_agent_parallel do
    parent = self()
    release_ref = :atomics.new(1, [])

    tool = fn name ->
      Agent.new_tool(name, name, fn _args ->
        send(parent, {:started, String.to_atom(name)})
        wait_for_release(release_ref)
        name
      end)
    end

    model = fn request ->
      if length(request.messages) == 1 do
        calls = [
          Models.tool_call("c1", "a", %{}),
          Models.tool_call("c2", "b", %{})
        ]

        {:ok, Models.response(Models.message_assistant("", calls))}
      else
        ids =
          request.messages
          |> Enum.filter(&(&1.role == "tool"))
          |> Enum.map(& &1.tool_id)

        send(parent, {:order, ids})
        {:ok, Models.response(Models.message_assistant("done"))}
      end
    end

    options = %{
      Agent.new_agent_options(model) |
        tools: [tool.("a"), tool.("b")],
        max_parallel_tools: 2
    }

    run = Task.async(fn -> Agent.run_agent(options, Models.session("s1"), "go") end)

    started = [receive_message(2000), receive_message(2000)]
    check(Enum.sort(started) == [{:started, :a}, {:started, :b}], "elixir parallel starts")
    :atomics.put(release_ref, 1, 1)

    {:ok, result, _options} = Task.await(run, 5000)
    check(result.output == "done", "elixir parallel result")
    check(receive_message(2000) == {:order, ["c1", "c2"]}, "elixir parallel order")
  end

  defp test_sse do
    check(Praxo.SSE.parse(
      "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n" <>
        "data: [DONE]\n\n"
    ) == {:ok, "hi"}, "elixir sse complete")

    check(Praxo.SSE.parse(
      "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n"
    ) == {:error, "MODEL_STREAM"}, "elixir sse truncated")

    check(Praxo.SSE.parse("data: {\"choices\"\n\n") == {:error, "MODEL_STREAM"},
      "elixir sse half packet")
  end

  defp wait_for_release(ref, attempts \\ 200) do
    cond do
      :atomics.get(ref, 1) == 1 -> :ok
      attempts <= 0 -> raise "parallel release timeout"
      true ->
        Process.sleep(10)
        wait_for_release(ref, attempts - 1)
    end
  end

  defp receive_message(timeout) do
    receive do
      message -> message
    after
      timeout -> raise "message timeout"
    end
  end

  defp stream_messages(acc \\ []) do
    receive do
      {:stream, kind} -> stream_messages(acc ++ [kind])
    after
      0 -> acc
    end
  end

  defp receive_messages(acc \\ []) do
    receive do
      message -> receive_messages(acc ++ [message])
    after
      100 -> acc
    end
  end

  defp test_agent_hitl do
    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("c1", "echo", %{"value" => "original"})
      ])),
      Models.response(Models.message_assistant("done"))
    ])
    options = %{Agent.new_agent_options(model) |
      tools: [Agent.new_tool("echo", "Echo", fn arguments -> arguments end)],
      interrupt_on: ["echo"],
      on_interrupt_decision: fn _interrupt -> %Praxo.InterruptDecision{action: "approve"} end}
    {:ok, result, options} = Agent.run_agent(options, Models.session("s1"), "go")
    check(result.output == "done" and hd(options.tools).calls == 1, "hitl approve")

    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("c1", "echo", %{"value" => "original"})
      ])),
      Models.response(Models.message_assistant("done"))
    ])
    parent = self()
    options = %{Agent.new_agent_options(model) |
      tools: [Agent.new_tool("echo", "Echo", fn arguments -> arguments end)],
      policy: fn action ->
        if action.kind == "tool.invoke", do: send(parent, {:hitl_auth, action})
        Models.decision(true)
      end,
      interrupt_on: ["echo"],
      on_interrupt_decision: fn _interrupt ->
        %Praxo.InterruptDecision{action: "edit", arguments: %{"value" => "edited"}}
      end}
    {:ok, _, _} = Agent.run_agent(options, Models.session("s1"), "go")
    receive do {:hitl_auth, _} -> :ok after 0 -> raise "missing hitl authorization" end
    receive do {:hitl_auth, _} -> :ok after 0 -> raise "missing hitl reauthorization" end

    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("c1", "echo", %{"value" => "original"})
      ]))
    ])
    options = %{Agent.new_agent_options(model) |
      tools: [Agent.new_tool("echo", "Echo", fn arguments -> arguments end)],
      interrupt_on: ["echo"],
      on_interrupt_decision: fn _interrupt -> %Praxo.InterruptDecision{action: "reject"} end}
    {:error, "AGENT_APPROVAL_DENIED", _} = Agent.run_agent(options, Models.session("s1"), "go")

    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("c1", "echo", %{"value" => "original"})
      ]))
    ])
    options = %{Agent.new_agent_options(model) |
      tools: [Agent.new_tool("echo", "Echo", fn arguments -> arguments end)],
      interrupt_on: ["echo"]}
    {:error, "AGENT_INTERRUPT_UNHANDLED", _} = Agent.run_agent(options, Models.session("s1"), "go")

    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("c1", "echo", %{"value" => "original"})
      ])),
      Models.response(Models.message_assistant("done"))
    ])
    options = %{Agent.new_agent_options(model) |
      tools: [Agent.new_tool("echo", "Echo", fn arguments -> arguments end)],
      events: Sink.new(),
      interrupt_on: ["echo"],
      on_interrupt_decision: fn _interrupt -> %Praxo.InterruptDecision{action: "approve"} end}
    {:ok, _, options} = Agent.run_agent(options, Models.session("s1"), "go")
    check(Enum.count(options.events.kinds, &(&1 == "tool.interrupt")) == 1, "hitl event")
  end

  defp test_agent_capacity do
    options = %{Agent.new_agent_options(Agent.static_model("done")) |
      system_prompt: String.duplicate("x", 1000),
      context: Models.context_budget(10, 0),
      events: Sink.new()}
    {:error, "AGENT_CONTEXT_BUDGET", returned} = Agent.run_agent(options, Models.session("s1"), "go")
    check(returned.events.kinds == ["run.started", "run.failed"], "capacity fail-closed events")
  end
  defp test_openai_adapter do
    adapter =
      Praxo.OpenAICompatible.new(
        base_url: "http://example.test/v1",
        model: "test-model",
        transport: fn payload ->
          send(self(), {:adapter_payload, payload})

          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" => "hello",
                   "tool_calls" => [
                     %{
                       "id" => "c1",
                       "function" => %{"name" => "echo", "arguments" => "{\"text\":\"hi\"}"}
                     }
                   ]
                 },
                 "finish_reason" => "tool_calls"
               }
             ],
             "usage" => %{"prompt_tokens" => 3, "completion_tokens" => 2}
           }}
        end
      )

    request =
      Models.request(
        [%Praxo.Message{role: "user", content: "hi"}],
        [Models.tool_spec("echo", "echo")]
      )

    {:ok, response} = adapter.(request)
    check(response.message.content == "hello", "adapter content")
    [call] = response.message.tool_calls
    check(call.name == "echo" and call.arguments["text"] == "hi", "adapter tool call")
    check(response.usage.input_tokens == 3 and response.usage.output_tokens == 2, "adapter usage")

    receive do
      {:adapter_payload, payload} ->
        check(payload["model"] == "test-model", "adapter model")
        check(hd(payload["messages"])["role"] == "user", "adapter role")
        check(hd(payload["tools"])["function"]["name"] == "echo", "adapter tool")
    after
      1000 -> raise "adapter payload not captured"
    end
  end

  defp test_harmovela_sink do
    parent = self()

    transport = fn request ->
      send(parent, {:harmovela, request})
      {:ok, 201, ""}
    end

    sink =
      Praxo.HarmovelaSink.new(
        base_url: "http://harmovela.test/aep/api/",
        transport: transport
      )

    event = Models.event("tool.call", "s1", "run-123", %{"name" => "echo"})
    returned = Sink.emit(sink, event)
    check(is_struct(returned, Praxo.HarmovelaSink), "harmovela sink state")

    receive do
      {:harmovela, request} ->
        check(request.method == "POST", "harmovela method")
        check(request.url == "http://harmovela.test/aep/api/events", "harmovela path")
        check(request.headers["content-type"] == "application/json", "harmovela content type")
        envelope = Json.parse!(request.body)
        check(envelope["spec_version"] == "0.2", "harmovela spec")
        check(String.starts_with?(envelope["id"], "run-123-"), "harmovela id")
        check(envelope["type"] == "tool.call", "harmovela type")
        check(envelope["source"] == "praxo-core", "harmovela source")

        check(
          Regex.match?(~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}Z$/, envelope["created_at"]),
          "harmovela created_at"
        )

        payload = envelope["payload"]
        check(payload["name"] == "echo", "harmovela payload data")
        check(payload["session_id"] == "s1", "harmovela payload session")
        check(payload["run_id"] == "run-123", "harmovela payload run")
    after
      1000 -> raise "harmovela request not captured"
    end

    custom =
      Praxo.HarmovelaSink.new(
        base_url: "http://harmovela.test",
        source: "custom",
        spec_version: "0.3",
        transport: transport
      )

    merged =
      Models.event("tool.call", "s1", nil, %{
        "name" => "echo",
        "session_id" => "event-side",
        "run_id" => "old"
      })

    Sink.emit(custom, merged)

    receive do
      {:harmovela, request} ->
        envelope = Json.parse!(request.body)
        check(envelope["source"] == "custom", "harmovela custom source")
        check(envelope["spec_version"] == "0.3", "harmovela custom spec")
        check(String.starts_with?(envelope["id"], "s1-"), "harmovela session id")
        payload = envelope["payload"]
        check(payload["session_id"] == "s1", "harmovela session override")
        check(payload["run_id"] == "old", "harmovela data run retained")
    after
      1000 -> raise "harmovela merged request not captured"
    end

    for status <- [200, 201, 204, 299] do
      accepted =
        Praxo.HarmovelaSink.new(
          base_url: "http://harmovela.test",
          transport: fn _request -> {:ok, status, ""} end
        )

      Sink.emit(accepted, event)
    end

    failing =
      Praxo.HarmovelaSink.new(
        base_url: "http://harmovela.test",
        transport: fn _request ->
          {:ok, 503, String.duplicate("service down ", 100)}
        end
      )

    error =
      try do
        Sink.emit(failing, event)
        nil
      rescue
        error in Praxo.Error -> error
      end

    check(match?(%Praxo.Error{code: "HARMOVELA_HTTP"}, error), "harmovela error code")
    check(String.contains?(error.message, "503"), "harmovela error status")
    check(String.contains?(error.message, "service down"), "harmovela error body")
    check(String.length(error.message) <= 600, "harmovela bounded error")
  end

end

Praxo.Tests.run()
