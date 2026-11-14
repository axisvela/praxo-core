import std.string : indexOf;
import std.stdio;

struct Response {
    int status;
    string body;
}

Response handle(string method, string path, string principal, string body) {
    if (method == "GET" && path == "/healthz") {
        return Response(200, `{"status":"ok"}`);
    }
    if (method != "POST" || path != "/run") {
        return Response(404, `{"error":"not found"}`);
    }
    if (principal.length == 0) {
        return Response(401, `{"error":"missing X-Praxo-Principal"}`);
    }
    if (body.indexOf("\"prompt\"") < 0) {
        return Response(400, `{"error":"prompt is required"}`);
    }
    return Response(200, `{"output":"hello from the service"}`);
}

void main() {
    assert(handle("GET", "/healthz", "", "").status == 200);
    assert(handle("POST", "/run", "", `{"prompt":"hi"}`).status == 401);
    assert(handle("POST", "/run", "user-1", `{"prompt":"hi"}`).status == 200);
    writeln("D service example passed");
}
