local json = require("praxo.json")

local M = {}

local KINDS = {
  ["tool.provider.v1"] = true,
  ["model.provider.v1"] = true,
  ["policy.provider.v1"] = true,
  ["memory.provider.v1"] = true,
  ["sandbox.provider.v1"] = true,
}
local TOP_KEYS = {
  schemaVersion = true, id = true, version = true, kind = true, entrypoint = true,
  protocol = true, capabilities = true, permissions = true, limits = true,
  isolation = true, health = true, signature = true, sbom = true,
}
local ENTRYPOINT_KEYS = { type = true, command = true, module = true, image = true, args = true, dir = true }
local PERMISSION_KEYS = { filesystem = true, network = true, env = true }
local LIMIT_KEYS = { memoryMB = true, cpuMillis = true, timeoutMs = true, maxInflight = true }
local HEALTH_KEYS = { method = true, intervalMs = true }
local SIGNATURE_KEYS = { algorithm = true, keyId = true }

local function fail(message)
  error({ code = "PLUGIN_INVALID", message = message })
end

local function check_keys(value, allowed, where)
  for key in pairs(value) do
    if not allowed[key] then fail("plugin: manifest: unknown field " .. key .. " in " .. where) end
  end
end

local function as_object(value, where)
  if value == nil then return {} end
  if type(value) ~= "table" or json.is_array(value) then
    fail("plugin: manifest: " .. where .. " must be an object")
  end
  return value
end

local function as_string(value, where)
  if type(value) ~= "string" then fail("plugin: manifest: " .. where .. " must be a string") end
  return value
end

local function as_int(value, where)
  if type(value) ~= "number" or math.floor(value) ~= value then
    fail("plugin: manifest: " .. where .. " must be an integer")
  end
  return value
end

local function text_present(value)
  return type(value) == "string" and value ~= ""
end

function M.parse_manifest(raw)
  if type(raw) ~= "string" or raw:match("^%s*$") then fail("plugin: manifest is empty") end
  local ok, root = pcall(json.parse, raw)
  if not ok then fail("plugin: manifest: " .. tostring(root)) end
  if type(root) ~= "table" or json.is_array(root) then fail("plugin: manifest must be an object") end
  check_keys(root, TOP_KEYS, "manifest")
  local schema_version = as_int(root.schemaVersion, "schemaVersion")
  if schema_version ~= 1 then
    fail("plugin: manifest: schemaVersion = " .. schema_version .. ", want 1")
  end
  local id = as_string(root.id, "id")
  if not id:match("^[a-z0-9][a-z0-9%.%-]*%.[a-z0-9][a-z0-9%-]*$") then
    fail("plugin: manifest: id " .. id .. " is not reverse-DNS")
  end
  local version = as_string(root.version, "version")
  if not version:match("^%d+%.%d+%.%d+") then
    fail("plugin: manifest: version " .. version .. " is not semver")
  end
  local kind = as_string(root.kind, "kind")
  if not KINDS[kind] then fail("plugin: manifest: kind " .. kind .. " is not a known contract") end
  local protocol = as_string(root.protocol, "protocol")
  if protocol ~= "jsonrpc-2" then
    fail("plugin: manifest: protocol = " .. protocol .. ", want jsonrpc-2")
  end
  local entrypoint = as_object(root.entrypoint, "entrypoint")
  check_keys(entrypoint, ENTRYPOINT_KEYS, "entrypoint")
  local entry_type = as_string(entrypoint.type, "entrypoint.type")
  local required = ({ process = "command", wasm = "module", container = "image" })[entry_type]
  if not required then fail("plugin: manifest: unknown entrypoint type " .. entry_type) end
  if not text_present(entrypoint[required]) then
    fail("plugin: manifest: " .. entry_type .. " entrypoint requires " .. required)
  end
  local isolation = as_string(root.isolation, "isolation")
  if isolation ~= entry_type then
    fail("plugin: manifest: isolation " .. isolation .. " does not match entrypoint " .. entry_type)
  end
  local permissions = as_object(root.permissions, "permissions")
  check_keys(permissions, PERMISSION_KEYS, "permissions")
  local limits = as_object(root.limits, "limits")
  check_keys(limits, LIMIT_KEYS, "limits")
  for key, value in pairs(limits) do
    if as_int(value, "limits." .. key) < 0 then fail("plugin: manifest: limits must not be negative") end
  end
  local health = as_object(root.health, "health")
  check_keys(health, HEALTH_KEYS, "health")
  if root.signature ~= nil then
    local signature = as_object(root.signature, "signature")
    check_keys(signature, SIGNATURE_KEYS, "signature")
    if not text_present(signature.algorithm) or not text_present(signature.keyId) then
      fail("plugin: manifest: signature requires algorithm and keyId")
    end
  end
  local capabilities = {}
  if root.capabilities ~= nil then
    if not json.is_array(root.capabilities) then
      fail("plugin: manifest: capabilities must be an array")
    end
    local seen = {}
    for _, item in ipairs(root.capabilities) do
      local capability = as_string(item, "capabilities")
      if capability == "" then fail("plugin: manifest: capability must not be empty") end
      if seen[capability] then fail("plugin: manifest: duplicate capability") end
      seen[capability] = true
      capabilities[#capabilities + 1] = capability
    end
  end
  return {
    schema_version = schema_version,
    id = id,
    version = version,
    kind = kind,
    entrypoint = entrypoint,
    protocol = protocol,
    capabilities = capabilities,
    permissions = permissions,
    limits = limits,
    isolation = isolation,
    health = health,
  }
end

return M
