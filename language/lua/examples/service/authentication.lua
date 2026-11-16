local json = require("praxo.json")

local M = {}

local Principal = {}
Principal.__index = Principal

function Principal.new(subject, tenant, expires)
  return setmetatable({ subject = subject, tenant = tenant, expires = expires }, Principal)
end

M.Principal = Principal

local AuthError = {}
AuthError.__index = AuthError

function AuthError.new(message)
  return setmetatable({ message = message }, AuthError)
end

AuthError.__tostring = function(self)
  return self.message
end

M.AuthError = AuthError

local ContextAuthenticator = {}
ContextAuthenticator.__index = ContextAuthenticator

function ContextAuthenticator.new(tenant)
  return setmetatable({ tenant = tenant }, ContextAuthenticator)
end

function ContextAuthenticator:authenticate(principal)
  if type(principal) ~= "string" or principal == "" then return nil end
  return Principal.new(principal, self.tenant, nil)
end

M.ContextAuthenticator = ContextAuthenticator

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function encode_byte(triple, shift)
  local index = math.floor(triple / shift) % 64 + 1
  return alphabet:sub(index, index)
end

local function base64(value)
  local out = {}
  local index = 1
  while index <= #value do
    local first = value:byte(index) or 0
    local second = value:byte(index + 1)
    local third = value:byte(index + 2)
    local triple = first * 65536 + (second or 0) * 256 + (third or 0)
    out[#out + 1] = encode_byte(triple, 262144)
    out[#out + 1] = encode_byte(triple, 4096)
    out[#out + 1] = second and encode_byte(triple, 64) or "="
    out[#out + 1] = third and encode_byte(triple, 1) or "="
    index = index + 3
  end
  return table.concat(out)
end

local function basic_auth(client_id, client_secret)
  if client_id == "" then return nil end
  return "Basic " .. base64(client_id .. ":" .. client_secret)
end

local IntrospectionAuthenticator = {}
IntrospectionAuthenticator.__index = IntrospectionAuthenticator

function IntrospectionAuthenticator.new(options)
  local tenant_claim = options.tenant_claim or "tenant"
  if tenant_claim == "" then tenant_claim = "tenant" end
  return setmetatable({
    transport = assert(options.transport, "transport is required"),
    endpoint = assert(options.endpoint, "endpoint is required"),
    client_id = options.client_id or "",
    client_secret = options.client_secret or "",
    tenant_claim = tenant_claim,
  }, IntrospectionAuthenticator)
end

function IntrospectionAuthenticator:authenticate(authorization, now)
  if type(authorization) ~= "string" or authorization:sub(1, 7) ~= "Bearer " then
    return nil
  end
  local token = authorization:sub(8):match("^%s*(.-)%s*$")
  if token == "" then return nil end
  now = now or os.time()
  local form = {
    token = token,
    client_id = self.client_id,
    client_secret = self.client_secret,
  }
  local ok, status, body =
    pcall(self.transport, self.endpoint, form, basic_auth(self.client_id, self.client_secret))
  if not ok or status ~= 200 or type(body) ~= "string" then return nil end
  local parsed_ok, payload = pcall(json.parse, body)
  if not parsed_ok or type(payload) ~= "table" or payload == json.null or json.is_array(payload) then
    return nil
  end
  if payload.active ~= true then return nil end
  local subject = payload.sub
  if type(subject) ~= "string" or subject == "" then return nil end
  local tenant = payload[self.tenant_claim]
  if type(tenant) ~= "string" or tenant == "" then return nil end
  local expires = payload.exp
  if type(expires) ~= "number" then return nil end
  if math.type and math.type(expires) ~= "integer" then return nil end
  if expires <= now then return nil end
  return Principal.new(subject, tenant, expires)
end

M.IntrospectionAuthenticator = IntrospectionAuthenticator

local RevocationClient = {}
RevocationClient.__index = RevocationClient

function RevocationClient.new(options)
  return setmetatable({
    transport = assert(options.transport, "transport is required"),
    endpoint = assert(options.endpoint, "endpoint is required"),
    client_id = options.client_id or "",
    client_secret = options.client_secret or "",
  }, RevocationClient)
end

function RevocationClient:revoke(token)
  if type(token) ~= "string" or token == "" then
    error(AuthError.new("revocation token is required"))
  end
  local form = {
    token = token,
    token_type_hint = "access_token",
    client_id = self.client_id,
    client_secret = self.client_secret,
  }
  local ok, status =
    pcall(self.transport, self.endpoint, form, basic_auth(self.client_id, self.client_secret))
  if not ok or status ~= 200 then
    error(AuthError.new("token revocation failed"))
  end
  return true
end

M.RevocationClient = RevocationClient

return M
