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

struct GeminiOptions {
    std::string base_url = "https://generativelanguage.googleapis.com";
    std::string model;
    std::string api_key;
    int max_output_tokens = 0;
};

using GeminiTransport = std::function<Json(
    const std::string& url, const Json& payload,
    const std::map<std::string, std::string>& headers)>;

class Gemini : public Model {
public:
    Gemini(GeminiOptions options, GeminiTransport transport)
        : options_(std::move(options)), transport_(std::move(transport)) {}

    Json build_payload(const Request& request) const {
        auto [system, contents] = build_contents(request.messages);
        Json payload = Json::object();
        payload["contents"] = contents;
        if (!system.as_array().empty()) {
            Json instruction = Json::object();
            instruction["parts"] = system;
            payload["system_instruction"] = instruction;
        }
        if (!request.tools.empty()) {
            Json declarations = Json::array();
            for (const auto& tool : request.tools) {
                Json item = Json::object();
                item["name"] = tool.name;
                item["description"] = tool.description;
                item["parameters"] = tool.parameters.is_null()
                    ? Json::parse(R"({"type":"object"})")
                    : tool.parameters;
                declarations.push_back(item);
            }
            Json group = Json::object();
            group["functionDeclarations"] = declarations;
            Json tools = Json::array();
            tools.push_back(group);
            payload["tools"] = tools;
            payload["toolConfig"] = Json::parse(
                R"({"functionCallingConfig":{"mode":"AUTO"}})");
        }
        if (request.temperature != 0 || options_.max_output_tokens > 0) {
            Json generation = Json::object();
            generation["temperature"] = request.temperature;
            generation["maxOutputTokens"] = options_.max_output_tokens;
            payload["generationConfig"] = generation;
        }
        return payload;
    }

    Response generate(const Request& request) override {
        if (options_.base_url.empty()) {
            throw PraxoError("PROVIDER_HTTP", "provider base URL is required");
        }
        if (options_.api_key.empty()) {
            throw PraxoError("MODEL_CONFIG", "gemini: API key is required");
        }
        if (options_.model.empty()) {
            throw PraxoError("MODEL_CONFIG", "gemini: model is required");
        }
        if (!transport_) {
            throw PraxoError("PROVIDER_HTTP", "a Gemini transport is required");
        }
        std::map<std::string, std::string> headers{
            {"content-type", "application/json"},
            {"x-goog-api-key", options_.api_key}};
        return parse_response(transport_(endpoint(), build_payload(request), headers));
    }

    static Response parse_response(const Json& data) {
        if (!data.at("error").is_null()) {
            throw PraxoError("PROVIDER_HTTP", "gemini: provider error");
        }
        const Json& candidates = data.at("candidates");
        if (!candidates.is_array() || candidates.as_array().empty()) {
            throw PraxoError("PROVIDER_HTTP", "gemini: empty response");
        }
        const Json& candidate = candidates.as_array().front();
        const Json& parts = candidate.at("content").at("parts");
        Response response;
        response.message.role = ASSISTANT;
        std::string text;
        if (parts.is_array()) {
            for (const auto& part : parts.as_array()) {
                if (part.at("text").is_string()) {
                    text += part.at("text").as_string();
                }
                const Json& call = part.at("functionCall");
                if (call.is_object()) {
                    ToolCall tool;
                    tool.id = "call-" + std::to_string(
                        response.message.tool_calls.size() + 1);
                    tool.name = call.at("name").is_string()
                        ? call.at("name").as_string() : "";
                    if (call.at("args").is_object()) {
                        tool.arguments = call.at("args");
                    }
                    response.message.tool_calls.push_back(std::move(tool));
                }
            }
        }
        response.message.content = text;
        const Json& usage = data.at("usageMetadata");
        if (usage.is_object()) {
            response.usage.input_tokens = number(usage.at("promptTokenCount"));
            response.usage.output_tokens = number(
                usage.at("candidatesTokenCount"));
            response.usage.cached_tokens = number(
                usage.at("cachedContentTokenCount"));
        }
        if (candidate.at("finishReason").is_string()) {
            response.finish_reason = candidate.at("finishReason").as_string();
        }
        return response;
    }

private:
    static int number(const Json& value) {
        return value.is_number() ? static_cast<int>(value.as_number()) : 0;
    }

    static std::pair<Json, Json> build_contents(
            const std::vector<Message>& messages) {
        Json system = Json::array();
        Json contents = Json::array();
        Json pending = Json::array();
        auto flush = [&]() {
            if (pending.as_array().empty()) return;
            Json group = Json::object();
            group["role"] = "user";
            group["parts"] = pending;
            contents.push_back(group);
            pending = Json::array();
        };
        for (const auto& message : messages) {
            if (message.role == SYSTEM) {
                if (message.content && !message.content->empty()) {
                    Json part = Json::object();
                    part["text"] = *message.content;
                    system.push_back(part);
                }
                continue;
            }
            if (message.role == TOOL) {
                Json response = Json::object();
                response["result"] = message.content ? *message.content : "";
                Json function = Json::object();
                function["name"] = message.tool_id ? *message.tool_id : "tool";
                function["response"] = response;
                Json part = Json::object();
                part["functionResponse"] = function;
                pending.push_back(part);
                continue;
            }
            flush();
            Json parts = Json::array();
            if (message.content && !message.content->empty()) {
                Json text = Json::object();
                text["text"] = *message.content;
                parts.push_back(text);
            }
            for (const auto& block : message.content_blocks) {
                if (block.type == "text" && block.text && !block.text->empty()) {
                    Json text = Json::object();
                    text["text"] = *block.text;
                    parts.push_back(text);
                }
            }
            for (const auto& call : message.tool_calls) {
                Json function = Json::object();
                function["name"] = call.name;
                function["args"] = call.arguments;
                Json part = Json::object();
                part["functionCall"] = function;
                parts.push_back(part);
            }
            if (!parts.as_array().empty()) {
                Json group = Json::object();
                group["role"] = message.role == ASSISTANT ? "model" : "user";
                group["parts"] = parts;
                contents.push_back(group);
            }
        }
        flush();
        return {system, contents};
    }

    std::string endpoint() const {
        std::string root = options_.base_url;
        while (!root.empty() && root.back() == '/') root.pop_back();
        return root + "/v1beta/models/" + options_.model + ":generateContent";
    }

    GeminiOptions options_;
    GeminiTransport transport_;
};

}  // namespace praxo
