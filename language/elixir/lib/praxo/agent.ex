defmodule Praxo.Tool do
  defstruct name: "", description: "", calls: 0, invoke: nil
end

defmodule Praxo.Model do
  defstruct mode: :scripted, script: [], index: 0, content: "", primary: nil, fallback: nil
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
            max_steps: 8,
            max_tokens: 0,
            session_id: "s1"
end

defmodule Praxo.Agent do
  alias Praxo.{AgentOptions, Json, Middleware, Model, Models, Sink, Tool, ToolSpec, Usage}

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
    options = emit(options, "run.started")
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
    loop(options, messages, run_id, 1, max_steps, %Usage{}, limit)
  end

  defp loop(options, messages, run_id, step, max_steps, total, limit) do
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

  defp run_model(options, messages, request, run_id, step, max_steps, total, limit) do
      case generate(options.model, request) do
        {:error, code, model} ->
          fail(%{options | model: model}, run_id, code)

        {:ok, response, model} ->
          options = %{options | model: model}
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
                  options = emit(options, "run.completed", run_id)
                  {:ok, Models.run_result(run_id, output, step, total), options}
                {:error, code} when is_binary(code) -> fail(options, run_id, code)
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

  defp invoke_tools(options, calls, messages, run_id, limit) do
    Enum.reduce_while(calls, {:ok, options, messages, limit}, fn tool_call, {:ok, options, messages, limit} ->
      index = Enum.find_index(options.tools, fn tool -> tool.name == tool_call.name end)

      selection = if options.tool_selection == nil, do: :ok, else: Middleware.check_tool_selected(options.tool_selection, tool_call.name)

      cond do
        selection != :ok ->
          {:error, code} = selection
          {:error, code, options} = fail(options, run_id, code)
          {:halt, {:error, code, options}}

        index == nil ->
          options = emit(options, "run.failed", run_id, %{"error" => "tool not found"})
          {:halt, {:error, "TOOL_NOT_FOUND", options}}

        true ->
          case check_tool_limit(limit) do
            {:error, code, _limit} ->
              {:error, code, options} = fail(options, run_id, code)
              {:halt, {:error, code, options}}
            {:ok, limit} ->
              tool = Enum.at(options.tools, index)
              options = emit(options, "tool.call", run_id, %{"name" => tool_call.name, "arguments" => tool_call.arguments})
              {tool, value} = call(tool, tool_call.arguments)
              options = %{options | tools: List.replace_at(options.tools, index, tool)}
              value = if options.pii, do: Middleware.redact_value(value), else: value
              messages = messages ++ [Models.message_tool(Json.encode(value), tool_call.id)]
              {:cont, {:ok, options, messages, limit}}
          end
      end
    end)
  end

  defp check_model_limit(nil), do: {:ok, nil}
  defp check_model_limit(limit), do: Middleware.model_call(limit)
  defp check_tool_limit(nil), do: {:ok, nil}
  defp check_tool_limit(limit), do: Middleware.tool_call(limit)

  defp redact_message(message) do
    blocks = Enum.map(message.content_blocks, fn block ->
      %{block | text: if(is_binary(block.text), do: Middleware.pii_redact(block.text), else: block.text)}
    end)
    %{message | content: Middleware.pii_redact(message.content), content_blocks: blocks}
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

  defp fail(options, run_id, code) do
    options = emit(options, "run.failed", run_id, %{"error" => code})
    {:error, code, options}
  end
end
