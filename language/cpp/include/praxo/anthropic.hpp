#pragma once

#include <cctype>
#include <functional>
#include <sstream>
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
using AnthropicStreamTransport = std::function<std::string(
    const std::string& url, const Json& payload,
    const std::map<std::string, std::string>& headers)>;

class Anthropic : public Model {
public:
    Anthropic(AnthropicOptions options, AnthropicTransport transport,
              AnthropicStreamTransport stream_transport = {})
        : options_(std::move(options)),
          transport_(std::move(transport)),
          stream_transport_(std::move(stream_transport)) {}

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

    Response generate_stream(
            const Request& request,
            const std::function<void(const std::string&)>& on_delta) override {
        if (options_.base_url.empty()) {
            throw PraxoError("PROVIDER_HTTP", "provider base URL is required");
        }
        if (options_.api_key.empty()) {
            throw PraxoError("MODEL_CONFIG", "anthropic: API key is required");
        }
        if (options_.model.empty()) {
            throw PraxoError("MODEL_CONFIG", "anthropic: model is required");
        }
        if (!stream_transport_) {
            throw PraxoError(
                "PROVIDER_HTTP",
                "an Anthropic streaming transport is required");
        }
        std::map<std::string, std::string> headers{
            {"content-type", "application/json"},
            {"accept", "text/event-stream"},
            {"x-api-key", options_.api_key},
            {"anthropic-version", options_.version.empty()
                ? "2023-06-01" : options_.version}};
        Json payload = build_payload(request);
        payload["stream"] = true;
        return parse_sse(stream_transport_(endpoint(), payload, headers),
                         on_delta);
    }

    static Response parse_sse(
            const std::string& text,
            const std::function<void(const std::string&)>& on_delta) {
        Response response;
        response.message.role = ASSISTANT;
        std::string content;
        std::map<std::size_t, ToolCall> calls;
        std::map<std::size_t, std::string> arguments;
        int input_tokens = 0;
        int output_tokens = 0;
        int cached_tokens = 0;
        std::string stop_reason;
        bool stopped = false;
        std::istringstream stream(text);
        std::string raw;
        auto trim = [](const std::string& value) {
            std::size_t start = 0;
            std::size_t end = value.size();
            while (start < end &&
                   std::isspace(static_cast<unsigned char>(value[start]))) {
                ++start;
            }
            while (end > start &&
                   std::isspace(static_cast<unsigned char>(value[end - 1]))) {
                --end;
            }
            return value.substr(start, end - start);
        };
        while (std::getline(stream, raw)) {
            std::string line = trim(raw);
            if (line.rfind("data:", 0) != 0) continue;
            std::string chunk = trim(line.substr(5));
            if (chunk.empty()) continue;
            Json event;
            try {
                event = Json::parse(chunk);
            } catch (...) {
                throw PraxoError("MODEL_STREAM",
                                 "anthropic: invalid stream chunk");
            }
            const Json& type = event.at("type");
            const std::string kind = type.is_string()
                ? type.as_string() : "";
            if (kind == "message_start") {
                const Json& usage = event.at("message").at("usage");
                if (usage.at("input_tokens").is_number()) {
                    input_tokens =
                        static_cast<int>(usage.at("input_tokens").as_number());
                }
                if (usage.at("cache_read_input_tokens").is_number()) {
                    cached_tokens = static_cast<int>(
                        usage.at("cache_read_input_tokens").as_number());
                }
            } else if (kind == "content_block_start") {
                const Json& index_value = event.at("index");
                std::size_t index = index_value.is_number()
                    ? static_cast<std::size_t>(index_value.as_number()) : 0;
                const Json& block = event.at("content_block");
                const Json& block_type = block.at("type");
                if (block_type.is_string() &&
                    block_type.as_string() == "tool_use") {
                    ToolCall call;
                    call.id = block.at("id").is_string()
                        ? block.at("id").as_string() : "";
                    call.name = block.at("name").is_string()
                        ? block.at("name").as_string() : "";
                    calls[index] = call;
                }
            } else if (kind == "content_block_delta") {
                const Json& index_value = event.at("index");
                std::size_t index = index_value.is_number()
                    ? static_cast<std::size_t>(index_value.as_number()) : 0;
                const Json& delta = event.at("delta");
                const Json& delta_type = delta.at("type");
                if (delta_type.is_string() &&
                    delta_type.as_string() == "text_delta") {
                    const Json& piece = delta.at("text");
                    if (piece.is_string() && !piece.as_string().empty()) {
                        content += piece.as_string();
                        if (on_delta) on_delta(piece.as_string());
                    }
                } else if (delta_type.is_string() &&
                           delta_type.as_string() == "input_json_delta" &&
                           calls.count(index) > 0) {
                    const Json& partial = delta.at("partial_json");
                    if (partial.is_string()) {
                        arguments[index] += partial.as_string();
                    }
                }
            } else if (kind == "message_delta") {
                const Json& reason = event.at("delta").at("stop_reason");
                if (reason.is_string()) stop_reason = reason.as_string();
                const Json& usage = event.at("usage");
                if (usage.at("output_tokens").is_number()) {
                    output_tokens = static_cast<int>(
                        usage.at("output_tokens").as_number());
                }
            } else if (kind == "message_stop") {
                stopped = true;
            } else if (kind == "error") {
                throw PraxoError("MODEL_STREAM", "anthropic: stream error");
            }
        }
        if (!stopped && stop_reason.empty()) {
            throw PraxoError("MODEL_STREAM",
                             "anthropic: stream ended before completion");
        }
        for (auto& [index, call] : calls) {
            if (call.name.empty()) continue;
            const std::string& raw_arguments = arguments[index];
            if (!raw_arguments.empty()) {
                try {
                    call.arguments = Json::parse(raw_arguments);
                } catch (...) {
                    throw PraxoError("PROVIDER_JSON",
                                     "anthropic: invalid tool arguments");
                }
                if (!call.arguments.is_object()) {
                    throw PraxoError("PROVIDER_JSON",
                                     "anthropic: invalid tool arguments");
                }
            }
            response.message.tool_calls.push_back(call);
        }
        response.message.content = content;
        response.usage.input_tokens = input_tokens;
        response.usage.output_tokens = output_tokens;
        response.usage.cached_tokens = cached_tokens;
        if (!stop_reason.empty()) response.finish_reason = stop_reason;
        return response;
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
    AnthropicStreamTransport stream_transport_;
};

}  // namespace praxo
