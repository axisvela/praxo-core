package.path = "language/lua/?.lua;language/lua/?/init.lua;" .. package.path

local json = require("praxo.json")
local middleware = require("praxo.middleware")

local schema = json.parse(
  '{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}'
)
local structured = middleware.structured_output(schema, 0)
local text, code = structured:apply('{"name":"ok"}')
assert(text == '{"name":"ok"}' and code == nil)

text, code = structured:apply("{}")
assert(text == nil and code == "AGENT_STRUCTURED_OUTPUT")

print("Lua structured output example passed")
