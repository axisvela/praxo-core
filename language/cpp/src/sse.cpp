#include "praxo/sse.hpp"

#include <cctype>
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

std::string parse_sse_stream(const std::string& text) {
    std::string content;
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
        if (!event.contains("choices") || !event.at("choices").is_array()) continue;
        for (const auto& choice : event.at("choices").as_array()) {
            if (!choice.is_object()) continue;
            if (choice.contains("delta") && choice.at("delta").is_object()) {
                const auto& delta = choice.at("delta");
                if (delta.contains("content") && delta.at("content").is_string()) {
                    content += delta.at("content").as_string();
                }
            }
            if (choice.contains("finish_reason") &&
                !choice.at("finish_reason").is_null()) {
                done = true;
            }
        }
    }
    if (!done) {
        throw PraxoError("MODEL_STREAM", "stream ended before completion");
    }
    return content;
}

}  // namespace praxo
