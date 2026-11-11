#pragma once

#include <functional>
#include <map>
#include <string>
#include <utility>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/json.hpp"
#include "praxo/models.hpp"

namespace praxo {

struct AnthropicOptions {
    std::string base_url = "https://api.anthropic.com";
    std::string model;
    std::string api_key;
    std::string version = "2023-06-01";
    int max_tokens = 1024;
};

using AnthropicTransport = std::function<Json(
    const std::string& url, const Json& payload,
    const std::map<std::string, std::string>& headers)>;

class Anthropic : public Model {
public:
    Anthropic(AnthropicOptions options, AnthropicTransport transport)
        : options_(std::move(options)), transport_(std::move(transport)) {}

    Json build_payload(const Request& request) const {
        auto [system, messages] = build_messages(request.messages);
        Json payload = Json::object();
        payload["model"] = options_.model;
        payload["max_tokens"] = options_.max_tokens;
        payload["messages"] = messages;
        if (!system.empty()) payload["system"] = system;
        if (!request.tools.empty()) {
            Json tools = Json::array();
            for (const auto& tool : request.tools) {
                Json item = Json::object();
                item["name"] = tool.name;
                item["description"] = tool.description;
                item["input_schema"] = tool.parameters.is_null()
                    ? Json::parse(R"({"type":"object"})")
                    : tool.parameters;
                tools.push_back(item);
            }
            payload["tools"] = tools;
            if (request.tool_choice) {
                if (*request.tool_choice == "auto") {
                    payload["tool_choice"] = Json::parse(R"({"type":"auto"})");
                } else if (*request.tool_choice == "required") {
                    payload["tool_choice"] = Json::parse(R"({"type":"any"})");
                } else if (*request.tool_choice == "none") {
                    payload["tool_choice"] = Json::parse(R"({"type":"none"})");
                }
            }
        }
        if (request.temperature != 0) payload["temperature"] = request.temperature;
        return payload;
    }

    Response generate(const Request& request) override {
        if (options_.base_url.empty()) {
            throw PraxoError("PROVIDER_HTTP", "provider base URL is required");
        }
        if (options_.api_key.empty()) {
            throw PraxoError("MODEL_CONFIG", "anthropic: API key is required");
        }
        if (options_.model.empty()) {
            throw PraxoError("MODEL_CONFIG", "anthropic: model is required");
        }
        if (!transport_) {
            throw PraxoError("PROVIDER_HTTP",
                             "an Anthropic transport is required");
        }
        std::map<std::string, std::string> headers{
            {"content-type", "application/json"},
            {"x-api-key", options_.api_key},
            {"anthropic-version", options_.version.empty()
                ? "2023-06-01" : options_.version}};
        return parse_response(transport_(endpoint(), build_payload(request), headers));
    }

    static Response parse_response(const Json& data) {
        if (!data.at("error").is_null()) {
            throw PraxoError("PROVIDER_HTTP", "anthropic: provider error");
        }
        Response response;
        response.message.role = ASSISTANT;
        std::string text;
        const Json& blocks = data.at("content");
        if (blocks.is_array()) {
            for (const auto& block : blocks.as_array()) {
                const Json& type = block.at("type");
                if (type.is_string() && type.as_string() == "text") {
                    if (block.at("text").is_string()) {
                        text += block.at("text").as_string();
                    }
                } else if (type.is_string()
                           && type.as_string() == "tool_use") {
                    ToolCall call;
                    call.id = block.at("id").is_string()
                        ? block.at("id").as_string() : "";
                    call.name = block.at("name").is_string()
                        ? block.at("name").as_string() : "";
                    if (block.at("input").is_object()) {
                        call.arguments = block.at("input");
                    }
                    response.message.tool_calls.push_back(std::move(call));
                }
            }
        }
        response.message.content = text;
        const Json& usage = data.at("usage");
        if (usage.is_object()) {
            response.usage.input_tokens = number(usage.at("input_tokens"));
            response.usage.output_tokens = number(usage.at("output_tokens"));
            response.usage.cached_tokens = number(
                usage.at("cache_read_input_tokens"));
        }
        if (data.at("stop_reason").is_string()) {
            response.finish_reason = data.at("stop_reason").as_string();
        }
        return response;
    }

private:
    static int number(const Json& value) {
        return value.is_number() ? static_cast<int>(value.as_number()) : 0;
    }

    static std::pair<std::string, Json> build_messages(
            const std::vector<Message>& messages) {
        std::string system;
        Json out = Json::array();
        Json pending = Json::array();
        auto flush = [&]() {
            if (pending.as_array().empty()) return;
            Json group = Json::object();
            group["role"] = "user";
            group["content"] = pending;
            out.push_back(group);
            pending = Json::array();
        };
        for (const auto& message : messages) {
            if (message.role == SYSTEM) {
                if (message.content && !message.content->empty()) {
                    if (!system.empty()) system += "\n\n";
                    system += *message.content;
                }
                continue;
            }
            if (message.role == TOOL) {
                Json result = Json::object();
                result["type"] = "tool_result";
                result["tool_use_id"] = message.tool_id ? *message.tool_id : "";
                result["content"] = message.content ? *message.content : "";
                pending.push_back(result);
                continue;
            }
            flush();
            Json content = Json::array();
            if (message.content && !message.content->empty()) {
                Json text = Json::object();
                text["type"] = "text";
                text["text"] = *message.content;
                content.push_back(text);
            }
            for (const auto& block : message.content_blocks) {
                if (block.type == "text" && block.text && !block.text->empty()) {
                    Json text = Json::object();
                    text["type"] = "text";
                    text["text"] = *block.text;
                    content.push_back(text);
                }
            }
            for (const auto& call : message.tool_calls) {
                Json item = Json::object();
                item["type"] = "tool_use";
                item["id"] = call.id;
                item["name"] = call.name;
                item["input"] = call.arguments;
                content.push_back(item);
            }
            if (!content.as_array().empty()) {
                Json item = Json::object();
                item["role"] = message.role;
                item["content"] = content;
                out.push_back(item);
            }
        }
        flush();
        return {system, out};
    }

    std::string endpoint() const {
        std::string root = options_.base_url;
        while (!root.empty() && root.back() == '/') root.pop_back();
        return root + "/v1/messages";
    }

    AnthropicOptions options_;
    AnthropicTransport transport_;
};

}  // namespace praxo
