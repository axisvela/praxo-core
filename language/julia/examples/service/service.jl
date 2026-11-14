function handle(method, path, principal, body)
    method == "GET" && path == "/healthz" && return (200, "{\"status\":\"ok\"}")
    (method != "POST" || path != "/run") && return (404, "{\"error\":\"not found\"}")
    isempty(principal) && return (401, "{\"error\":\"missing X-Praxo-Principal\"}")
    !occursin("\"prompt\"", body) && return (400, "{\"error\":\"prompt is required\"}")
    return (200, "{\"output\":\"hello from the service\"}")
end

@assert handle("GET", "/healthz", "", "")[1] == 200
@assert handle("POST", "/run", "", "{\"prompt\":\"hi\"}")[1] == 401
@assert handle("POST", "/run", "user-1", "{\"prompt\":\"hi\"}")[1] == 200
println("Julia service example passed")
