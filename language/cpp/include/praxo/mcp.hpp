#pragma once

#include <functional>
#include <set>
#include <string>
#include <utility>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"

namespace praxo {

using McpTransport = std::function<Json(const std::string& method, const Json& params)>;

class McpClient {
public:
    explicit McpClient(McpTransport transport, std::string client_version = "",
                       std::string protocol_version = "")
        : transport_(std::move(transport)) {
        if (!transport_) {
            throw PraxoError("MCP_TRANSPORT", "mcp: transport is required");
        }
        client_version_ = client_version.empty() ? "0.6.0" : std::move(client_version);
        const std::string requested = protocol_version.empty()
            ? "2024-11-05" : protocol_version;
        Json params = Json::object();
        params["protocolVersion"] = requested;
        params["capabilities"] = Json::object();
        Json info = Json::object();
        info["name"] = "praxo-core";
        info["version"] = client_version_;
        params["clientInfo"] = info;
        const Json result = transport_("initialize", params);
        if (!result.is_object()) {
            throw PraxoError("MCP_PROTOCOL", "mcp: initialize result must be an object");
        }
        const Json& negotiated = result.at("protocolVersion");
        if (!negotiated.is_string() || negotiated.as_string().empty()) {
            throw PraxoError("MCP_HANDSHAKE",
                             "mcp: initialize returned no protocol version");
        }
        protocol_version_ = negotiated.as_string();
        server_info_ = result.at("serverInfo").is_object()
            ? result.at("serverInfo") : Json::object();
    }

    const std::string& protocol_version() const { return protocol_version_; }
    const Json& server_info() const { return server_info_; }
    bool closed() const { return closed_; }

    Json list_tools() const {
        Json tools = Json::array();
        std::set<std::string> names;
        std::set<std::string> cursors;
        std::string cursor;
        for (;;) {
            Json params = Json::object();
            if (!cursor.empty()) {
                params["cursor"] = cursor;
            }
            const Json result = transport_("tools/list", params);
            if (!result.is_object() || !result.at("tools").is_array()) {
                throw PraxoError("MCP_PROTOCOL",
                                 "mcp: tools/list tools must be an array");
            }
            for (const auto& item : result.at("tools").as_array()) {
                if (!item.is_object() || !item.at("name").is_string() ||
                        item.at("name").as_string().empty()) {
                    throw PraxoError("MCP_PROTOCOL", "mcp: tool name is required");
                }
                const std::string name = item.at("name").as_string();
                if (!names.insert(name).second) {
                    throw PraxoError("MCP_DUPLICATE_TOOL",
                                     "mcp: duplicate tool " + name);
                }
                tools.push_back(item);
            }
            const Json& next = result.at("nextCursor");
            if (next.is_null()) {
                break;
            }
            if (!next.is_string()) {
                throw PraxoError("MCP_PROTOCOL", "mcp: nextCursor must be a string");
            }
            if (next.as_string().empty()) {
                break;
            }
            if (!cursors.insert(next.as_string()).second) {
                throw PraxoError("MCP_PAGINATION",
                                 "mcp: repeated tool pagination cursor");
            }
            cursor = next.as_string();
        }
        return tools;
    }

    Json call_tool(const std::string& name, const Json& arguments = Json::object()) const {
        if (name.empty()) {
            throw PraxoError("MCP_PROTOCOL", "mcp: tool name is required");
        }
        Json params = Json::object();
        params["name"] = name;
        params["arguments"] = arguments;
        const Json result = transport_("tools/call", params);
        if (!result.is_object()) {
            throw PraxoError("MCP_PROTOCOL",
                             "mcp: tools/call result must be an object");
        }
        if (result.at("isError").is_bool() && result.at("isError").as_bool()) {
            throw PraxoError("MCP_TOOL_ERROR", "mcp: tool " + name + " failed");
        }
        if (result.contains("structuredContent")) {
            return result.at("structuredContent");
        }
        Json texts = Json::array();
        if (result.at("content").is_array()) {
            for (const auto& item : result.at("content").as_array()) {
                if (item.is_object() && item.at("type").is_string() &&
                        item.at("type").as_string() == "text" &&
                        item.at("text").is_string()) {
                    texts.push_back(item.at("text"));
                }
            }
        }
        if (texts.size() == 0) {
            return Json(nullptr);
        }
        if (texts.size() == 1) {
            return texts.as_array().front();
        }
        return texts;
    }

    void close() { closed_ = true; }

private:
    McpTransport transport_;
    std::string client_version_;
    std::string protocol_version_;
    Json server_info_ = Json::object();
    bool closed_ = false;
};

}  // namespace praxo
