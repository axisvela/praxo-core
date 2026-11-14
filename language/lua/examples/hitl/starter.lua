local script_dir = (arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$")) or "."
package.path = table.concat({
  script_dir .. "/../../language/lua/?.lua",
  script_dir .. "/../../language/lua/?/init.lua",
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  "./?.lua",
  package.path,
}, ";")

local agent = require("praxo.agent")
local errors = require("praxo.errors")
local models = require("praxo.models")

local function fixture_model()
  return {
    generate = function(request)
      local last = request.messages[#request.messages]
      if last.role == models.TOOL then
        return models.response({ message = models.message_assistant("done") })
      end
      local call = models.tool_call({
        id = "write-note-1",
        name = "write_note",
        arguments = { text = "hello", visibility = "public" },
      })
      return models.response({
        message = models.message_assistant("", { call }),
      })
    end,
  }
end

local function public_notes_policy(action)
  if action.kind == "model.generate" then
    return { allowed = true }
  end
  if action.kind == "tool.invoke" then
    return {
      allowed = action.tool_name == "write_note" and
        action.arguments.visibility == "public",
      reason = "only public notes are permitted",
    }
  end
  return { allowed = false, reason = "unsupported action" }
end

local function run_scenario(decision)
  local notes = {}
  local registry = agent.tool_registry()
  agent.register_tool(registry, agent.func_tool(
    "write_note",
    "Write a short note with the requested visibility.",
    function(arguments)
      notes[#notes + 1] = arguments.text
      return "written"
    end,
    {
      type = "object",
      required = { "text", "visibility" },
      properties = {
        text = { type = "string" },
        visibility = { type = "string", enum = { "public", "private" } },
      },
    },
    "write"
  ))

  local options = agent.agent_options(fixture_model())
  options.tools = registry
  options.max_steps = 3
  options.allowed_tools = { "write_note" }
  options.policy = public_notes_policy
  options.interrupt_on = { "write_note" }
  options.on_interrupt_decision = function(_interrupt) return decision end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "hitl" }), "Write a note.")
  return ok, result, #notes
end

local ok, result, effects = run_scenario(
  models.interrupt_decision({ action = models.INTERRUPT_APPROVE })
)
assert(ok and result.output == "done" and effects == 1, "approve scenario failed")
print("approve: written; effects=1")

local edited_ok, edited_result, edited_effects = run_scenario(
  models.interrupt_decision({
    action = models.INTERRUPT_EDIT,
    arguments = { text = "hello", visibility = "private" },
  })
)
assert(not edited_ok and errors.code(edited_result) == "AGENT_POLICY_DENIED"
  and edited_effects == 0, "edit scenario failed")
print("edit: policy rejected; effects=0")
