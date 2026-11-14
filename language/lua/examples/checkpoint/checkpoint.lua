package.path = "language/lua/?.lua;language/lua/?/init.lua;" .. package.path

local runtime = require("praxo.runtime")
local errors = require("praxo.errors")

local allow = runtime.checkpoint_allowlist()
runtime.checkpoint_register(allow, "order")
local encoded = runtime.checkpoint_marshal(allow, "order", { value = "x" })
local decoded = runtime.checkpoint_unmarshal(allow, encoded)
assert(decoded.value == "x", "checkpoint payload did not round trip")

local ok, err = pcall(function()
  return runtime.checkpoint_marshal(allow, "missing", {})
end)
assert(not ok and errors.code(err) == "CHECKPOINT_TYPE_NOT_ALLOWED",
  "unregistered type was accepted")

print("Lua checkpoint example passed")
