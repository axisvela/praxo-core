defmodule Praxo.Tool do
  defstruct name: "", description: "", calls: 0, invoke: nil
end

defmodule Praxo.Model do
  defstruct mode: :scripted, script: [], index: 0, content: "", primary: nil, fallback: nil
end

defmodule Praxo.Interrupt do
  defstruct run_id: "", session_id: "", call: nil
end

defmodule Praxo.InterruptDecision do
  defstruct action: "approve", arguments: nil, response: "", reason: ""
end

defmodule Praxo.AgentOptions do
  defstruct model: nil,
            tools: [],
            tool_selection: nil,
            pii: false,
            structured_output: nil,
            call_limit: nil,
            events: nil,
            system_prompt: "",
            context: nil,
            max_steps: 8,
            max_tokens: 0,
            session_id: "s1",
            policy: nil,
            middleware: [],
            allowed_tools: [],
            cancellation: nil,
            on_stream: nil,
            max_parallel_tools: 1,
            interrupt_on: [],
            on_interrupt_decision: nil,
            on_interrupt: nil,
            entered: []
end

defmodule Praxo.Agent do
  alias Praxo.{AgentOptions, Json, Middleware, Model, Models, Runtime, Sink, Tool, ToolSpec, Usage}

  def new_tool(name, description, invoke \\ nil) do
    invoke = invoke || fn arguments -> arguments end
    %Tool{name: name, description: description, invoke: invoke}
  end

  def call(%Tool{} = tool, arguments) do
    {%{tool | calls: tool.calls + 1}, tool.invoke.(arguments)}
  end

  def scripted_model(steps), do: %Model{mode: :scripted, script: steps}
  def static_model(content), do: %Model{mode: :static, content: content}
  def failing_model, do: %Model{mode: :failing}
  def fallback_model(primary, fallback), do: %Model{mode: :fallback, primary: primary, fallback: fallback}

  def generate(model, request) when is_function(model, 1) do
    case model.(request) do
      {:ok, response} -> {:ok, response, model}
      {:error, code} -> {:error, code, model}
    end
  end

  def generate(%Model{mode: :fallback, primary: primary, fallback: fallback} = model, request) do
    case generate(primary, request) do
      {:ok, response, primary} ->
        {:ok, response, %{model | primary: primary}}

      {:error, code, primary} ->
        model = %{model | primary: primary}
        if fallback == nil do
          {:error, code, model}
        else
          case generate(fallback, request) do
            {:ok, response, fallback} -> {:ok, response, %{model | fallback: fallback}}
            {:error, fallback_code, fallback} -> {:error, fallback_code, %{model | fallback: fallback}}
          end
        end
    end
  end

  def generate(%Model{mode: :static, content: content} = model, _request) do
    {:ok, Models.response(Models.message_assistant(content)), model}
  end

  def generate(%Model{mode: :failing} = model, _request) do
    {:error, "MODEL_ERROR", model}
  end

  def generate(%Model{mode: :scripted} = model, _request) do
    if model.index >= length(model.script) do
      {:error, "MODEL_ERROR", model}
    else
      response = Enum.at(model.script, model.index)
      {:ok, response, %{model | index: model.index + 1}}
    end
  end

  def new_agent_options(model) do
    %AgentOptions{model: model, max_steps: 8, session_id: "s1"}
  end

  def run_agent(%AgentOptions{} = options, session, prompt) do
    run_id = "run-#{System.system_time(:nanosecond)}-#{System.unique_integer([:positive, :monotonic])}"
    messages = session.messages ++ [Models.message("user", prompt)]

    messages =
      if options.system_prompt == "" do
        messages
      else
        [Models.message("system", options.system_prompt) | messages]
      end

    max_steps = if options.max_steps > 0, do: options.max_steps, else: 8
    limit = if options.call_limit == nil, do: nil, else: %{options.call_limit | models: 0, tools: 0}

    case before_run(options, run_id, prompt) do
      {:error, error, options} ->
        _ = after_run(options, nil, Exception.message(error))
        {:error, Exception.message(error), options}

      {:ok, options} ->
        options = emit(options, "run.started")

        case emit_stream(options, run_id, "values", 0, prompt) do
          :ok ->
            case compact(options, messages) do
              {:ok, messages} ->
                case loop(options, messages, run_id, 1, max_steps, %Usage{}, limit) do
                  {:ok, result, options} ->
                    case after_run(options, result, nil) do
                      nil ->
                        options = emit(options, "run.completed", run_id)
                        {:ok, result, options}

                      error ->
                        options = emit(options, "run.failed", run_id, %{"error" => Exception.message(error)})
                        {:error, Exception.message(error), options}
                    end

                  other ->
                    other
                end

              {:error, code} ->
                fail(options, run_id, code)
            end

          {:error, code} ->
            fail(options, run_id, code)
        end
    end
  end

  defp before_run(options, run_id, prompt) do
    Enum.reduce_while(options.middleware, {:ok, %{options | entered: []}}, fn middleware, {:ok, acc} ->
      acc = %{acc | entered: acc.entered ++ [middleware]}
      try do
        if middleware[:before_run], do: middleware.before_run.(%{run_id: run_id, prompt: prompt})
        {:cont, {:ok, acc}}
      rescue
        error -> {:halt, {:error, error, acc}}
      end
    end)
  end

  defp after_run(options, result, error) do
    Enum.reduce(options.entered, nil, fn middleware, first ->
      if middleware[:after_run] do
        try do
          middleware.after_run.(result, error)
          first
        rescue
          caught -> first || caught
        end
      else
        first
      end
    end)
  end

  defp compact(%AgentOptions{context: nil}, messages), do: {:ok, messages}

  defp compact(%AgentOptions{context: budget}, messages) do
    case Runtime.compact_context(budget, messages) do
      {compacted, true} -> {:ok, compacted}
      {_compacted, false} -> {:error, "AGENT_CONTEXT_BUDGET"}
    end
  end

  defp loop(options, messages, run_id, step, max_steps, total, limit) do
    case check_cancelled(options) do
      {:error, code} ->
        fail(options, run_id, code)

      :ok ->
        if step > max_steps do
          fail(options, run_id, "AGENT_MAX_STEPS")
        else
          specs = tool_specs(options.tools)
          specs = if options.tool_selection == nil, do: specs, else: Middleware.select_tools(options.tool_selection, specs)
          request_messages = if options.pii, do: Enum.map(messages, &redact_message/1), else: messages
          request = Models.request(request_messages, specs)

          case check_model_limit(limit) do
            {:error, code, _limit} -> fail(options, run_id, code)
            {:ok, limit} -> run_model(options, messages, request, run_id, step, max_steps, total, limit)
          end
        end
    end
  end

  defp run_model(options, messages, request, run_id, step, max_steps, total, limit) do
    case generate(options.model, request) do
      {:error, code, model} ->
        fail(%{options | model: model}, run_id, code)

      {:ok, response, model} ->
        options = %{options | model: model}

        case check_cancelled(options) do
          {:error, code} ->
            fail(options, run_id, code)

          :ok ->
            total = Models.add_usage(total, response.usage)

            if options.max_tokens > 0 and total.input_tokens + total.output_tokens > options.max_tokens do
              fail(options, run_id, "AGENT_MAX_TOKENS")
            else
              messages = messages ++ [response.message]

              if response.message.tool_calls == [] do
                output = response.message.content
                validated = if options.structured_output == nil, do: {:ok, output}, else: Middleware.apply_structured(options.structured_output, output)

                case validated do
                  {:ok, output} ->
                    case emit_stream(options, run_id, "messages", step, output) do
                      :ok -> {:ok, Models.run_result(run_id, output, step, total), options}
                      {:error, code} -> fail(options, run_id, code)
                    end

                  {:error, code} when is_binary(code) ->
                    fail(options, run_id, code)

                  {:error, error} ->
                    options = emit(options, "run.failed", run_id, %{"error" => "AGENT_STRUCTURED_OUTPUT"})
                    {:error, error, options}
                end
              else
                case invoke_tools(options, response.message.tool_calls, messages, run_id, limit) do
                  {:ok, options, messages, limit} ->
                    loop(options, messages, run_id, step + 1, max_steps, total, limit)

                  {:error, code, options} ->
                    {:error, code, options}
                end
              end
            end
        end
    end
  end

  defp invoke_tools(options, calls, messages, run_id, limit) do
    parallel = if options.max_parallel_tools > 0, do: options.max_parallel_tools, else: 1
    process_tool_batches(options, calls, messages, run_id, limit, parallel)
  end

  defp process_tool_batches(options, [], messages, _run_id, limit, _parallel) do
    {:ok, options, messages, limit}
  end

  defp process_tool_batches(options, calls, messages, run_id, limit, parallel) do
    case check_cancelled(options) do
      {:error, code} ->
        tool_fail(options, run_id, code)

      :ok ->
        {batch, rest} = Enum.split(calls, parallel)

        case prepare_batch(options, batch, run_id, limit) do
          {:ok, prepared, options, limit} ->
            case execute_batch(options, prepared, messages, parallel) do
              {:ok, options, messages} ->
                case check_cancelled(options) do
                  {:error, code} -> tool_fail(options, run_id, code)
                  :ok -> process_tool_batches(options, rest, messages, run_id, limit, parallel)
                end

              error ->
                error
            end

          error ->
            error
        end
    end
  end

  defp prepare_batch(options, calls, run_id, limit) do
    Enum.reduce_while(calls, {:ok, [], options, limit}, fn call, {:ok, prepared, options, limit} ->
      case prepare_tool(options, call, run_id, limit) do
        {:ok, options, item, limit} ->
          {:cont, {:ok, prepared ++ [item], options, limit}}

        {:error, code, options} ->
          {:halt, {:error, code, options}}
      end
    end)
  end

  defp prepare_tool(options, call, run_id, limit) do
    original_name = call.name
    original_arguments = call.arguments

    cond do
      not allowed?(options, original_name) ->
        tool_fail(options, run_id, "AGENT_TOOL_NOT_ALLOWED")

      authorize(options, Models.action("tool.invoke", options.session_id, original_name, original_arguments)) != :ok ->
        tool_fail(options, run_id, "AGENT_POLICY_DENIED")

      true ->
        active =
          Enum.reduce(options.middleware, call, fn middleware, current ->
            if middleware[:before_tool], do: middleware.before_tool.(current), else: current
          end)

        case apply_interrupt(options, active, run_id) do
          {:error, options, code} ->
            tool_fail(options, run_id, code)

          {:skip, options, call, value} ->
            {:ok, options, {nil, interrupt_tool(value), call}, limit}

          {:continue, options, active} ->
            cond do
              not allowed?(options, active.name) ->
                tool_fail(options, run_id, "AGENT_TOOL_NOT_ALLOWED")

              active.name != original_name or active.arguments != original_arguments ->
                if authorize(options, Models.action("tool.invoke", options.session_id, active.name, active.arguments)) != :ok do
                  tool_fail(options, run_id, "AGENT_POLICY_DENIED")
                else
                  prepare_selected_tool(options, active, run_id, limit)
                end

              true ->
                prepare_selected_tool(options, active, run_id, limit)
            end
        end
    end
  end

  defp interrupt_tool(value) do
    %Tool{
      name: "interrupt.response",
      description: "interrupt response",
      invoke: fn _arguments -> value end
    }
  end

  defp apply_interrupt(options, call, run_id) do
    if call.name not in options.interrupt_on do
      {:continue, options, call}
    else
      if options.on_interrupt_decision == nil and options.on_interrupt == nil do
        {:error, options, "AGENT_INTERRUPT_UNHANDLED"}
      else
        options = emit(options, "tool.interrupt", run_id,
                       %{"name" => call.name, "arguments" => call.arguments})
        interrupt = %Praxo.Interrupt{
          run_id: run_id,
          session_id: options.session_id,
          call: call
        }
        cond do
          options.on_interrupt_decision != nil ->
            decision = options.on_interrupt_decision.(interrupt)
            case decision.action do
              "approve" ->
                {:continue, options, call}

              "edit" ->
                if decision.arguments == nil do
                  {:error, options, "AGENT_INTERRUPT_DECISION_INVALID"}
                else
                  {:continue, options, %{call | arguments: decision.arguments}}
                end

              "reject" ->
                {:error, options, "AGENT_APPROVAL_DENIED"}

              "respond" ->
                {:skip, options, call, decision.response}

              _ ->
                {:error, options, "AGENT_INTERRUPT_DECISION_INVALID"}
            end

          true ->
            if options.on_interrupt.(interrupt) do
              {:continue, options, call}
            else
              {:error, options, "AGENT_APPROVAL_DENIED"}
            end
        end
      end
    end
  end

  defp prepare_selected_tool(options, call, run_id, limit) do
    index = Enum.find_index(options.tools, fn tool -> tool.name == call.name end)
    selection = if options.tool_selection == nil, do: :ok, else: Middleware.check_tool_selected(options.tool_selection, call.name)

    cond do
      selection != :ok ->
        {:error, code} = selection
        tool_fail(options, run_id, code)

      index == nil ->
        tool_fail(options, run_id, "TOOL_NOT_FOUND")

      true ->
        case check_tool_limit(limit) do
          {:error, code, _limit} ->
            tool_fail(options, run_id, code)

          {:ok, limit} ->
            tool = Enum.at(options.tools, index)
            options = emit(options, "tool.call", run_id, %{"name" => call.name, "arguments" => call.arguments})
            {:ok, options, {index, tool, call}, limit}
        end
    end
  end

  defp execute_batch(options, prepared, messages, 1) do
    Enum.reduce(prepared, {:ok, options, messages}, fn {index, tool, tool_call}, {:ok, options, messages} ->
      {updated, value} = call(tool, tool_call.arguments)
      options =
        if index == nil do
          options
        else
          %{options | tools: List.replace_at(options.tools, index, updated)}
        end
      value = if options.pii, do: Middleware.redact_value(value), else: value
      messages = messages ++ [Models.message_tool(Json.encode(value), tool_call.id)]
      {:ok, options, messages}
    end)
  end

  defp execute_batch(options, prepared, messages, _parallel) do
    tasks =
      Enum.map(prepared, fn {index, tool, tool_call} ->
        {index, tool_call, Task.async(fn -> call(tool, tool_call.arguments) end)}
      end)

    Enum.reduce(tasks, {:ok, options, messages}, fn {index, tool_call, task}, {:ok, options, messages} ->
      {updated, value} = Task.await(task, 30_000)
      options =
        if index == nil do
          options
        else
          %{options | tools: List.replace_at(options.tools, index, updated)}
        end
      value = if options.pii, do: Middleware.redact_value(value), else: value
      messages = messages ++ [Models.message_tool(Json.encode(value), tool_call.id)]
      {:ok, options, messages}
    end)
  end

  defp tool_fail(options, run_id, code) do
    {:error, error_code, options} = fail(options, run_id, code)
    {:error, error_code, options}
  end

  defp allowed?(options, name) do
    options.allowed_tools == [] or name in options.allowed_tools
  end

  defp authorize(%AgentOptions{policy: nil}, _action), do: :ok
  defp authorize(options, action) do
    case options.policy.(action) do
      %{allowed: true} -> :ok
      _ -> :error
    end
  end

  defp check_model_limit(nil), do: {:ok, nil}
  defp check_model_limit(limit), do: Middleware.model_call(limit)
  defp check_tool_limit(nil), do: {:ok, nil}
  defp check_tool_limit(limit), do: Middleware.tool_call(limit)

  defp redact_message(message) do
    blocks = Enum.map(message.content_blocks, fn block ->
      %{block | text: if(is_binary(block.text), do: Middleware.pii_redact(block.text), else: block.text)}
    end)
    tool_calls = Enum.map(message.tool_calls, fn call ->
      %{call | arguments: Middleware.redact_value(call.arguments)}
    end)
    %{message | content: Middleware.pii_redact(message.content), content_blocks: blocks, tool_calls: tool_calls}
  end

  defp tool_specs(tools) do
    Enum.map(tools, fn tool -> %ToolSpec{name: tool.name, description: tool.description} end)
  end

  defp emit(options, kind, run_id \\ nil, data \\ :null) do
    if options.events == nil do
      options
    else
      event = Models.event(kind, options.session_id, run_id, data)
      sink = Sink.emit(options.events, event)
      %{options | events: sink}
    end
  end

  defp check_cancelled(%AgentOptions{cancellation: nil}), do: :ok
  defp check_cancelled(options) do
    cancelled =
      cond do
        is_function(options.cancellation, 0) -> options.cancellation.()
        is_function(options.cancellation, 1) -> options.cancellation.(options)
        true -> options.cancellation
      end

    if cancelled, do: {:error, "AGENT_CANCELLED"}, else: :ok
  end

  defp emit_stream(%AgentOptions{on_stream: nil}, _run_id, _kind, _step, _data), do: :ok
  defp emit_stream(options, run_id, kind, step, data) do
    part = Models.stream_part(run_id, options.session_id, kind, step, data)

    try do
      options.on_stream.(part)
      :ok
    rescue
      _error -> {:error, "STREAM_ERROR"}
    end
  end

  defp fail(options, run_id, code) do
    _ = after_run(options, nil, code)
    options = emit(options, "run.failed", run_id, %{"error" => code})
    {:error, code, options}
  end
end
