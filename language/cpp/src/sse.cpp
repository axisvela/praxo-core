#include "praxo/sse.hpp"

#include <cctype>
#include <map>
#include <sstream>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"

namespace praxo {

namespace {

std::string trim(const std::string& value) {
    std::size_t start = 0;
    std::size_t end = value.size();
    while (start < end && std::isspace(static_cast<unsigned char>(value[start]))) {
        ++start;
    }
    while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1]))) {
        --end;
    }
    return value.substr(start, end - start);
}

}  // namespace

Response parse_sse_response(
        const std::string& text,
        const std::function<void(const std::string&)>& on_delta) {
    Response response;
    response.message.role = ASSISTANT;
    std::string content;
    std::map<std::size_t, ToolCall> calls;
    std::map<std::size_t, std::string> arguments;
    std::size_t call_count = 0;
    std::string finish_reason;
    bool done = false;
    std::istringstream stream(text);
    std::string raw;
    while (std::getline(stream, raw)) {
        std::string line = trim(raw);
        if (line.rfind("data:", 0) != 0) continue;
        std::string chunk = trim(line.substr(5));
        if (chunk.empty()) continue;
        if (chunk == "[DONE]") {
            done = true;
            break;
        }
        Json event;
        try {
            event = Json::parse(chunk);
        } catch (...) {
            throw PraxoError("MODEL_STREAM", "invalid SSE packet");
        }
        if (!event.is_object()) continue;
        if (event.contains("usage") && event.at("usage").is_object()) {
            const Json& usage = event.at("usage");
            if (usage.contains("prompt_tokens") && usage.at("prompt_tokens").is_number()) {
                response.usage.input_tokens =
                    static_cast<int>(usage.at("prompt_tokens").as_number());
            }
            if (usage.contains("completion_tokens") &&
                usage.at("completion_tokens").is_number()) {
                response.usage.output_tokens =
                    static_cast<int>(usage.at("completion_tokens").as_number());
            }
        }
        if (!event.contains("choices") || !event.at("choices").is_array()) continue;
        for (const auto& choice : event.at("choices").as_array()) {
            if (!choice.is_object()) continue;
            if (choice.contains("finish_reason") &&
                choice.at("finish_reason").is_string()) {
                finish_reason = choice.at("finish_reason").as_string();
            }
            if (!choice.contains("delta") || !choice.at("delta").is_object()) continue;
            const Json& delta = choice.at("delta");
            if (delta.contains("content") && delta.at("content").is_string()) {
                const std::string piece = delta.at("content").as_string();
                if (!piece.empty()) {
                    content += piece;
                    if (on_delta) on_delta(piece);
                }
            }
            if (!delta.contains("tool_calls") || !delta.at("tool_calls").is_array()) {
                continue;
            }
            for (const auto& item : delta.at("tool_calls").as_array()) {
                if (!item.is_object()) continue;
                std::size_t index = call_count;
                if (item.contains("index") && item.at("index").is_number()) {
                    index = static_cast<std::size_t>(item.at("index").as_number());
                }
                if (index + 1 > call_count) call_count = index + 1;
                ToolCall& call = calls[index];
                if (item.contains("id") && item.at("id").is_string()) {
                    call.id += item.at("id").as_string();
                }
                if (item.contains("function") && item.at("function").is_object()) {
                    const Json& function = item.at("function");
                    if (function.contains("name") && function.at("name").is_string()) {
                        call.name += function.at("name").as_string();
                    }
                    if (function.contains("arguments") &&
                        function.at("arguments").is_string()) {
                        arguments[index] += function.at("arguments").as_string();
                    }
                }
            }
        }
    }
    if (!done && finish_reason.empty()) {
        throw PraxoError("MODEL_STREAM", "stream ended before completion");
    }
    response.message.content = content;
    for (auto& [index, call] : calls) {
        if (call.name.empty()) continue;
        const std::string& raw_arguments = arguments[index];
        if (!raw_arguments.empty()) {
            try {
                call.arguments = Json::parse(raw_arguments);
            } catch (...) {
                throw PraxoError("PROVIDER_JSON", "invalid tool arguments");
            }
            if (!call.arguments.is_object()) {
                throw PraxoError("PROVIDER_JSON", "invalid tool arguments");
            }
        }
        response.message.tool_calls.push_back(call);
    }
    if (!finish_reason.empty()) response.finish_reason = finish_reason;
    return response;
}

std::string parse_sse_stream(const std::string& text) {
    Response response = parse_sse_response(text);
    return response.message.content.value_or("");
}

}  // namespace praxo
