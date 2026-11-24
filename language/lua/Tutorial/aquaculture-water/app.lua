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

local function water_fixture(pond_id)
  if pond_id ~= "pond-100" then
    return nil
  end
  return {
    pond_id = "pond-100",
    dissolved_oxygen = 4.2,
    temperature_c = 27.5,
    oxygen_threshold = 5.0,
    status = "below_threshold",
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
              id = "water-1",
              name = "read_water",
              arguments = { pond_id = event.pond_id },
            }),
          }),
        })
      end
      if #tool_messages == 1 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "action-1",
              name = "draft_action",
              arguments = { pond_id = event.pond_id, action = "draft_action" },
            }),
          }),
        })
      end
      local water = json.parse(tool_messages[1].content)
      local action = json.parse(tool_messages[2].content)
      return models.response({
        message = models.message_assistant(json.encode({
          water = water,
          action = action,
          aerator_commands = 0,
          feeder_commands = 0,
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
    "read_water", "Compute fixed oxygen/temperature indicators; no actuator access.",
    function(arguments)
      reads = reads + 1
      if simulate_failure then
        error("simulated pond store unavailable")
      end
      local water = water_fixture(arguments.pond_id)
      if not water then
        error("pond not found")
      end
      return water
    end
  ))
  agent.register_tool(registry, agent.func_tool(
    "draft_action", "Draft a review-only bounded action; never commands aerators or feeders.",
    function(arguments)
      if arguments.pond_id ~= "pond-100" then
        error("pond not found")
      end
      if arguments.action ~= "draft_action" then
        error("unsupported draft action")
      end
      drafts = drafts + 1
      return {
        action_id = "water-100",
        pond_id = "pond-100",
        action = "draft_action",
        actions = 1,
        recommendation = "schedule aeration review",
        status = "draft_only",
        review = "review_required",
        aerator_commands = 0,
        feeder_commands = 0,
      }
    end
  ))

  local options = agent.agent_options(fixture_model(event))
  options.tools = registry
  options.allowed_tools = { "read_water", "draft_action" }
  options.max_steps = 4
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "fixture model" }
    end
    if action.kind ~= "tool.invoke" then
      return { allowed = false, reason = "unsupported action" }
    end
    if (action.arguments or {}).pond_id ~= "pond-100" then
      return { allowed = false, reason = "pond outside monitoring scope" }
    end
    if action.tool_name == "read_water" then
      return { allowed = true, reason = "read-only water fixture" }
    end
    if action.tool_name == "draft_action" then
      return {
        allowed = (action.arguments or {}).action == "draft_action",
        reason = "only a review-only action draft is permitted",
      }
    end
    return { allowed = false, reason = "unsupported tool" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "aquaculture-water" }), event.text or "Draft a water action.")
  if not ok then
    return nil, reads, drafts, errors.code(result)
  end
  return result.output, reads, drafts, nil
end

function M.run_tests()
  local output, reads, drafts, code = M.handle_event({
    pond_id = "pond-100", type = "water",
    text = "Read the fixed water indicators and draft a review-only action.",
  })
  assert(code == nil, "success failed: " .. tostring(code))
  assert(reads == 1 and drafts == 1, "success counts")
  local report = json.parse(output)
  assert(report.water.pond_id == "pond-100", "pond citation")
  assert(report.water.dissolved_oxygen == 4.2, "oxygen")
  assert(report.water.status == "below_threshold", "status")
  assert(report.action.status == "draft_only", "action status")
  assert(report.action.review == "review_required", "action review")
  assert(report.action.aerator_commands == 0 and report.aerator_commands == 0, "no aerator command")
  assert(report.feeder_commands == 0, "no feeder command")

  local _, deny_reads, deny_drafts, deny_code = M.handle_event({
    pond_id = "pond-200", type = "water",
    text = "Draft the out-of-scope pond.",
  })
  assert(deny_code == "AGENT_POLICY_DENIED", "deny code")
  assert(deny_reads == 0 and deny_drafts == 0, "deny counts")

  local _, fail_reads, fail_drafts, fail_code = M.handle_event({
    pond_id = "pond-100", type = "water",
    text = "Read the fixed water indicators and draft an action.",
  }, true)
  assert(fail_code ~= nil, "failure code")
  assert(fail_reads == 1 and fail_drafts == 0, "failure counts")

  print("Lua aquaculture-water tutorial: all checks passed")
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
local pond_id = arg and arg[1]
if not pond_id or pond_id == "--simulate-failure" then
  pond_id = "pond-100"
end
local event = {
  pond_id = pond_id,
  type = "water",
  text = "Read the fixed water indicators and draft a review-only action.",
}
local output, reads, drafts, code = M.handle_event(event, simulate_failure)
if code then
  io.stderr:write(string.format("aquaculture water failed: reads=%d drafts=%d; %s\n", reads, drafts, tostring(code)))
  os.exit(1)
end
print(output)

return M
