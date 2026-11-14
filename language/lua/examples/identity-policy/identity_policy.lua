local function authorize(principal, action)
  if principal == nil then return false, "missing" end
  if not principal.active then return false, "inactive" end
  if action.kind == "model.generate" then return true end
  if principal.role ~= "operator" then return false, "role" end
  if action.tenant ~= principal.tenant then return false, "tenant" end
  if action.tool ~= "record" then return false, "operation" end
  return true
end

local operator = { tenant = "acme", role = "operator", active = true }
assert(authorize(operator, { kind = "model.generate" }))
assert(authorize(operator, { kind = "tool.invoke", tool = "record", tenant = "acme" }))
assert(not authorize({ tenant = "acme", role = "viewer", active = true },
  { kind = "tool.invoke", tool = "record", tenant = "acme" }))
assert(not authorize(operator, { kind = "tool.invoke", tool = "record", tenant = "other" }))
assert(not authorize(nil, { kind = "model.generate" }))

print("Lua identity policy example passed")
