local script_dir = (arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$")) or "."

package.path = table.concat({
  script_dir .. "/../../../?.lua",
  script_dir .. "/../../../?/init.lua",
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  "./?.lua",
  package.path,
}, ";")

local agent = require("praxo.agent")
local models = require("praxo.models")
local openai = require("praxo.openai_compatible")

local function env_or(name, fallback)
  local value = os.getenv(name)
  if value == nil or value == "" then return fallback end
  return value
end

local function get_time(arguments)
  if arguments and arguments.zone == "local" then
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local base_url = env_or("PRAXO_BASE_URL", "http://localhost:11434/v1")
local model_name = env_or("PRAXO_MODEL", "qwen3.5:4b")
local prompt = env_or(
  "PRAXO_PROMPT",
  "What time is it? Use get_time with zone set to utc and reply with the time."
)

local model = openai.new({
  base_url = base_url,
  model = model_name,
  api_key = env_or("PRAXO_API_KEY", nil),
})

local registry = agent.tool_registry()
agent.register_tool(registry, agent.func_tool(
  "get_time",
  "Return the current time in ISO 8601 format for the requested zone.",
  get_time,
  {
    type = "object",
    properties = {
      zone = {
        type = "string",
        enum = { "utc", "local" },
        description = "utc or local; defaults to utc",
      },
    },
  },
  "read"
))

local options = agent.agent_options(model)
options.tools = registry
options.system_prompt = "You are a concise assistant. Use the provided tools when they help."
options.max_steps = 4
options.allowed_tools = { "get_time" }
options.policy = function(action)
  if action.kind == "model.generate" then
    return { allowed = true, reason = "model generation" }
  elseif action.kind == "tool.invoke" then
    return {
      allowed = action.tool_name == "get_time",
      reason = "only get_time is permitted",
    }
  end
  return { allowed = false, reason = "unsupported action" }
end

local ok, result = pcall(
  agent.run_agent,
  options,
  models.session({ id = "live-model" }),
  prompt
)

if not ok then
  io.stderr:write(
    "live model run failed: " .. tostring(result) .. "\n\n" ..
    "Check PRAXO_BASE_URL (" .. base_url .. "), PRAXO_MODEL (" .. model_name .. "), and PRAXO_API_KEY\n"
  )
  os.exit(1)
end

print(result.output)
