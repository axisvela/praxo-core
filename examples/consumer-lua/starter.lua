package.path = table.concat({
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  "./?.lua",
  package.path,
}, ";")

local agent = require("praxo.agent")
local errors = require("praxo.errors")
local models = require("praxo.models")

local M = {}

local function fixture_model(target)
  return {
    generate = function(request)
      local last = request.messages[#request.messages]
      if last.role == models.TOOL then
        return models.response({ message = models.message_assistant("recorded") })
      end
      local call = models.tool_call({
        id = "record-1",
        name = "record",
        arguments = { target = target },
      })
      return models.response({
        message = models.message_assistant("", { call }),
      })
    end,
  }
end

function M.run_scenario(target)
  local calls = 0
  local registry = agent.tool_registry()
  agent.register_tool(registry, agent.func_tool("record", "Record a target.", function(_arguments)
    calls = calls + 1
    return "recorded"
  end))

  local options = agent.agent_options(fixture_model(target))
  options.tools = registry
  options.allowed_tools = { "record" }
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "model generation" }
    elseif action.kind == "tool.invoke" then
      return {
        allowed = action.tool_name == "record" and action.arguments.target == "public",
        reason = "only the public target is permitted",
      }
    end
    return { allowed = false, reason = "unsupported action" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "consumer-" .. target }), "Record the requested target.")
  if not ok then
    return "", calls, errors.code(result)
  end
  return result.output, calls, nil
end

function M.run()
  local output, calls, code = M.run_scenario("public")
  assert(code == nil and output == "recorded" and calls == 1, "allow verification failed")
  print("allow: recorded; effects=1")

  local _, deny_calls, deny_code = M.run_scenario("private")
  assert(deny_code == "AGENT_POLICY_DENIED" and deny_calls == 0, "deny verification failed")
  print("deny: policy rejected; effects=0")
end

return M
