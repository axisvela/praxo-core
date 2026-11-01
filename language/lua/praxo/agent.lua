local errors = require("praxo.errors")
local json = require("praxo.json")
local models = require("praxo.models")
local runtime = require("praxo.runtime")

local M = {}

function M.func_tool(name, description, func)
  return { name = name, description = description, invoke = func }
end

function M.tool_registry()
  return { tools = {} }
end

function M.register_tool(registry, tool)
  registry.tools[tool.name] = tool
  return tool
end

function M.get_tool(registry, name)
  if not registry.tools[name] then
    errors.raise("TOOL_NOT_FOUND", "tool not found: " .. name)
  end
  return registry.tools[name]
end

function M.tool_specs(registry)
  local out = {}
  for _, tool in pairs(registry.tools) do
    out[#out + 1] = models.tool_spec({ name = tool.name, description = tool.description })
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function M.static_model(content)
  return {
    generate = function(_request)
      return models.response({ message = models.message_assistant(content or "") })
    end,
  }
end

function M.agent_options(model)
  return {
    model = model,
    tools = nil,
    events = nil,
    policy = nil,
    system_prompt = "",
    context = nil,
    max_steps = 8,
    max_tokens = 0,
    tool_choice = nil,
    middleware = {},
    allowed_tools = {},
    cancellation = nil,
    on_stream = nil,
    max_parallel_tools = 1,
    batch_invoke = nil,
  }
end

local function emit(options, event_type, session_id, run_id, data)
  if not options.events then return end
  options.events.emit(models.event({
    type = event_type, session_id = session_id, run_id = run_id, data = data,
  }))
end

local function authorize(options, action)
  if not options.policy then return end
  local decision = options.policy(action)
  if not (decision and decision.allowed) then
    errors.raise("AGENT_POLICY_DENIED", "policy denied the action")
  end
end

local function allowed(options, name)
  if #(options.allowed_tools or {}) == 0 then return true end
  for _, item in ipairs(options.allowed_tools) do
    if item == name then return true end
  end
  return false
end

local invoke_tool

local function check_cancelled(options)
  if not options.cancellation then return end
  local cancelled = options.cancellation
  if type(cancelled) == "function" then cancelled = cancelled() end
  if cancelled then
    errors.raise("AGENT_CANCELLED", "run cancelled")
  end
end

local function emit_stream(options, run_id, session_id, kind, step, data)
  if not options.on_stream then return end
  local ok = pcall(options.on_stream, models.stream_part({
    run_id = run_id, session_id = session_id, kind = kind, step = step, data = data,
  }))
  if not ok then
    errors.raise("STREAM_ERROR", "stream callback failed")
  end
end

local function prepare_batch(options, calls, run_id, session_id)
  local prepared = {}
  for _, call in ipairs(calls) do
    local original_name = call.name
    local original_arguments = call.arguments
    if not allowed(options, original_name) then
      errors.raise("AGENT_TOOL_NOT_ALLOWED", "tool " .. original_name .. " is not allowed")
    end
    authorize(options, models.action({
      kind = "tool.invoke", session_id = session_id,
      tool_name = original_name, arguments = original_arguments,
    }))
    for _, middleware in ipairs(options.middleware or {}) do
      if middleware.before_tool then call = middleware.before_tool(call) or call end
    end
    if not allowed(options, call.name) then
      errors.raise("AGENT_TOOL_NOT_ALLOWED", "tool " .. call.name .. " is not allowed")
    end
    if call.name ~= original_name or call.arguments ~= original_arguments then
      authorize(options, models.action({
        kind = "tool.invoke", session_id = session_id,
        tool_name = call.name, arguments = call.arguments,
      }))
    end
    if not options.tools then errors.raise("TOOL_NOT_FOUND", "tool is not registered") end
    local tool = M.get_tool(options.tools, call.name)
    emit(options, "tool.call", session_id, run_id, {
      name = call.name, arguments = call.arguments or {},
    })
    prepared[#prepared + 1] = { tool = tool, call = call }
  end
  return prepared
end

local function invoke_tools(options, calls, run_id, session_id)
  if options.batch_invoke then
    local prepared = prepare_batch(options, calls, run_id, session_id)
    local results = options.batch_invoke(prepared, options.max_parallel_tools or 1)
    local messages_out = {}
    for index, entry in ipairs(prepared) do
      messages_out[#messages_out + 1] = models.message_tool(
        json.encode(results[index]), entry.call.id or ""
      )
    end
    return messages_out
  end
  local messages_out = {}
  for _, call in ipairs(calls) do
    check_cancelled(options)
    messages_out[#messages_out + 1] = invoke_tool(options, call, run_id, session_id)
    check_cancelled(options)
  end
  return messages_out
end

invoke_tool = function(options, call, run_id, session_id)
  local original_name = call.name
  local original_arguments = call.arguments
  if not allowed(options, original_name) then
    errors.raise("AGENT_TOOL_NOT_ALLOWED", "tool " .. original_name .. " is not allowed")
  end
  authorize(options, models.action({
    kind = "tool.invoke", session_id = session_id,
    tool_name = original_name, arguments = original_arguments,
  }))
  for _, middleware in ipairs(options.middleware or {}) do
    if middleware.before_tool then call = middleware.before_tool(call) or call end
  end
  if not allowed(options, call.name) then
    errors.raise("AGENT_TOOL_NOT_ALLOWED", "tool " .. call.name .. " is not allowed")
  end
  if call.name ~= original_name or call.arguments ~= original_arguments then
    authorize(options, models.action({
      kind = "tool.invoke", session_id = session_id,
      tool_name = call.name, arguments = call.arguments,
    }))
  end
  if not options.tools then
    errors.raise("TOOL_NOT_FOUND", "tool is not registered")
  end
  local tool = M.get_tool(options.tools, call.name)
  emit(options, "tool.call", session_id, run_id, {
    name = call.name, arguments = call.arguments or {},
  })
  local value = tool.invoke(call.arguments or {})
  return models.message_tool(json.encode(value), call.id or "")
end

local function before_run(options, entered, run_id, prompt)
  for _, middleware in ipairs(options.middleware or {}) do
    entered[#entered + 1] = middleware
    if middleware.before_run then middleware.before_run({ run_id = run_id, prompt = prompt }) end
  end
end

local function after_run(options, entered, result, err)
  local first = nil
  for _, middleware in ipairs(entered) do
    if middleware.after_run then
      local ok, caught = pcall(middleware.after_run, result, err)
      if not ok and first == nil then first = caught end
    end
  end
  return first
end

function M.run_agent(options, session, prompt)
  local max_steps = (options.max_steps or 0) > 0 and options.max_steps or 8
  local run_id = "run-" .. tostring(math.floor(os.time() * 1000))
  local messages = {}
  for _, message in ipairs(session.messages or {}) do messages[#messages + 1] = message end
  if (options.system_prompt or "") ~= "" then
    table.insert(messages, 1, models.message_text(models.SYSTEM, options.system_prompt))
  end
  messages[#messages + 1] = models.message_text(models.USER, prompt or "")
  local usage = models.usage()
  local entered = {}
  local startup_ok, startup_error = pcall(before_run, options, entered, run_id, prompt)
  if not startup_ok then
    after_run(options, entered, nil, startup_error)
    error(startup_error)
  end
  emit(options, "run.started", session.id, run_id)
  emit_stream(options, run_id, session.id, "values", 0, prompt)
  local after_run_invoked = false
  local ok, result = pcall(function()
    for step = 1, max_steps do
      check_cancelled(options)
      authorize(options, models.action({ kind = "model.generate", session_id = session.id }))
      if options.context then
        local compacted, context_ok = runtime.compact_context(options.context, messages)
        if not context_ok then errors.raise("AGENT_CONTEXT_BUDGET", "context budget") end
        messages = compacted
      end
      local request = models.request({
        messages = messages,
        tools = options.tools and M.tool_specs(options.tools) or {},
        tool_choice = options.tool_choice,
      })
      local response = options.model.generate(request)
      check_cancelled(options)
      usage = models.usage_plus(usage, response.usage or models.usage())
      local total = (usage.input_tokens or 0) + (usage.output_tokens or 0)
      if (options.max_tokens or 0) > 0 and total > options.max_tokens then
        errors.raise("AGENT_MAX_TOKENS", "token budget")
      end
      local message = response.message
      messages[#messages + 1] = message
      local calls = message.tool_calls or {}
      if #calls == 0 then
        emit_stream(options, run_id, session.id, "messages", step, message.content or "")
        local outcome = models.run_result({
          run_id = run_id, output = message.content or "", steps = step, usage = usage,
        })
        after_run_invoked = true
        local cleanup_error = after_run(options, entered, outcome, nil)
        if cleanup_error ~= nil then error(cleanup_error) end
        emit(options, "run.completed", session.id, run_id)
        return outcome
      end
      local tool_messages = invoke_tools(options, calls, run_id, session.id)
      for _, tool_message in ipairs(tool_messages) do
        messages[#messages + 1] = tool_message
      end
    end
    errors.raise("AGENT_MAX_STEPS", "maximum steps")
  end)
  if not ok then
    if not after_run_invoked then after_run(options, entered, nil, result) end
    local message = type(result) == "table" and (result.message or tostring(result)) or tostring(result)
    emit(options, "run.failed", session.id, run_id, { error = message })
    error(result)
  end
  return result
end

return M
