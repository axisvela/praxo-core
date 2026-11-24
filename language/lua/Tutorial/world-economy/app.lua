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

local M = {}

local function world_fixture(world_id)
  if world_id ~= "world-100" then
    return nil
  end
  return {
    world_id = "world-100",
    tick = 12,
    population = 30,
    food = 120,
    ore = 45,
  }
end

local function fixture_model(event)
  return {
    generate = function(request)
      local tool_messages = {}
      for _, message in ipairs(request.messages or {}) do
        if message.role == models.TOOL then
          tool_messages[#tool_messages + 1] = message
        end
      end
      if #tool_messages == 0 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "world-1",
              name = "read_economy",
              arguments = { world_id = event.world_id },
            }),
          }),
        })
      end
      if #tool_messages == 1 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "balance-1",
              name = "draft_balance",
              arguments = { world_id = event.world_id, action = "draft_balance" },
            }),
          }),
        })
      end
      local economy = json.parse(tool_messages[1].content)
      local balance = json.parse(tool_messages[2].content)
      return models.response({
        message = models.message_assistant(json.encode({
          economy = economy,
          balance = balance,
          applied = false,
          scale_claims = 0,
        })),
      })
    end,
  }
end

function M.handle_event(event, simulate_failure)
  local reads = 0
  local drafts = 0
  local registry = agent.tool_registry()
  agent.register_tool(registry, agent.func_tool(
    "read_economy", "Read fixed synthetic world economy state; no writes.",
    function(arguments)
      reads = reads + 1
      if simulate_failure then
        error("simulated world store unavailable")
      end
      local world = world_fixture(arguments.world_id)
      if not world then
        error("world not found")
      end
      return world
    end
  ))
  agent.register_tool(registry, agent.func_tool(
    "draft_balance", "Draft a review-only economy balance; never applies changes.",
    function(arguments)
      if arguments.world_id ~= "world-100" then
        error("world not found")
      end
      if arguments.action ~= "draft_balance" then
        error("unsupported draft action")
      end
      drafts = drafts + 1
      return {
        balance_id = "economy-100",
        world_id = "world-100",
        action = "draft_balance",
        tick = 12,
        changes = 2,
        status = "draft_only",
        review = "review_required",
        applied = false,
        scale_claims = 0,
      }
    end
  ))

  local options = agent.agent_options(fixture_model(event))
  options.tools = registry
  options.allowed_tools = { "read_economy", "draft_balance" }
  options.max_steps = 4
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "fixture model" }
    end
    if action.kind ~= "tool.invoke" then
      return { allowed = false, reason = "unsupported action" }
    end
    if (action.arguments or {}).world_id ~= "world-100" then
      return { allowed = false, reason = "world outside simulation scope" }
    end
    if action.tool_name == "read_economy" then
      return { allowed = true, reason = "read-only world fixture" }
    end
    if action.tool_name == "draft_balance" then
      return {
        allowed = (action.arguments or {}).action == "draft_balance",
        reason = "only a review-only balance draft is permitted",
      }
    end
    return { allowed = false, reason = "unsupported tool" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "world-economy" }), event.text or "Draft an economy balance.")
  if not ok then
    return nil, reads, drafts, errors.code(result)
  end
  return result.output, reads, drafts, nil
end

function M.run_tests()
  local output, reads, drafts, code = M.handle_event({
    world_id = "world-100", type = "economy",
    text = "Read the fixed world and draft a review-only balance.",
  })
  assert(code == nil, "success failed: " .. tostring(code))
  assert(reads == 1 and drafts == 1, "success counts")
  local report = json.parse(output)
  assert(report.economy.world_id == "world-100", "world citation")
  assert(report.economy.tick == 12, "tick")
  assert(report.economy.population == 30, "population")
  assert(report.balance.status == "draft_only", "balance status")
  assert(report.balance.review == "review_required", "balance review")
  assert(report.balance.changes == 2, "balance changes")
  assert(report.balance.applied == false and report.applied == false, "no applied changes")
  assert(report.scale_claims == 0, "no scale claim")

  local _, deny_reads, deny_drafts, deny_code = M.handle_event({
    world_id = "world-200", type = "economy",
    text = "Draft the out-of-scope world.",
  })
  assert(deny_code == "AGENT_POLICY_DENIED", "deny code")
  assert(deny_reads == 0 and deny_drafts == 0, "deny counts")

  local _, fail_reads, fail_drafts, fail_code = M.handle_event({
    world_id = "world-100", type = "economy",
    text = "Read the fixed world and draft a balance.",
  }, true)
  assert(fail_code ~= nil, "failure code")
  assert(fail_reads == 1 and fail_drafts == 0, "failure counts")

  print("Lua world-economy tutorial: all checks passed")
end

if arg and arg[1] == "--test" then
  M.run_tests()
  return M
end

local simulate_failure = false
for i = 1, #arg do
  if arg[i] == "--simulate-failure" then
    simulate_failure = true
  end
end
local world_id = arg and arg[1]
if not world_id or world_id == "--simulate-failure" then
  world_id = "world-100"
end
local event = {
  world_id = world_id,
  type = "economy",
  text = "Read the fixed world and draft a review-only balance.",
}
local output, reads, drafts, code = M.handle_event(event, simulate_failure)
if code then
  io.stderr:write(string.format("world economy failed: reads=%d drafts=%d; %s\n", reads, drafts, tostring(code)))
  os.exit(1)
end
print(output)

return M
