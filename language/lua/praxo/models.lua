local M = {}

M.SYSTEM = "system"
M.USER = "user"
M.ASSISTANT = "assistant"
M.TOOL = "tool"
M.STREAM_KINDS = { "values", "updates", "messages", "tasks", "debug", "checkpoint" }

function M.content_block(args)
  args = args or {}
  return {
    type = args.type or "text",
    text = args.text,
    image_url = args.image_url,
    data = args.data,
  }
end

function M.tool_call(args)
  args = args or {}
  return {
    id = args.id or "",
    name = args.name or "",
    arguments = args.arguments or {},
  }
end

function M.message(args)
  args = args or {}
  return {
    role = args.role or M.USER,
    content = args.content,
    content_blocks = args.content_blocks or {},
    tool_calls = args.tool_calls or {},
    tool_id = args.tool_id,
  }
end

function M.message_text(role, content)
  return M.message({ role = role, content = content })
end

function M.message_assistant(content, tool_calls)
  return M.message({ role = M.ASSISTANT, content = content, tool_calls = tool_calls or {} })
end

function M.message_tool(content, tool_id)
  return M.message({ role = M.TOOL, content = content, tool_id = tool_id })
end

function M.tool_spec(args)
  args = args or {}
  return {
    name = args.name or "",
    description = args.description or "",
    parameters = args.parameters,
    risk = args.risk,
  }
end

function M.usage(args)
  args = args or {}
  return {
    input_tokens = args.input_tokens or 0,
    output_tokens = args.output_tokens or 0,
    cached_tokens = args.cached_tokens or 0,
  }
end

function M.usage_plus(left, right)
  return M.usage({
    input_tokens = (left.input_tokens or 0) + (right.input_tokens or 0),
    output_tokens = (left.output_tokens or 0) + (right.output_tokens or 0),
    cached_tokens = (left.cached_tokens or 0) + (right.cached_tokens or 0),
  })
end

function M.request(args)
  args = args or {}
  return {
    messages = args.messages or {},
    tools = args.tools or {},
    tool_choice = args.tool_choice,
    response_format = args.response_format,
    temperature = args.temperature or 0,
  }
end

function M.response(args)
  args = args or {}
  return {
    message = args.message,
    usage = args.usage or M.usage(),
    finish_reason = args.finish_reason,
  }
end

function M.session(args)
  args = args or {}
  return { id = args.id or "", messages = args.messages or {} }
end

function M.run_result(args)
  args = args or {}
  return {
    run_id = args.run_id or "",
    output = args.output or "",
    steps = args.steps or 0,
    usage = args.usage or M.usage(),
  }
end

function M.memory_record(args)
  args = args or {}
  return {
    id = args.id or "",
    frame = args.frame or "",
    content = args.content or "",
    created_at = args.created_at,
  }
end

function M.path_grant(args)
  args = args or {}
  return { root = args.root or "", access = args.access or "read" }
end

function M.action(args)
  args = args or {}
  return {
    kind = args.kind or "",
    session_id = args.session_id or "",
    tool_name = args.tool_name,
    arguments = args.arguments,
  }
end

function M.decision(args)
  args = args or {}
  return { allowed = args.allowed and true or false, reason = args.reason or "" }
end

function M.event(args)
  args = args or {}
  return {
    type = args.type or "",
    session_id = args.session_id or "",
    run_id = args.run_id,
    data = args.data,
  }
end

function M.message_wire(message)
  local out = { role = message.role }
  if message.content ~= nil then out.content = message.content end
  if message.content_blocks and #message.content_blocks > 0 then
    out.contentBlocks = {}
    for index, block in ipairs(message.content_blocks) do
      local wire = { type = block.type }
      if block.text ~= nil then wire.text = block.text end
      if block.image_url ~= nil then wire.image_url = block.image_url end
      if block.data ~= nil then wire.data = block.data end
      out.contentBlocks[index] = wire
    end
  end
  if message.tool_calls and #message.tool_calls > 0 then
    out.toolCalls = {}
    for index, call in ipairs(message.tool_calls) do
      out.toolCalls[index] = {
        id = call.id,
        name = call.name,
        arguments = call.arguments,
      }
    end
  end
  if message.tool_id ~= nil then out.toolId = message.tool_id end
  return out
end

return M
