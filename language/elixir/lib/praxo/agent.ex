defmodule Praxo.Tool do
  defstruct name: "", description: "", calls: 0, invoke: nil
end

defmodule Praxo.Model do
  defstruct mode: :scripted, script: [], index: 0, content: "", primary: nil, fallback: nil
end

defmodule Praxo.AgentOptions do
  defstruct model: nil,
            tools: [],
            events: nil,
            system_prompt: "",
            max_steps: 8,
            max_tokens: 0,
            session_id: "s1"
end

defmodule Praxo.Agent do
  alias Praxo.{AgentOptions, Json, Model, Models, Sink, Tool, ToolSpec, Usage}

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
    run_id = "run-#{System.system_time(:second)}"
    messages = session.messages ++ [Models.message("user", prompt)]

    messages =
      if options.system_prompt == "" do
        messages
      else
        [Models.message("system", options.system_prompt) | messages]
      end

    max_steps = if options.max_steps > 0, do: options.max_steps, else: 8
    loop(options, messages, run_id, 1, max_steps, %Usage{})
  end

  defp loop(options, messages, run_id, step, max_steps, total) do
    if step > max_steps do
      fail(options, run_id, "AGENT_MAX_STEPS")
    else
      request = Models.request(messages, tool_specs(options.tools))

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
              options = emit(options, "run.completed", run_id)
              result = Models.run_result(run_id, response.message.content, step, total)
              {:ok, result, options}
            else
              case invoke_tools(options, response.message.tool_calls, messages, run_id) do
                {:ok, options, messages} ->
                  loop(options, messages, run_id, step + 1, max_steps, total)

                {:error, code, options} ->
                  {:error, code, options}
              end
            end
          end
      end
    end
  end

  defp invoke_tools(options, calls, messages, run_id) do
    Enum.reduce_while(calls, {:ok, options, messages}, fn tool_call, {:ok, options, messages} ->
      index = Enum.find_index(options.tools, fn tool -> tool.name == tool_call.name end)

      if index == nil do
        options = emit(options, "run.failed", run_id, %{"error" => "tool not found"})
        {:halt, {:error, "TOOL_NOT_FOUND", options}}
      else
        tool = Enum.at(options.tools, index)
        options = emit(options, "tool.call", run_id, %{"name" => tool_call.name, "arguments" => tool_call.arguments})
        {tool, value} = call(tool, tool_call.arguments)
        options = %{options | tools: List.replace_at(options.tools, index, tool)}
        messages = messages ++ [Models.message_tool(Json.encode(value), tool_call.id)]
        {:cont, {:ok, options, messages}}
      end
    end)
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
