#include "praxo/mcp.hpp"

#include <cassert>
#include <string>

using namespace praxo;

namespace {

enum Mode {
    MODE_OK,
    MODE_DUPLICATE,
    MODE_REPEATED_CURSOR,
    MODE_TOOL_ERROR,
    MODE_STRUCTURED
};

Json transport(const std::string& method, const Json& params, Mode mode) {
    if (method == "initialize") {
        return Json::parse(
            "{\"protocolVersion\":\"2024-11-05\","
            "\"serverInfo\":{\"name\":\"fake\"}}");
    }
    if (method == "tools/list") {
        if (mode == MODE_DUPLICATE) {
            return Json::parse("{\"tools\":[{\"name\":\"echo\"},{\"name\":\"echo\"}]}");
        }
        if (mode == MODE_REPEATED_CURSOR) {
            return Json::parse("{\"tools\":[],\"nextCursor\":\"c1\"}");
        }
        const Json& cursor = params.at("cursor");
        if (cursor.is_string() && cursor.as_string() == "c1") {
            return Json::parse("{\"tools\":[{\"name\":\"two\"}]}");
        }
        return Json::parse(
            "{\"tools\":[{\"name\":\"echo\",\"description\":\"Echo\"}],"
            "\"nextCursor\":\"c1\"}");
    }
    if (method == "tools/call") {
        if (mode == MODE_TOOL_ERROR) {
            return Json::parse("{\"isError\":true}");
        }
        if (mode == MODE_STRUCTURED) {
            return Json::parse("{\"structuredContent\":{\"ok\":true}}");
        }
        return Json::parse("{\"content\":[{\"type\":\"text\",\"text\":\"ok\"}]}");
    }
    return Json::object();
}

std::string error_code(Mode mode) {
    try {
        McpClient client([mode](const std::string& method, const Json& params) {
            return transport(method, params, mode);
        });
        if (mode == MODE_DUPLICATE || mode == MODE_REPEATED_CURSOR) {
            client.list_tools();
        } else {
            client.call_tool("echo");
        }
    } catch (const PraxoError& error) {
        return error.code();
    }
    return "";
}

}  // namespace

int main() {
    Mode mode = MODE_OK;
    McpClient client([&mode](const std::string& method, const Json& params) {
        return transport(method, params, mode);
    });
    assert(client.protocol_version() == "2024-11-05");
    const Json tools = client.list_tools();
    assert(tools.is_array() && tools.size() == 2);
    assert(tools.as_array()[0].at("name").as_string() == "echo");
    assert(tools.as_array()[1].at("name").as_string() == "two");
    const Json value = client.call_tool("echo");
    assert(value.is_string() && value.as_string() == "ok");

    mode = MODE_STRUCTURED;
    const Json structured = client.call_tool("echo");
    assert(structured.is_object() && structured.at("ok").as_bool());

    assert(error_code(MODE_DUPLICATE) == "MCP_DUPLICATE_TOOL");
    assert(error_code(MODE_REPEATED_CURSOR) == "MCP_PAGINATION");
    assert(error_code(MODE_TOOL_ERROR) == "MCP_TOOL_ERROR");

    client.close();
    assert(client.closed());
    return 0;
}
