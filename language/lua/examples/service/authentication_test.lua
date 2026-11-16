local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

package.path = table.concat({
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  dir .. "/../../?.lua",
  dir .. "/../../?/init.lua",
  "./?.lua",
  package.path,
}, ";")

local auth = dofile(dir .. "/authentication.lua")

local function check(condition, message)
  if not condition then error(message) end
end

local function scripted(status, body)
  local calls = {}
  local transport = function(url, form, authorization)
    calls[#calls + 1] = { url = url, form = form, authorization = authorization }
    return status, body
  end
  return transport, calls
end

local function failing()
  local calls = {}
  local transport = function(url, form, authorization)
    calls[#calls + 1] = { url = url, form = form, authorization = authorization }
    error("unavailable")
  end
  return transport, calls
end

local function error_message(fn)
  local ok, err = pcall(fn)
  if ok then return nil end
  if type(err) == "table" then return err.message end
  return tostring(err)
end

local function active_body(now)
  return string.format(
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":%d}',
    now + 60
  )
end

local now = 1700000000

local context = auth.ContextAuthenticator.new("tenant-a")
local principal = context:authenticate("user-1")
check(principal.subject == "user-1", "context subject")
check(principal.tenant == "tenant-a", "context tenant")
check(principal.expires == nil, "context expires")
check(context:authenticate(nil) == nil, "context missing principal")
check(context:authenticate("") == nil, "context empty principal")

local transport, calls = scripted(200, active_body(now))
local authenticator = auth.IntrospectionAuthenticator.new({
  transport = transport,
  endpoint = "https://idp.example/introspect",
  client_id = "svc",
  client_secret = "secret",
})
principal = authenticator:authenticate("Bearer token-1", now)
check(principal ~= nil, "introspection success")
check(principal.subject == "user-1", "introspection subject")
check(principal.tenant == "tenant-a", "introspection tenant")
check(principal.expires == now + 60, "introspection expires")
check(#calls == 1, "introspection call count")
check(calls[1].url == "https://idp.example/introspect", "introspection endpoint")
check(calls[1].form.token == "token-1", "introspection token")
check(calls[1].form.client_id == "svc", "introspection client id")
check(calls[1].form.client_secret == "secret", "introspection client secret")
check(calls[1].authorization == "Basic c3ZjOnNlY3JldA==", "introspection basic auth")

local local_transport, local_calls = scripted(200, active_body(now))
local local_auth = auth.IntrospectionAuthenticator.new({
  transport = local_transport,
  endpoint = "https://idp.example",
  client_id = "svc",
  client_secret = "secret",
})
check(local_auth:authenticate(nil, now) == nil, "missing bearer")
check(local_auth:authenticate("Basic token", now) == nil, "wrong scheme")
check(local_auth:authenticate("Bearer   ", now) == nil, "empty token")
check(#local_calls == 0, "rejected requests are local")

local rejected = {
  '{"active":false,"sub":"user-1","tenant":"tenant-a","exp":1700000060}',
  '{"active":true,"sub":"","tenant":"tenant-a","exp":1700000060}',
  '{"active":true,"tenant":"tenant-a","exp":1700000060}',
  '{"active":true,"sub":"user-1","tenant":"","exp":1700000060}',
  '{"active":true,"sub":"user-1","exp":1700000060}',
  '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000000}',
  '{"active":true,"sub":"user-1","tenant":"tenant-a"}',
  "not-json",
  "[]",
}
for _, body in ipairs(rejected) do
  local reject_transport = scripted(200, body)
  local reject_auth = auth.IntrospectionAuthenticator.new({
    transport = reject_transport,
    endpoint = "https://idp.example",
  })
  check(reject_auth:authenticate("Bearer token-1", now) == nil, "rejected introspection body")
end

local status_transport = scripted(500, active_body(now))
local status_auth = auth.IntrospectionAuthenticator.new({
  transport = status_transport,
  endpoint = "https://idp.example",
})
check(status_auth:authenticate("Bearer token-1", now) == nil, "non-200 introspection")

local error_transport = failing()
local error_auth = auth.IntrospectionAuthenticator.new({
  transport = error_transport,
  endpoint = "https://idp.example",
})
check(error_auth:authenticate("Bearer token-1", now) == nil, "introspection transport error")

local custom_transport = scripted(
  200,
  '{"active":true,"sub":"user-1","org":"org-a","exp":1700000060}'
)
local custom_auth = auth.IntrospectionAuthenticator.new({
  transport = custom_transport,
  endpoint = "https://idp.example",
  tenant_claim = "org",
})
principal = custom_auth:authenticate("Bearer token-1", now)
check(principal ~= nil and principal.tenant == "org-a", "custom tenant claim")

local revocation_transport, revocation_calls = scripted(200, "")
local client = auth.RevocationClient.new({
  transport = revocation_transport,
  endpoint = "https://idp.example/revoke",
  client_id = "svc",
  client_secret = "secret",
})
check(client:revoke("token-1") == true, "revocation result")
check(#revocation_calls == 1, "revocation call count")
check(revocation_calls[1].form.token == "token-1", "revocation token")
check(revocation_calls[1].form.token_type_hint == "access_token", "revocation hint")
check(
  revocation_calls[1].authorization == "Basic c3ZjOnNlY3JldA==",
  "revocation basic auth"
)

local rejected_transport = scripted(400, "")
local rejected_client = auth.RevocationClient.new({
  transport = rejected_transport,
  endpoint = "https://idp.example/revoke",
})
check(
  error_message(function() rejected_client:revoke("token-1") end) == "token revocation failed",
  "revocation non-200"
)

local revocation_error_transport = failing()
local revocation_error_client = auth.RevocationClient.new({
  transport = revocation_error_transport,
  endpoint = "https://idp.example/revoke",
})
check(
  error_message(function() revocation_error_client:revoke("token-1") end)
    == "token revocation failed",
  "revocation transport error"
)

local empty_transport, empty_calls = scripted(200, "")
local empty_client = auth.RevocationClient.new({
  transport = empty_transport,
  endpoint = "https://idp.example/revoke",
})
check(
  error_message(function() empty_client:revoke("") end) == "revocation token is required",
  "revocation empty token"
)
check(#empty_calls == 0, "empty revocation is local")

print("Lua service auth tests passed")
