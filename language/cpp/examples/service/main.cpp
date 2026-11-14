#include <cassert>
#include <iostream>
#include <optional>
#include <string>

struct Response {
    int status;
    std::string body;
};

Response handle(const std::string& method, const std::string& path,
                const std::optional<std::string>& principal,
                const std::string& body) {
    if (method == "GET" && path == "/healthz") {
        return {200, R"({"status":"ok"})"};
    }
    if (method != "POST" || path != "/run") {
        return {404, R"({"error":"not found"})"};
    }
    if (!principal || principal->empty()) {
        return {401, R"({"error":"missing X-Praxo-Principal"})"};
    }
    if (body.find("\"prompt\"") == std::string::npos) {
        return {400, R"({"error":"prompt is required"})"};
    }
    return {200, R"({"output":"hello from the service"})"};
}

int main() {
    assert(handle("GET", "/healthz", std::nullopt, "").status == 200);
    assert(handle("POST", "/run", std::nullopt, R"({"prompt":"hi"})").status == 401);
    auto ok = handle("POST", "/run", "user-1", R"({"prompt":"hi"})");
    assert(ok.status == 200 && ok.body.find("hello from the service") != std::string::npos);
    std::cout << "C++ service example passed\n";
    return 0;
}
