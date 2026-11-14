package.path = "language/lua/?.lua;language/lua/?/init.lua;" .. package.path

local runtime = require("praxo.runtime")
local models = require("praxo.models")

local all = {}
all.emit = function(event) all[#all + 1] = event.type end

local tool = {}
tool.emit = function(event) tool[#tool + 1] = event.type end

local filtered = runtime.filter_sink(tool, function(event)
  return event.type == "tool.call"
end)
local multi = runtime.multi_sink({ all, filtered })

for _, kind in ipairs({ "run.started", "tool.call", "run.completed" }) do
  multi.emit(models.event({ type = kind, session_id = "s1" }))
end

assert(table.concat(all, ",") == "run.started,tool.call,run.completed")
assert(table.concat(tool, ",") == "tool.call")

print("Lua event sink example passed")
