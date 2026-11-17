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
local models = require("praxo.models")

local function check(condition, message)
  if not condition then error(message) end
end

local function expect_error(fn, expected)
  local ok, err = pcall(fn)
  if ok then error("expected error " .. expected) end
  if errors.code(err) ~= expected then
    error("expected " .. expected .. ", got " .. tostring(errors.code(err)))
  end
end

local function new_budget(remaining)
  return { remaining = remaining }
end

local function budget_available(budget)
  return budget.remaining > 0
end

local function budget_take(budget)
  if budget.remaining <= 0 then return false end
  budget.remaining = budget.remaining - 1
  return true
end

local function subset(items, set)
  for _, item in ipairs(items) do
    if not set[item] then return false end
  end
  return true
end

local function allow_all()
  return function(_action)
    return { allowed = true, reason = "root" }
  end
end

local function record_policy(action)
  if action.kind ~= "tool.invoke" then
    return { allowed = true, reason = "non-tool action" }
  end
  if action.tool_name ~= "record" then
    return { allowed = false, reason = "child may only record" }
  end
  local arguments = action.arguments or {}
  if arguments.target == "blocked" then
    return { allowed = false, reason = "blocked target" }
  end
  return { allowed = true, reason = "record allowed" }
end

local function budget_policy(budget)
  return function(action)
    if action.kind ~= "tool.invoke" then
      return { allowed = true, reason = "non-tool action" }
    end
    if budget_available(budget) then
      return { allowed = true, reason = "budget available" }
    end
    return { allowed = false, reason = "delegation budget exhausted" }
  end
end

local function compose_policy(parent, child)
  if parent == nil and child == nil then
    return function(_action)
      return { allowed = true, reason = "delegation policy chain allowed" }
    end
  end
  if parent == nil then return child end
  if child == nil then return parent end
  return function(action)
    local decision = parent(action)
    if decision.allowed then return child(action) end
    return decision
  end
end

local function new_authority(options)
  return {
    allowed = options.allowed,
    delegable = options.delegable,
    max_depth = options.max_depth,
    max_children = options.max_children or 1,
    depth = options.depth or 0,
    budget = options.budget or new_budget(1),
    policy = options.policy or allow_all(),
  }
end

local function new_governor(authority)
  local governor = { authority = authority, active = 0 }

  function governor.delegate(request)
    request = request or {}
    local allowed = request.allowed or {}
    local delegable = request.delegable or {}
    local depth = authority.depth + 1
    if depth > authority.max_depth then
      errors.raise("DELEGATION_DEPTH", "delegation depth exceeded")
    end
    if #allowed == 0 then
      errors.raise("DELEGATION_SCOPE", "delegation tool scope is empty")
    end
    if not subset(allowed, authority.delegable) or
        not subset(allowed, authority.allowed) then
      errors.raise("DELEGATION_SCOPE", "delegation scope exceeds parent")
    end
    if not subset(delegable, authority.delegable) then
      errors.raise("DELEGATION_SCOPE", "child delegable scope exceeds parent")
    end
    if not budget_available(authority.budget) then
      errors.raise("DELEGATION_BUDGET", "delegation budget exhausted")
    end
    if governor.active >= authority.max_children then
      errors.raise("DELEGATION_CHILDREN", "delegation child limit exceeded")
    end
    governor.active = governor.active + 1
    local released = false
    local function release()
      if released then return end
      released = true
      governor.active = governor.active - 1
    end
    local allowed_set = {}
    for _, name in ipairs(allowed) do allowed_set[name] = true end
    local delegable_set = {}
    for _, name in ipairs(delegable) do delegable_set[name] = true end
    local child_policy = compose_policy(
      compose_policy(authority.policy, request.policy),
      budget_policy(authority.budget)
    )
    return {
      authority = new_authority({
        allowed = allowed_set,
        delegable = delegable_set,
        max_depth = authority.max_depth,
        max_children = authority.max_children,
        depth = depth,
        budget = authority.budget,
        policy = child_policy,
      }),
      release = release,
    }
  end

  return governor
end

local function budgeted_tool(inner, budget)
  return {
    name = inner.name,
    description = inner.description,
    parameters = inner.parameters,
    risk = inner.risk,
    invoke = function(arguments)
      if not budget_take(budget) then
        return { error = "DELEGATION_BUDGET" }
      end
      return inner.invoke(arguments)
    end,
  }
end

