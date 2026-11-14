#include <cassert>
#include <iostream>
#include <string>

#include "praxo/mcp.hpp"

praxo::Json transport(const std::string& method, const praxo::Json& params) {
    (void)params;
    if (method == "initialize") {
        return praxo::Json::parse(
            R"({"protocolVersion":"2024-11-05","serverInfo":{"name":"example-mcp"}})");
    }
    if (method == "tools/list") {
        return praxo::Json::parse(
            R"({"tools":[{"name":"echo","description":"Echo input"},{"name":"add","description":"Add two integers"}]})");
    }
    if (method == "tools/call") {
        return praxo::Json::parse(R"({"structuredContent":{"sum":5}})");
    }
    return praxo::Json::parse(R"({"error":"method not found"})");
}

int main() {
    praxo::McpClient client(transport);
    auto tools = client.list_tools();
    assert(tools.is_array() && tools.size() == 2);
    assert(tools.as_array()[0].at("name").as_string() == "echo");
    assert(tools.as_array()[1].at("name").as_string() == "add");
    auto value = client.call_tool("add");
    assert(value.is_object() && value.at("sum").as_number() == 5);
    client.close();
    std::cout << "C++ MCP example passed\n";
    return 0;
}
