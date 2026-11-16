func handle(method: String, path: String, principal: String, body: String) -> (Int, String) {
    if method == "GET" && path == "/healthz" { return (200, "{\"status\":\"ok\"}") }
    if method != "POST" || path != "/run" { return (404, "{\"error\":\"not found\"}") }
    if principal.isEmpty { return (401, "{\"error\":\"missing X-Praxo-Principal\"}") }
    if !body.contains("\"prompt\"") { return (400, "{\"error\":\"prompt is required\"}") }
    return (200, "{\"output\":\"hello from the service\"}")
}
