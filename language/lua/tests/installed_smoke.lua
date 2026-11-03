local agent = require("praxo.agent")
local models = require("praxo.models")

local result = agent.run_agent(
  agent.agent_options(agent.static_model("hello")),
  models.session({ id = "installed-smoke" }),
  "hello"
)

assert(result.output == "hello", "installed smoke output")
print("lua installed smoke passed")