local function child_run(scope, model, tools, prompt, options)
  options = options or {}
  local authority = scope.authority
  local registry = agent.tool_registry()
  local names = {}
  for _, tool in ipairs(tools) do
    if authority.allowed[tool.name] then
      agent.register_tool(registry, budgeted_tool(tool, authority.budget))
      names[#names + 1] = tool.name
    end
  end
  table.sort(names)
  local agent_options = agent.agent_options(model)
  agent_options.tools = registry
  agent_options.max_steps = 3
  agent_options.allowed_tools = names
  agent_options.policy = authority.policy
  agent_options.require_policy = true
  agent_options.require_tool_scope = true
  if options.cancellation then
    agent_options.cancellation = options.cancellation
  end
  if options.middleware then
    agent_options.middleware = options.middleware
  end
  return agent.run_agent(
    agent_options,
    models.session({ id = "governed-delegation-child" }),
    prompt
  )
end

local function record_tool()
  local state = { calls = 0 }
  local tool = agent.func_tool(
    "record",
    "Record a delegated effect",
    function(_arguments)
      state.calls = state.calls + 1
      return "recorded"
    end,
    { type = "object", properties = { target = { type = "string" } } },
    "write"
  )
  return tool, function() return state.calls end
end

local function parent_only_tool()
  local state = { calls = 0 }
  local tool = agent.func_tool(
    "parent_only",
    "Parent-only capability",
    function(_arguments)
      state.calls = state.calls + 1
      return "parent-effect"
    end,
    { type = "object", properties = {} },
    "write"
  )
  return tool, function() return state.calls end
end

local function fixture_model(tool_name, target, final)
  local step = 0
  return {
    generate = function(_request)
      step = step + 1
      if step == 1 then
        return models.response({ message = models.message_assistant("", {
          models.tool_call({
            id = "call-1",
            name = tool_name,
            arguments = { target = target },
          }),
        }) })
      end
      return models.response({ message = models.message_assistant(final) })
    end,
  }
end

local function run_scope_escalation()
  local _record, record_calls = record_tool()
  local _parent_only, parent_only_calls = parent_only_tool()
  local governor = new_governor(new_authority({
    allowed = { record = true, parent_only = true },
    delegable = { record = true },
    max_depth = 1,
    max_children = 2,
    budget = new_budget(2),
    policy = allow_all(),
  }))
  expect_error(function()
    governor.delegate({ allowed = { "parent_only" } })
  end, "DELEGATION_SCOPE")
  check(record_calls() == 0, "scope escalation produced a record effect")
  check(parent_only_calls() == 0, "scope escalation produced a parent effect")
  local child = governor.delegate({
    allowed = { "record" },
    policy = record_policy,
  })
  child.release()
  check(record_calls() == 0, "unexpected effect after allowed delegation")
  check(parent_only_calls() == 0, "unexpected parent effect after delegation")
  print("scope escalation: rejected; effects=0")
end

local function run_depth_limit()
  local _record, record_calls = record_tool()
  local governor = new_governor(new_authority({
    allowed = { record = true },
    delegable = { record = true },
    max_depth = 1,
    max_children = 1,
    budget = new_budget(2),
    policy = allow_all(),
  }))
  local child = governor.delegate({
    allowed = { "record" },
    delegable = { "record" },
    policy = record_policy,
  })
  local grand = new_governor(child.authority)
  expect_error(function()
    grand.delegate({ allowed = { "record" } })
  end, "DELEGATION_DEPTH")
  check(record_calls() == 0, "depth rejection produced an effect")
  child.release()
  print("depth limit: grandchild rejected; effects=0")
end

local function run_child_limit()
  local governor = new_governor(new_authority({
    allowed = { record = true },
    delegable = { record = true },
    max_depth = 1,
    max_children = 1,
    budget = new_budget(2),
    policy = allow_all(),
  }))
  local first = governor.delegate({ allowed = { "record" } })
  expect_error(function()
    governor.delegate({ allowed = { "record" } })
  end, "DELEGATION_CHILDREN")
  first.release()
  local second = governor.delegate({ allowed = { "record" } })
  second.release()
  print("child limit: enforced and released")
end

local function run_sibling_budget()
  local record, record_calls = record_tool()
  local governor = new_governor(new_authority({
    allowed = { record = true },
    delegable = { record = true },
    max_depth = 1,
    max_children = 2,
    budget = new_budget(1),
    policy = allow_all(),
  }))
  local first = governor.delegate({
    allowed = { "record" },
    policy = record_policy,
  })
  local second = governor.delegate({
    allowed = { "record" },
    policy = record_policy,
  })
  local first_result = child_run(
    first,
    fixture_model("record", "first", "first-done"),
    { record },
    "record once"
  )
  check(first_result.output == "first-done", "first sibling did not complete")
  expect_error(function()
    child_run(
      second,
      fixture_model("record", "second", "second-done"),
      { record },
      "record twice"
    )
  end, "AGENT_POLICY_DENIED")
  check(record_calls() == 1, "sibling budget did not allow one effect")
  first.release()
  second.release()
  print("sibling budget: effects=1")
end

local function run_cancellation()
  local record, record_calls = record_tool()
  local governor = new_governor(new_authority({
    allowed = { record = true },
    delegable = { record = true },
    max_depth = 1,
    max_children = 1,
    budget = new_budget(1),
    policy = allow_all(),
  }))
  local child = governor.delegate({
    allowed = { "record" },
    policy = record_policy,
  })
  local cancelled = false
  local model = {
    generate = function(_request)
      cancelled = true
      return models.response({ message = models.message_assistant("", {
        models.tool_call({
          id = "call-1",
          name = "record",
          arguments = { target = "safe" },
        }),
      }) })
    end,
  }
  expect_error(function()
    child_run(child, model, { record }, "record after cancel", {
      cancellation = function() return cancelled end,
    })
  end, "AGENT_CANCELLED")
  check(record_calls() == 0, "cancellation produced an effect")
  child.release()
  print("cancellation: zero effects")
end

local function run_final_argument_reauthorization()
  local record, record_calls = record_tool()
  local governor = new_governor(new_authority({
    allowed = { record = true },
    delegable = { record = true },
    max_depth = 1,
    max_children = 1,
    budget = new_budget(1),
    policy = allow_all(),
  }))
  local child = governor.delegate({
    allowed = { "record" },
    policy = record_policy,
  })
  local middleware = {
    {
      before_tool = function(call)
        call.arguments = { target = "blocked" }
        return call
      end,
    },
  }
  expect_error(function()
    child_run(
      child,
      fixture_model("record", "safe", "unexpected"),
      { record },
      "record safely",
      { middleware = middleware }
    )
  end, "AGENT_POLICY_DENIED")
  check(record_calls() == 0, "reauthored arguments produced an effect")
  child.release()
  print("final argument reauthorization: denied; effects=0")
end

run_scope_escalation()
run_depth_limit()
run_child_limit()
run_sibling_budget()
run_cancellation()
run_final_argument_reauthorization()
print("lua governance: delegation checks passed (6)")
