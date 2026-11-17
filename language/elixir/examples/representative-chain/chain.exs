defmodule RepresentativeChain do
  alias Praxo.{Agent, Json, Mcp, Models, Sink}

  def run do
    events = new_log()
    transport = fake_transport(events.effects)
    {:ok, client} = Mcp.connect(transport: transport)

    try do
      {:ok, tools} = Mcp.tools(client)
      record = Enum.find(tools, fn tool -> tool.name == "record" end)
      parent_counter = :atomics.new(1, [])
      child_counter = :atomics.new(1, [])
      child_model = model(child_steps(), child_counter)
      parent_model = model(parent_steps(), parent_counter)
      sinks = sinks(events)
      delegate = delegate_tool(record, child_model, sinks)

      options = %{
        Agent.new_agent_options(parent_model)
        | tools: [record, delegate],
          max_steps: 6,
          allowed_tools: ["record", "delegate"],
          policy: &parent_policy/1,
          require_policy: true,
          require_tool_scope: true,
          events: sinks
      }

      {:ok, result, _options} =
        Agent.run_agent(options, Models.session("chain-parent"), "run the representative chain")

      chain = %{
        output: result.output,
        parent: effect(events.effects, "parent"),
        child: effect(events.effects, "child"),
        child_calls: :atomics.get(child_counter, 1),
        otel: entries(events.otel),
        harmovela: entries(events.harmovela)
      }

      denial = run_denial(events.effects)

      check(chain.output == "DONE", "parent output was not DONE")
      check(chain.parent == 1, "parent effect count was not one")
      check(chain.child == 1, "child effect count was not one")
      check(chain.child_calls >= 2, "child model calls were fewer than two")

      for span <- ["praxo.run.started", "praxo.tool.call", "praxo.run.completed"] do
        check(span in chain.otel, "missing otel span #{span}")
      end

      for kind <- ["run.started", "tool.call", "run.completed"] do
        check(kind in chain.harmovela, "missing harmovela event #{kind}")
      end

      check(denial.blocked == 0, "denied target produced an effect")
      check(denial.code == "AGENT_POLICY_DENIED", "denial code was not AGENT_POLICY_DENIED")

      IO.puts("output: #{chain.output}")
      IO.puts("effects: parent=#{chain.parent} child=#{chain.child}")
      IO.puts("child calls: #{chain.child_calls}")
      IO.puts("otel spans: #{length(chain.otel)}")
      IO.puts("harmovela events: #{length(chain.harmovela)}")
      IO.puts("denied effects: #{denial.blocked}")
      :ok
    after
      Mcp.close(client)
    end
  end

  defp run_denial(effects) do
    transport = fake_transport(effects)
    {:ok, client} = Mcp.connect(transport: transport)

    try do
      {:ok, tools} = Mcp.tools(client)
      record = Enum.find(tools, fn tool -> tool.name == "record" end)
      model = model(denial_steps(), :atomics.new(1, []))

      middleware = [
        %{
          before_tool: fn call ->
            %{call | arguments: Map.put(call.arguments, "target", "blocked")}
          end
        }
      ]

      options = %{
        Agent.new_agent_options(model)
        | tools: [record],
          max_steps: 2,
          allowed_tools: ["record"],
          policy: &parent_policy/1,
          middleware: middleware,
          require_policy: true,
          require_tool_scope: true
      }

      case Agent.run_agent(options, Models.session("chain-denial"), "call record") do
        {:error, code, _options} ->
          %{blocked: effect(effects, "blocked"), code: code}

        {:ok, _result, _options} ->
          raise "denial path unexpectedly succeeded"
      end
    after
      Mcp.close(client)
    end
  end

  defp delegate_tool(record, child_model, sinks) do
    agent_tool =
      Agent.new_tool(
        "delegate",
        "Run a governed child agent with the narrowed record scope.",
        fn _arguments ->
          options = %{
            Agent.new_agent_options(child_model)
            | tools: [record],
              max_steps: 3,
              allowed_tools: ["record"],
              policy: composed_policy(),
              require_policy: true,
              require_tool_scope: true,
              events: sinks
          }

          case Agent.run_agent(options, Models.session("chain-child"), "record child") do
            {:ok, result, _options} -> %{"output" => result.output}
            {:error, code, _options} -> raise "child run failed: #{code}"
          end
        end
      )

    %{
      agent_tool
      | parameters: %{
          "type" => "object",
          "properties" => %{"task" => %{"type" => "string"}},
          "required" => ["task"]
        }
    }
  end

  defp composed_policy do
    fn action ->
      case parent_policy(action) do
        %{allowed: true} -> child_policy(action)
        decision -> decision
      end
    end
  end

  defp parent_policy(action) do
    cond do
      action.kind == "model.generate" ->
        Models.decision(true, "model")

      action.kind != "tool.invoke" ->
        Models.decision(false, "unsupported action")

      action.tool_name == "record" ->
        if Map.get(action.arguments, "target") == "blocked" do
          Models.decision(false, "blocked target")
        else
          Models.decision(true, "record")
        end

      action.tool_name == "delegate" ->
        Models.decision(true, "delegate")

      true ->
        Models.decision(false, "parent tool is not allowed")
    end
  end

  defp child_policy(action) do
    cond do
      action.kind == "model.generate" -> Models.decision(true, "model")
      action.kind == "tool.invoke" and action.tool_name == "record" -> Models.decision(true, "child record")
      true -> Models.decision(false, "child may only record")
    end
  end

  defp model(steps, counter) do
    fn _request ->
      index = :atomics.add_get(counter, 1, 1) - 1
      step = Enum.at(steps, min(index, length(steps) - 1))
      {:ok, step}
    end
  end

  defp parent_steps do
    [
      Models.response(
        Models.message_assistant("", [
          Models.tool_call("parent-record", "record", %{"target" => "parent"})
        ])
      ),
      Models.response(
        Models.message_assistant("", [
          Models.tool_call("parent-delegate", "delegate", %{"task" => "child"})
        ])
      ),
      Models.response(Models.message_assistant("DONE"))
    ]
  end

  defp child_steps do
    [
      Models.response(
        Models.message_assistant("", [
          Models.tool_call("child-record", "record", %{"target" => "child"})
        ])
      ),
      Models.response(Models.message_assistant("CHILD-DONE"))
    ]
  end

  defp denial_steps do
    [
      Models.response(
        Models.message_assistant("", [
          Models.tool_call("denied-record", "record", %{"target" => "safe"})
        ])
      ),
      Models.response(Models.message_assistant("UNEXPECTED"))
    ]
  end

  defp fake_transport(effects) do
    %{
      request: fn method, params, _timeout ->
        case method do
          "initialize" ->
            {:ok,
             %{
               "protocolVersion" => "2024-11-05",
               "capabilities" => %{"tools" => %{}},
               "serverInfo" => %{"name" => "fixture-mcp", "version" => "0.0.1"}
             }}

          "tools/list" ->
            {:ok,
             %{
               "tools" => [
                 %{
                   "name" => "record",
                   "description" => "Record a target",
                   "inputSchema" => %{
                     "type" => "object",
                     "properties" => %{"target" => %{"type" => "string"}},
                     "required" => ["target"]
                   }
                 }
               ]
             }}

          "tools/call" ->
            call_tool(effects, params)

          _ ->
            {:error, %Praxo.Error{code: "MCP_RPC", message: "mcp: #{method} failed"}}
        end
      end,
      notify: fn _method, _params -> :ok end,
      close: fn -> :ok end
    }
  end

  defp call_tool(effects, params) do
    case params do
      %{"name" => "record", "arguments" => arguments} ->
        target = Map.get(arguments, "target", "")
        :ets.update_counter(effects, target, {2, 1}, {target, 0})

        {:ok,
         %{
           "content" => [%{"type" => "text", "text" => "recorded:#{target}"}]
         }}

      _ ->
        {:ok,
         %{
           "isError" => true,
           "content" => [%{"type" => "text", "text" => "unknown tool"}]
         }}
    end
  end

  defp sinks(events) do
    Sink.multi([
      Praxo.OtelSink.new(transport: fn request -> record_otel(events.otel, request) end),
      Praxo.HarmovelaSink.new(
        base_url: "http://harmovela.local",
        transport: fn request -> record_harmovela(events.harmovela, request) end
      )
    ])
  end

  defp record_otel(log, request) do
    payload = Json.parse!(request.body)

    for resource <- payload["resourceSpans"] || [],
        scope <- resource["scopeSpans"] || [],
        span <- scope["spans"] || [] do
      :ets.insert(log, {span["name"]})
    end

    {:ok, 200, ""}
  end

  defp record_harmovela(log, request) do
    payload = Json.parse!(request.body)
    :ets.insert(log, {payload["type"]})
    {:ok, 202, ""}
  end

  defp new_log do
    %{
      effects: :ets.new(:chain_effects, [:set, :public]),
      otel: :ets.new(:chain_otel, [:duplicate_bag, :public]),
      harmovela: :ets.new(:chain_harmovela, [:duplicate_bag, :public])
    }
  end

  defp effect(table, target) do
    case :ets.lookup(table, target) do
      [{^target, count}] -> count
      [] -> 0
    end
  end

  defp entries(table) do
    table |> :ets.tab2list() |> Enum.map(fn {value} -> value end)
  end

  defp check(true, _message), do: :ok
  defp check(false, message), do: raise(message)
end

RepresentativeChain.run()
