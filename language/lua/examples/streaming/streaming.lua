package.path = "language/lua/?.lua;language/lua/?/init.lua;" .. package.path

local agent = require("praxo.agent")
local models = require("praxo.models")

local parts = {}
local options = agent.agent_options(agent.static_model("done"))
options.on_stream = function(part) parts[#parts + 1] = part.kind end

local result = agent.run_agent(options, models.session({ id = "streaming" }), "go")
assert(result.output == "done")
assert(table.concat(parts, ",") == "values,messages")

print("Lua streaming example passed")
