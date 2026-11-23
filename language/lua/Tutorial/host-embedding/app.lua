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

local function device_fixture(device_id)
  if device_id ~= "device-100" then
    return nil
  end
  return {
    id = "device-100",
    mode = "idle",
    temperature = 82,
    fan = "auto",
    firmware = "1.4.2",
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
              id = "device-1",
              name = "read_device",
              arguments = { device_id = event.device_id },
            }),
          }),
        })
      end
      if #tool_messages == 1 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "draft-1",
              name = "draft_action",
              arguments = {
                device_id = event.device_id,
                action = "notify_operator",
              },
            }),
          }),
        })
      end
      local device = json.parse(tool_messages[1].content)
      local draft = json.parse(tool_messages[2].content)
      return models.response({
        message = models.message_assistant(json.encode({
          recommendation = "Review the operator notification; no device command was sent.",
          device = device,
          draft = draft,
          device_writes = json.array({}),
        })),
      })
    end,
  }
end

function M.handle_event(event, simulate_failure)
  local reads = 0
  local registry = agent.tool_registry()
  agent.register_tool(registry, agent.func_tool(
    "read_device", "Read the fixed host device state; no writes.",
    function(arguments)
      reads = reads + 1
      if simulate_failure then
        error("simulated host telemetry unavailable")
      end
      local device = device_fixture(arguments.device_id)
      if not device then
        error("device not found")
      end
      return device
    end
  ))
  agent.register_tool(registry, agent.func_tool(
    "draft_action", "Draft an operator notification; never sends a device command.",
    function(arguments)
      reads = reads + 1
      if arguments.device_id ~= "device-100" then
        error("device not found")
      end
      if arguments.action ~= "notify_operator" then
        error("unsupported draft action")
      end
      return {
        draft_id = "device-draft-1",
        device_id = "device-100",
        action = "notify_operator",
        status = "draft_only",
        review = "review_required",
      }
    end
  ))

  local options = agent.agent_options(fixture_model(event))
  options.tools = registry
  options.allowed_tools = { "read_device", "draft_action" }
  options.max_steps = 4
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "fixture model" }
    end
    if action.kind ~= "tool.invoke" then
      return { allowed = false, reason = "unsupported action" }
    end
    if (action.arguments or {}).device_id ~= "device-100" then
      return { allowed = false, reason = "device outside host scope" }
    end
    if action.tool_name == "read_device" then
      return { allowed = true, reason = "read-only host state" }
    end
    if action.tool_name == "draft_action" then
      return {
        allowed = (action.arguments or {}).action == "notify_operator",
        reason = "only a review-only operator draft is permitted",
      }
    end
    return { allowed = false, reason = "unsupported tool" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "host-embedding" }), event.text or "Review the host event.")
  if not ok then
    return nil, reads, errors.code(result)
  end
  return result.output, reads, nil
end

function M.run_tests()
  local output, reads, code = M.handle_event({
    device_id = "device-100", type = "temperature_high",
    text = "Review the temperature event and draft an operator notification only.",
  })
  assert(code == nil, "success failed: " .. tostring(code))
  assert(reads == 2, "success read count")
  local report = json.parse(output)
  assert(report.device.id == "device-100", "device citation")
  assert(report.draft.status == "draft_only", "draft status")
  assert(report.draft.review == "review_required", "draft review")
  assert(json.is_array(report.device_writes) and #report.device_writes == 0, "device writes")

  local _, deny_reads, deny_code = M.handle_event({
    device_id = "device-200", type = "temperature_high",
    text = "Review the out-of-scope device.",
  })
  assert(deny_code == "AGENT_POLICY_DENIED", "deny code")
  assert(deny_reads == 0, "deny reads")

  local _, fail_reads, fail_code = M.handle_event({
    device_id = "device-100", type = "temperature_high",
    text = "Review the host event.",
  }, true)
  assert(fail_code ~= nil, "failure code")
  assert(fail_reads == 1, "failure reads")

  print("Lua host-embedding tutorial: all checks passed")
end

if arg and arg[1] == "--test" then
  M.run_tests()
  return M
end

local event = {
  device_id = arg and arg[1] or "device-100",
  type = "temperature_high",
  text = "Review the temperature event and draft an operator notification only.",
}
local output, reads, code = M.handle_event(event)
if code then
  io.stderr:write(string.format("host embedding failed: reads=%d; %s\n", reads, tostring(code)))
  os.exit(1)
end
print(output)

return M
