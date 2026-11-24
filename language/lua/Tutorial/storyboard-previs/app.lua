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

local function script_fixture(scene_id)
  if scene_id ~= "scene-100" then
    return nil
  end
  return {
    scene_id = "scene-100",
    title = "Rooftop Chase",
    beats = { "setup", "pursuit", "reversal" },
    constraints = { max_shots = 6, duration_s = 45 },
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
              id = "scene-1",
              name = "read_script",
              arguments = { scene_id = event.scene_id },
            }),
          }),
        })
      end
      if #tool_messages == 1 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "plan-1",
              name = "draft_shot_plan",
              arguments = {
                scene_id = event.scene_id,
                action = "draft_previs",
              },
            }),
          }),
        })
      end
      local scene = json.parse(tool_messages[1].content)
      local plan = json.parse(tool_messages[2].content)
      return models.response({
        message = models.message_assistant(json.encode({
          scene = scene,
          plan = plan,
          renders = 0,
          engine_calls = 0,
        })),
      })
    end,
  }
end

function M.handle_event(event, simulate_failure)
  local reads = 0
  local plans = 0
  local registry = agent.tool_registry()
  agent.register_tool(registry, agent.func_tool(
    "read_script", "Read a fixed script scene; no media or engine access.",
    function(arguments)
      reads = reads + 1
      if simulate_failure then
        error("simulated script store unavailable")
      end
      local scene = script_fixture(arguments.scene_id)
      if not scene then
        error("scene not found")
      end
      return scene
    end
  ))
  agent.register_tool(registry, agent.func_tool(
    "draft_shot_plan", "Draft a review-only shot plan; never renders or calls an engine.",
    function(arguments)
      if arguments.scene_id ~= "scene-100" then
        error("scene not found")
      end
      if arguments.action ~= "draft_previs" then
        error("unsupported draft action")
      end
      plans = plans + 1
      return {
        plan_id = "previs-100",
        scene_id = "scene-100",
        action = "draft_previs",
        shots = {
          { no = 1, shot = "wide", beat = "setup" },
          { no = 2, shot = "tracking", beat = "pursuit" },
          { no = 3, shot = "close-up", beat = "reversal" },
        },
        status = "draft_only",
        review = "review_required",
        renders = 0,
        engine_calls = 0,
      }
    end
  ))

  local options = agent.agent_options(fixture_model(event))
  options.tools = registry
  options.allowed_tools = { "read_script", "draft_shot_plan" }
  options.max_steps = 4
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "fixture model" }
    end
    if action.kind ~= "tool.invoke" then
      return { allowed = false, reason = "unsupported action" }
    end
    if (action.arguments or {}).scene_id ~= "scene-100" then
      return { allowed = false, reason = "scene outside previs scope" }
    end
    if action.tool_name == "read_script" then
      return { allowed = true, reason = "read-only script fixture" }
    end
    if action.tool_name == "draft_shot_plan" then
      return {
        allowed = (action.arguments or {}).action == "draft_previs",
        reason = "only a review-only previs draft is permitted",
      }
    end
    return { allowed = false, reason = "unsupported tool" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "storyboard-previs" }), event.text or "Draft a shot plan.")
  if not ok then
    return nil, reads, plans, errors.code(result)
  end
  return result.output, reads, plans, nil
end

function M.run_tests()
  local output, reads, plans, code = M.handle_event({
    scene_id = "scene-100", type = "storyboard",
    text = "Read the fixed scene and draft a review-only shot plan.",
  })
  assert(code == nil, "success failed: " .. tostring(code))
  assert(reads == 1 and plans == 1, "success counts")
  local report = json.parse(output)
  assert(report.scene.scene_id == "scene-100", "scene citation")
  assert(#report.scene.beats == 3, "scene beats")
  assert(report.plan.status == "draft_only", "plan status")
  assert(report.plan.review == "review_required", "plan review")
  assert(#report.plan.shots == 3, "plan shots")
  assert(report.renders == 0 and report.engine_calls == 0, "no render or engine call")

  local _, deny_reads, deny_plans, deny_code = M.handle_event({
    scene_id = "scene-200", type = "storyboard",
    text = "Draft the out-of-scope scene.",
  })
  assert(deny_code == "AGENT_POLICY_DENIED", "deny code")
  assert(deny_reads == 0 and deny_plans == 0, "deny counts")

  local _, fail_reads, fail_plans, fail_code = M.handle_event({
    scene_id = "scene-100", type = "storyboard",
    text = "Read the fixed scene and draft a shot plan.",
  }, true)
  assert(fail_code ~= nil, "failure code")
  assert(fail_reads == 1 and fail_plans == 0, "failure counts")

  print("Lua storyboard-previs tutorial: all checks passed")
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
local scene_id = arg and arg[1]
if not scene_id or scene_id == "--simulate-failure" then
  scene_id = "scene-100"
end
local event = {
  scene_id = scene_id,
  type = "storyboard",
  text = "Read the fixed scene and draft a review-only shot plan.",
}
local output, reads, plans, code = M.handle_event(event, simulate_failure)
if code then
  io.stderr:write(string.format("storyboard previs failed: reads=%d plans=%d; %s\n", reads, plans, tostring(code)))
  os.exit(1)
end
print(output)

return M
