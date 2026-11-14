proc handle(method, path, principal, body: string): (int, string) =
  if method == "GET" and path == "/healthz": return (200, "{\"status\":\"ok\"}")
  if method != "POST" or path != "/run": return (404, "{\"error\":\"not found\"}")
  if principal.len == 0: return (401, "{\"error\":\"missing X-Praxo-Principal\"}")
  if "\"prompt\"" notin body: return (400, "{\"error\":\"prompt is required\"}")
  (200, "{\"output\":\"hello from the service\"}")

doAssert handle("GET", "/healthz", "", "")[0] == 200
doAssert handle("POST", "/run", "", "{\"prompt\":\"hi\"}")[0] == 401
doAssert handle("POST", "/run", "user-1", "{\"prompt\":\"hi\"}")[0] == 200
echo "Nim service example passed"
