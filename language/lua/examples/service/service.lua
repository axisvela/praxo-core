local function handle(method, path, principal, body)
  if method == "GET" and path == "/healthz" then
    return 200, { status = "ok" }
  end
  if method ~= "POST" or path ~= "/run" then
    return 404, { error = "not found" }
  end
  if principal == nil or principal == "" then
    return 401, { error = "missing X-Praxo-Principal" }
  end
  if not body:find('"prompt"', 1, true) then
    return 400, { error = "prompt is required" }
  end
  return 200, { output = "hello from the service" }
end

local status, body = handle("GET", "/healthz", nil, "")
assert(status == 200 and body.status == "ok")
status = handle("POST", "/run", nil, '{"prompt":"hi"}')
assert(status == 401)
status, body = handle("POST", "/run", "user-1", '{"prompt":"hi"}')
assert(status == 200 and body.output == "hello from the service")
print("Lua service example passed")
