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
    errors.raise("POLICY_ERROR", "policy denied the action")
  end
end

local function invoke_tool(options, call, run_id, session_id)
  authorize(options, models.action({
    kind = "tool.invoke", session_id = session_id,
    tool_name = call.name, arguments = call.arguments,
  }))
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
  emit(options, "run.started", session.id, run_id)
  local ok, result = pcall(function()
    for step = 1, max_steps do
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
      usage = models.usage_plus(usage, response.usage or models.usage())
      local total = (usage.input_tokens or 0) + (usage.output_tokens or 0)
      if (options.max_tokens or 0) > 0 and total > options.max_tokens then
        errors.raise("AGENT_MAX_TOKENS", "token budget")
      end
      local message = response.message
      messages[#messages + 1] = message
      local calls = message.tool_calls or {}
      if #calls == 0 then
        emit(options, "run.completed", session.id, run_id)
        return models.run_result({
          run_id = run_id, output = message.content or "", steps = step, usage = usage,
        })
      end
      for _, call in ipairs(calls) do
        messages[#messages + 1] = invoke_tool(options, call, run_id, session.id)
      end
    end
    errors.raise("AGENT_MAX_STEPS", "maximum steps")
  end)
  if not ok then
    local message = type(result) == "table" and (result.message or tostring(result)) or tostring(result)
    emit(options, "run.failed", session.id, run_id, { error = message })
    error(result)
  end
  return result
end

return M
