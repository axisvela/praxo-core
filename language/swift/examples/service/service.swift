func handle(method: String, path: String, principal: String, body: String) -> (Int, String) {
    if method == "GET" && path == "/healthz" { return (200, "{\"status\":\"ok\"}") }
    if method != "POST" || path != "/run" { return (404, "{\"error\":\"not found\"}") }
    if principal.isEmpty { return (401, "{\"error\":\"missing X-Praxo-Principal\"}") }
    if !body.contains("\"prompt\"") { return (400, "{\"error\":\"prompt is required\"}") }
    return (200, "{\"output\":\"hello from the service\"}")
}

precondition(handle(method: "GET", path: "/healthz", principal: "", body: "").0 == 200)
precondition(handle(method: "POST", path: "/run", principal: "", body: "{\"prompt\":\"hi\"}").0 == 401)
precondition(handle(method: "POST", path: "/run", principal: "user-1", body: "{\"prompt\":\"hi\"}").0 == 200)
print("Swift service example passed")
