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

local function field_fixture(field_id)
  if field_id ~= "field-100" then
    return nil
  end
  return {
    field_id = "field-100",
    soil_moisture = 22,
    moisture_threshold = 30,
    rain_forecast_mm = 2,
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
              id = "field-1",
              name = "read_field",
              arguments = { field_id = event.field_id },
            }),
          }),
        })
      end
      if #tool_messages == 1 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "request-1",
              name = "draft_request",
              arguments = { field_id = event.field_id, action = "draft_irrigation" },
            }),
          }),
        })
      end
      local field = json.parse(tool_messages[1].content)
      local request = json.parse(tool_messages[2].content)
      return models.response({
        message = models.message_assistant(json.encode({
          field = field,
          request = request,
          valve_commands = 0,
          drone_commands = 0,
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
    "read_field", "Evaluate fixed soil/weather observations; no actuator access.",
    function(arguments)
      reads = reads + 1
      if simulate_failure then
        error("simulated field store unavailable")
      end
      local field = field_fixture(arguments.field_id)
      if not field then
        error("field not found")
      end
      return field
    end
  ))
  agent.register_tool(registry, agent.func_tool(
    "draft_request", "Draft a review-only bounded irrigation request; never commands valves or drones.",
    function(arguments)
      if arguments.field_id ~= "field-100" then
        error("field not found")
      end
      if arguments.action ~= "draft_irrigation" then
        error("unsupported draft action")
      end
      drafts = drafts + 1
      return {
        request_id = "irrigation-100",
        field_id = "field-100",
        action = "draft_irrigation",
        request_liters = 400,
        status = "draft_only",
        review = "review_required",
        valve_commands = 0,
        drone_commands = 0,
      }
    end
  ))

  local options = agent.agent_options(fixture_model(event))
  options.tools = registry
  options.allowed_tools = { "read_field", "draft_request" }
  options.max_steps = 4
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "fixture model" }
    end
    if action.kind ~= "tool.invoke" then
      return { allowed = false, reason = "unsupported action" }
    end
    if (action.arguments or {}).field_id ~= "field-100" then
      return { allowed = false, reason = "field outside irrigation scope" }
    end
    if action.tool_name == "read_field" then
      return { allowed = true, reason = "read-only field fixture" }
    end
    if action.tool_name == "draft_request" then
      return {
        allowed = (action.arguments or {}).action == "draft_irrigation",
        reason = "only a review-only irrigation request is permitted",
      }
    end
    return { allowed = false, reason = "unsupported tool" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "irrigation-plan" }), event.text or "Draft an irrigation request.")
  if not ok then
    return nil, reads, drafts, errors.code(result)
  end
  return result.output, reads, drafts, nil
end

function M.run_tests()
  local output, reads, drafts, code = M.handle_event({
    field_id = "field-100", type = "irrigation",
    text = "Read the fixed field and draft a review-only irrigation request.",
  })
  assert(code == nil, "success failed: " .. tostring(code))
  assert(reads == 1 and drafts == 1, "success counts")
  local report = json.parse(output)
  assert(report.field.field_id == "field-100", "field citation")
  assert(report.field.soil_moisture == 22, "moisture")
  assert(report.field.status == "below_threshold", "status")
  assert(report.request.status == "draft_only", "request status")
  assert(report.request.review == "review_required", "request review")
  assert(report.request.request_liters == 400, "request liters")
  assert(report.request.valve_commands == 0 and report.valve_commands == 0, "no valve command")
  assert(report.drone_commands == 0, "no drone command")

  local _, deny_reads, deny_drafts, deny_code = M.handle_event({
    field_id = "field-200", type = "irrigation",
    text = "Draft the out-of-scope field.",
  })
  assert(deny_code == "AGENT_POLICY_DENIED", "deny code")
  assert(deny_reads == 0 and deny_drafts == 0, "deny counts")

  local _, fail_reads, fail_drafts, fail_code = M.handle_event({
    field_id = "field-100", type = "irrigation",
    text = "Read the fixed field and draft a request.",
  }, true)
  assert(fail_code ~= nil, "failure code")
  assert(fail_reads == 1 and fail_drafts == 0, "failure counts")

  print("Lua irrigation-plan tutorial: all checks passed")
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
local field_id = arg and arg[1]
if not field_id or field_id == "--simulate-failure" then
  field_id = "field-100"
end
local event = {
  field_id = field_id,
  type = "irrigation",
  text = "Read the fixed field and draft a review-only irrigation request.",
}
local output, reads, drafts, code = M.handle_event(event, simulate_failure)
if code then
  io.stderr:write(string.format("irrigation plan failed: reads=%d drafts=%d; %s\n", reads, drafts, tostring(code)))
  os.exit(1)
end
print(output)

return M
