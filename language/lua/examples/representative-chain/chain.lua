local script_dir = (arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$")) or "."
package.path = table.concat({
  script_dir .. "/../../?.lua",
  script_dir .. "/../../?/init.lua",
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  "./?.lua",
  package.path,
}, ";")

local agent = require("praxo.agent")
local errors = require("praxo.errors")
local json = require("praxo.json")
local models = require("praxo.models")
local runtime = require("praxo.runtime")
local mcp = require("praxo.adapters.mcp")
local harmovela = require("praxo.adapters.harmovela_sink")
local otel = require("praxo.adapters.otel_sink")

local function check(condition, message)
  if not condition then error(message) end
end

local function fake_mcp_transport(effects)
  return function(method, params)
    if method == "initialize" then
      return {
        protocolVersion = "2024-11-05",
        capabilities = { tools = {} },
        serverInfo = { name = "fixture-mcp", version = "0.0.1" },
      }
    end
    if method == "tools/list" then
      return {
        tools = {
          {
            name = "record",
            description = "Record a target",
            inputSchema = {
              type = "object",
              properties = { target = { type = "string" } },
              required = { "target" },
            },
          },
        },
      }
    end
    if method == "tools/call" then
      if params.name ~= "record" then
        return { isError = true, content = {} }
      end
      local target = tostring((params.arguments or {}).target or "")
      effects[target] = (effects[target] or 0) + 1
      return {
        isError = false,
        structuredContent = { recorded = target },
      }
    end
    return nil, "MCP_RPC"
  end
end

local function record_tool(client)
  return agent.func_tool(
    "record",
    "Record a target",
    function(arguments) return client.call_tool("record", arguments) end,
    {
      type = "object",
      properties = { target = { type = "string" } },
      required = { "target" },
    },
    "write"
  )
end

local function parent_policy(action)
  if action.kind ~= "tool.invoke" then
    return { allowed = true, reason = "non-tool action" }
  end
  if action.tool_name == "record" then
    if (action.arguments or {}).target == "blocked" then
      return { allowed = false, reason = "blocked target" }
    end
    return { allowed = true, reason = "record allowed" }
  end
  if action.tool_name == "delegate" then
    return { allowed = true, reason = "delegate allowed" }
  end
  return { allowed = false, reason = "parent tool is not allowed" }
end

local function child_policy(action)
  if action.kind ~= "tool.invoke" then
    return { allowed = true, reason = "non-tool action" }
  end
  if action.tool_name == "record" then
    return { allowed = true, reason = "record allowed" }
  end
  return { allowed = false, reason = "child may only record" }
end

local function compose_policy(parent, child)
  return function(action)
    local decision = parent(action)
    if decision.allowed then return child(action) end
    return decision
  end
end

local function scripted_model(steps, final)
  local state = { index = 0, calls = 0 }
  local model = {
    generate = function(_request)
      state.calls = state.calls + 1
      if state.index < #steps then
        state.index = state.index + 1
        local step = steps[state.index]
        return models.response({
          message = models.message_assistant(step.content or "", step.tool_calls or {}),
        })
      end
      return models.response({ message = models.message_assistant(final) })
    end,
  }
  model.calls = function() return state.calls end
  return model
end

local function tool_call(id, name, arguments)
  return models.tool_call({ id = id, name = name, arguments = arguments })
end

local function delegate_tool(record, child_model, events)
  return agent.func_tool(
    "delegate",
    "Run a governed child agent with the narrowed record scope",
    function(_arguments)
      local registry = agent.tool_registry()
      agent.register_tool(registry, record)
      local options = agent.agent_options(child_model)
      options.tools = registry
      options.max_steps = 3
      options.allowed_tools = { "record" }
      options.policy = compose_policy(parent_policy, child_policy)
      options.require_policy = true
      options.require_tool_scope = true
      options.events = events
      local result = agent.run_agent(
        options,
        models.session({ id = "chain-child" }),
        "record child"
      )
      return { output = result.output }
    end,
    {
      type = "object",
      properties = { task = { type = "string" } },
      required = { "task" },
    },
    "write"
  )
end

local function new_events()
  local otel_log = {}
  local harmovela_log = {}
  local otel_sink = otel.new({
    endpoint = "http://otel.local/v1/traces",
    clock = function() return 1700000000, 0 end,
    transport = function(_endpoint, body, _headers)
      local payload = json.parse(body)
      for _, resource in ipairs(payload.resourceSpans or {}) do
        for _, scope in ipairs(resource.scopeSpans or {}) do
          for _, span in ipairs(scope.spans or {}) do
            otel_log[#otel_log + 1] = span.name
          end
        end
      end
      return { status = 200, body = "" }
    end,
  })
  local harmovela_sink = harmovela.new({
    base_url = "http://harmovela.local",
    clock = function() return 1700000000, 0 end,
    transport = function(_path, body, _headers)
      local envelope = json.parse(body)
      harmovela_log[#harmovela_log + 1] = envelope.type
      return { status = 202, body = "" }
    end,
  })
  return runtime.multi_sink({ otel_sink, harmovela_sink }), otel_log, harmovela_log
end

local function required(values, wanted)
  for _, item in ipairs(wanted) do
    local found = false
    for _, value in ipairs(values) do
      if value == item then found = true; break end
    end
    check(found, "missing event: " .. item)
  end
end

local function run_chain()
  local effects = {}
  local client = mcp.new({ transport = fake_mcp_transport(effects) })
  local record = record_tool(client)
  local events, otel_log, harmovela_log = new_events()
  local child_model = scripted_model({
    {
      tool_calls = { tool_call("child-record", "record", { target = "child" }) },
    },
  }, "CHILD-DONE")
  local parent_model = scripted_model({
    {
      tool_calls = { tool_call("parent-record", "record", { target = "parent" }) },
    },
    {
      tool_calls = { tool_call("parent-delegate", "delegate", { task = "child" }) },
    },
  }, "DONE")
  local registry = agent.tool_registry()
  agent.register_tool(registry, record)
  agent.register_tool(registry, delegate_tool(record, child_model, events))
  local options = agent.agent_options(parent_model)
  options.tools = registry
  options.max_steps = 6
  options.allowed_tools = { "record", "delegate" }
  options.policy = parent_policy
  options.require_policy = true
  options.require_tool_scope = true
  options.events = events
  local result = agent.run_agent(
    options,
    models.session({ id = "chain-parent" }),
    "run the representative chain"
  )
  client.close()
  return {
    output = result.output,
    effects = effects,
    child_calls = child_model.calls(),
    otel = otel_log,
    harmovela = harmovela_log,
  }
end

local function run_denial()
  local effects = {}
  local client = mcp.new({ transport = fake_mcp_transport(effects) })
  local record = record_tool(client)
  local model = scripted_model({
    {
      tool_calls = { tool_call("denied-record", "record", { target = "safe" }) },
    },
  }, "UNEXPECTED")
  local registry = agent.tool_registry()
  agent.register_tool(registry, record)
  local options = agent.agent_options(model)
  options.tools = registry
  options.max_steps = 2
  options.allowed_tools = { "record" }
  options.policy = parent_policy
  options.require_policy = true
  options.require_tool_scope = true
  options.middleware = {
    {
      before_tool = function(call)
        call.arguments = { target = "blocked" }
        return call
      end,
    },
  }
  local ok, err = pcall(
    agent.run_agent,
    options,
    models.session({ id = "chain-denial" }),
    "call record"
  )
  client.close()
  if ok then error("denial path unexpectedly succeeded") end
  check(errors.code(err) == "AGENT_POLICY_DENIED",
    "unexpected denial error: " .. tostring(errors.code(err)))
  return effects.blocked or 0, errors.code(err)
end

local result = run_chain()
check(result.output == "DONE", "parent did not complete")
check(result.effects.parent == 1, "parent effect count")
check(result.effects.child == 1, "child effect count")
check(result.child_calls >= 2, "child model calls")
required(result.otel, { "praxo.run.started", "praxo.tool.call", "praxo.run.completed" })
required(result.harmovela, { "run.started", "tool.call", "run.completed" })
local blocked, code = run_denial()
check(blocked == 0, "denied effect count")
check(code == "AGENT_POLICY_DENIED", "denial code")

print("output: " .. result.output)
print("effects: parent=" .. result.effects.parent .. " child=" .. result.effects.child)
print("child calls: " .. result.child_calls)
print("otel spans: " .. #result.otel)
print("harmovela events: " .. #result.harmovela)
print("denied effects: " .. blocked)
print("lua representative chain passed")
