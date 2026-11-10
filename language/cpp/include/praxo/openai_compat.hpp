#pragma once

#include <functional>
#include <map>
#include <string>
#include <utility>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"
#include "praxo/models.hpp"

namespace praxo {

struct OpenAICompatibleOptions {
    std::string base_url;
    std::string model;
    std::string api_key;
};

using OpenAICompatibleTransport = std::function<Json(
    const std::string& url, const Json& payload,
    const std::map<std::string, std::string>& headers)>;

class OpenAICompatible : public Model {
public:
    OpenAICompatible(OpenAICompatibleOptions options,
                     OpenAICompatibleTransport transport)
        : options_(std::move(options)), transport_(std::move(transport)) {}

    Json build_payload(const Request& request) const {
        Json messages = Json::array();
        for (const auto& message : request.messages) {
            Json item = Json::object();
            item["role"] = message.role;
            item["content"] = content_text(message);
            if (message.role == ASSISTANT && !message.tool_calls.empty()) {
                Json calls = Json::array();
                for (const auto& call : message.tool_calls) {
                    Json entry = Json::object();
                    entry["id"] = call.id;
                    entry["type"] = "function";
                    Json function = Json::object();
                    function["name"] = call.name;
                    function["arguments"] = call.arguments.dump();
                    entry["function"] = function;
                    calls.push_back(entry);
                }
                item["tool_calls"] = calls;
            }
            if (message.role == TOOL && message.tool_id) {
                item["tool_call_id"] = *message.tool_id;
            }
            messages.push_back(item);
        }
        Json payload = Json::object();
        payload["model"] = options_.model;
        payload["messages"] = messages;
        if (!request.tools.empty()) {
            Json tools = Json::array();
            for (const auto& tool : request.tools) {
                Json entry = Json::object();
                entry["type"] = "function";
                Json function = Json::object();
                function["name"] = tool.name;
                function["description"] = tool.description;
                function["parameters"] = tool.parameters.is_null()
                    ? Json::parse(R"({"type":"object"})")
                    : tool.parameters;
                entry["function"] = function;
                tools.push_back(entry);
            }
            payload["tools"] = tools;
        }
        if (request.tool_choice) payload["tool_choice"] = *request.tool_choice;
        if (!request.response_format.is_null()) {
            payload["response_format"] = request.response_format;
        }
        if (request.temperature != 0) payload["temperature"] = request.temperature;
        return payload;
    }

    Response generate(const Request& request) override {
        if (options_.base_url.empty()) {
            throw PraxoError("PROVIDER_HTTP", "provider base URL is required");
        }
        if (!transport_) {
            throw PraxoError("PROVIDER_HTTP",
                             "an OpenAI-compatible transport is required");
        }
        std::map<std::string, std::string> headers{
            {"content-type", "application/json"}};
        if (!options_.api_key.empty()) {
            headers["authorization"] = "Bearer " + options_.api_key;
        }
        return parse_response(transport_(endpoint(), build_payload(request), headers));
    }

    static Response parse_response(const Json& data) {
        Response response;
        const Json& choices = data.at("choices");
        const Json& choice = choices.is_array() && !choices.as_array().empty()
            ? choices.as_array().front()
            : Json(nullptr);
        const Json& message = choice.at("message");
        response.message.role = ASSISTANT;
        response.message.content = message.at("content").is_string()
            ? message.at("content").as_string()
            : std::string();
        const Json& calls = message.at("tool_calls");
        if (calls.is_array()) {
            for (const auto& item : calls.as_array()) {
                const Json& function = item.at("function");
                ToolCall call;
                call.id = item.at("id").is_string() ? item.at("id").as_string() : "";
                call.name = function.at("name").is_string()
                    ? function.at("name").as_string()
                    : "";
                const Json& arguments = function.at("arguments");
                if (arguments.is_string() && !arguments.as_string().empty()) {
                    try {
                        call.arguments = Json::parse(arguments.as_string());
                    } catch (const std::exception&) {
                        throw PraxoError("PROVIDER_JSON", "invalid tool arguments");
                    }
                }
                response.message.tool_calls.push_back(std::move(call));
            }
        }
        const Json& usage = data.at("usage");
        if (usage.is_object()) {
            response.usage.input_tokens = usage.at("prompt_tokens").is_number()
                ? static_cast<int>(usage.at("prompt_tokens").as_number())
                : 0;
            response.usage.output_tokens = usage.at("completion_tokens").is_number()
                ? static_cast<int>(usage.at("completion_tokens").as_number())
                : 0;
        }
        if (choice.at("finish_reason").is_string()) {
            response.finish_reason = choice.at("finish_reason").as_string();
        }
        return response;
    }

private:
    static std::string content_text(const Message& message) {
        if (message.content && !message.content->empty()) return *message.content;
        std::string text;
        for (const auto& block : message.content_blocks) {
            if (block.type == "text" && block.text) text += *block.text;
        }
        return text;
    }

    std::string endpoint() const {
        std::string root = options_.base_url;
        while (!root.empty() && root.back() == '/') root.pop_back();
        const std::string suffix = "/chat/completions";
        if (root.size() >= suffix.size() &&
            root.compare(root.size() - suffix.size(), suffix.size(), suffix) == 0) {
            return root;
        }
        return root + suffix;
    }

    OpenAICompatibleOptions options_;
    OpenAICompatibleTransport transport_;
};

}  // namespace praxo
