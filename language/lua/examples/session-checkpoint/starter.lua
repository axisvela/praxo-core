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
local models = require("praxo.models")
local runtime = require("praxo.runtime")

local function turn_model()
  return {
    generate = function(request)
      return models.response({
        message = models.message_assistant("turn " .. tostring(#request.messages)),
      })
    end,
  }
end

local allow = runtime.checkpoint_allowlist()
runtime.checkpoint_register(allow, "session")

local session = models.session({
  id = "session-1",
  messages = {
    models.message_text(models.USER, "first"),
    models.message_text(models.ASSISTANT, "ack"),
  },
})

local function wire_messages(messages)
  local out = {}
  for _, message in ipairs(messages) do
    out[#out + 1] = models.message_wire(message)
  end
  return out
end

local function restore_messages(items)
  local out = {}
  for _, item in ipairs(items or {}) do
    out[#out + 1] = models.message({ role = item.role, content = item.content })
  end
  return out
end

local payload = runtime.checkpoint_marshal(allow, "session", {
  messages = wire_messages(session.messages),
})
local restored = runtime.checkpoint_unmarshal(allow, payload)
session.messages = restore_messages(restored.messages)

local ok, result = pcall(agent.run_agent, agent.agent_options(turn_model()), session, "second")
assert(ok and result.output == "turn 3", "unexpected second turn")

session.messages[#session.messages + 1] = models.message_text(models.USER, "second")
session.messages[#session.messages + 1] = models.message_text(models.ASSISTANT, result.output)
payload = runtime.checkpoint_marshal(allow, "session", {
  messages = wire_messages(session.messages),
})
restored = runtime.checkpoint_unmarshal(allow, payload)
session.messages = restore_messages(restored.messages)

ok, result = pcall(agent.run_agent, agent.agent_options(turn_model()), session, "third")
assert(ok and result.output == "turn 5", "unexpected third turn")

print("restored messages: " .. tostring(#session.messages))
print("output: " .. result.output)
