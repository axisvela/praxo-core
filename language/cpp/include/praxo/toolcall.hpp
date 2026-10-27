#pragma once

#include <optional>
#include <string>

#include "praxo/json.hpp"

namespace praxo {

struct ParsedToolCall {
    std::string call_id;
    std::string name;
    Json input = Json::object();
    std::string operation;
    std::string resource;
    std::string risk;
    std::string reason;
    std::string idempotency_key;
};

std::optional<ParsedToolCall> parse_toolcall(const std::string& content);
std::string strip_markup(const std::string& content);
std::optional<Json> parse_input_json(const std::string& raw);

}  // namespace praxo
