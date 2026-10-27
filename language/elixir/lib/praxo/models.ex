defmodule Praxo.ContentBlock do
  defstruct kind: "text", text: nil, image_url: nil, data: nil
end

defmodule Praxo.ToolCall do
  defstruct id: "", name: "", arguments: %{}
end

defmodule Praxo.Message do
  defstruct role: "user", content: "", content_blocks: [], tool_calls: [], tool_id: nil
end

defmodule Praxo.ToolSpec do
  defstruct name: "", description: ""
end

defmodule Praxo.Usage do
  defstruct input_tokens: 0, output_tokens: 0
end

defmodule Praxo.Request do
  defstruct messages: [], tools: [], tool_choice: nil
end

defmodule Praxo.Response do
  defstruct message: %Praxo.Message{}, usage: %Praxo.Usage{}
end

defmodule Praxo.Session do
  defstruct id: "", messages: []
end

defmodule Praxo.RunResult do
  defstruct run_id: "", output: "", steps: 0, usage: %Praxo.Usage{}
end

defmodule Praxo.MemoryRecord do
  defstruct id: "", frame: "", content: "", created_at: nil
end

defmodule Praxo.PathGrant do
  defstruct root: "", access: "read"
end

defmodule Praxo.Decision do
  defstruct allowed: false, reason: ""
end

defmodule Praxo.Action do
  defstruct kind: "", session_id: "", tool_name: nil, arguments: %{}
end

defmodule Praxo.ContextBudget do
  defstruct max_tokens: 0, keep_recent: 0
end

defmodule Praxo.Event do
  defstruct kind: "", session_id: "", run_id: nil, data: :null
end

defmodule Praxo.Models do
  alias Praxo.{ContentBlock, Event, Message, MemoryRecord, PathGrant, Request, Response, RunResult, Session, ToolCall, ToolSpec, Usage}

  @roles %{system: "system", user: "user", assistant: "assistant", tool: "tool"}
  @stream_kinds ["values", "updates", "messages", "tasks", "debug", "checkpoint"]

  def roles, do: @roles
  def stream_kinds, do: @stream_kinds

  def content_block(kind, text), do: %ContentBlock{kind: kind, text: text}

  def tool_call(id, name, arguments \\ %{}) do
    %ToolCall{id: id, name: name, arguments: arguments}
  end

  def message(role, content), do: %Message{role: role, content: content}

  def message_assistant(content, tool_calls \\ []) do
    %Message{role: "assistant", content: content, tool_calls: tool_calls}
  end

  def message_tool(content, tool_id) do
    %Message{role: "tool", content: content, tool_id: tool_id}
  end

  def tool_spec(name, description), do: %ToolSpec{name: name, description: description}

  def usage(input_tokens \\ 0, output_tokens \\ 0) do
    %Usage{input_tokens: input_tokens, output_tokens: output_tokens}
  end

  def add_usage(left, right) do
    %Usage{
      input_tokens: left.input_tokens + right.input_tokens,
      output_tokens: left.output_tokens + right.output_tokens
    }
  end

  def request(messages, tools \\ []), do: %Request{messages: messages, tools: tools}

  def response(message, usage \\ %Usage{}) do
    %Response{message: message, usage: usage}
  end

  def session(id, messages \\ []), do: %Session{id: id, messages: messages}

  def run_result(run_id, output, steps, usage) do
    %RunResult{run_id: run_id, output: output, steps: steps, usage: usage}
  end

  def memory_record(id, frame, content, created_at \\ nil) do
    %MemoryRecord{id: id, frame: frame, content: content, created_at: created_at}
  end

  def path_grant(root, access \\ "read"), do: %PathGrant{root: root, access: access}

  def decision(allowed, reason \\ ""), do: %Praxo.Decision{allowed: allowed, reason: reason}

  def action(kind, session_id, tool_name \\ nil, arguments \\ %{}) do
    %Praxo.Action{kind: kind, session_id: session_id, tool_name: tool_name, arguments: arguments}
  end

  def context_budget(max_tokens, keep_recent) do
    %Praxo.ContextBudget{max_tokens: max_tokens, keep_recent: keep_recent}
  end

  def event(kind, session_id, run_id \\ nil, data \\ :null) do
    %Event{kind: kind, session_id: session_id, run_id: run_id, data: data}
  end

  def message_wire(%Message{} = value) do
    base = %{"role" => value.role}

    base =
      if value.content != "" or
           (value.content_blocks == [] and value.tool_calls == [] and value.tool_id == nil) do
        Map.put(base, "content", value.content)
      else
        base
      end

    base =
      if value.content_blocks != [] do
        blocks =
          Enum.map(value.content_blocks, fn block ->
            %{"type" => block.kind}
            |> maybe_put("text", block.text)
            |> maybe_put("image_url", block.image_url)
            |> maybe_put("data", block.data)
          end)

        Map.put(base, "contentBlocks", blocks)
      else
        base
      end

    base =
      if value.tool_calls != [] do
        calls =
          Enum.map(value.tool_calls, fn call ->
            %{
              "id" => call.id,
              "name" => call.name,
              "arguments" => call.arguments
            }
          end)

        Map.put(base, "toolCalls", calls)
      else
        base
      end

    if value.tool_id != nil, do: Map.put(base, "toolId", value.tool_id), else: base
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
