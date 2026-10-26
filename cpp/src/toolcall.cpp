#include "praxo/toolcall.hpp"

#include <cctype>
#include <chrono>
#include <regex>

namespace praxo {

namespace {

std::string trim(const std::string& value) {
    std::size_t start = 0;
    std::size_t end = value.size();
    while (start < end && std::isspace(static_cast<unsigned char>(value[start]))) ++start;
    while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1]))) --end;
    return value.substr(start, end - start);
}

std::optional<std::smatch> last_match(const std::string& text, const std::regex& pattern) {
    std::optional<std::smatch> found;
    for (std::sregex_iterator it(text.begin(), text.end(), pattern), end; it != end; ++it) {
        found = *it;
    }
    return found;
}

ParsedToolCall base_call(const std::string& name, Json input) {
    ParsedToolCall call;
    call.name = name;
    call.input = std::move(input);
    return call;
}

std::optional<ParsedToolCall> parse_json_call(const std::string& content) {
    try {
        Json value = Json::parse(content);
        if (!value.is_object() || !value.contains("name") || !value.at("name").is_string()) {
            return std::nullopt;
        }
        std::string name = value.at("name").as_string();
        if (name.empty()) return std::nullopt;
        ParsedToolCall call = base_call(name,
            value.contains("input") && value.at("input").is_object()
                ? value.at("input") : Json::object());
        if (value.contains("operation") && value.at("operation").is_string())
            call.operation = value.at("operation").as_string();
        if (value.contains("resource") && value.at("resource").is_string())
            call.resource = value.at("resource").as_string();
        if (value.contains("risk") && value.at("risk").is_string())
            call.risk = value.at("risk").as_string();
        if (value.contains("reason") && value.at("reason").is_string())
            call.reason = value.at("reason").as_string();
        if (value.contains("idempotency_key") && value.at("idempotency_key").is_string())
            call.idempotency_key = value.at("idempotency_key").as_string();
        return call;
    } catch (...) {
        return std::nullopt;
    }
}

std::optional<ParsedToolCall> parse_xml(const std::string& content) {
    static const std::regex pattern(
        R"re(<tool_call\s+name="([^"]+)"\s*>\s*([\s\S]*?)\s*</tool_call>)re");
    auto match = last_match(content, pattern);
    if (!match) return std::nullopt;
    auto input = parse_input_json((*match)[2].str());
    if (!input) return std::nullopt;
    return base_call((*match)[1].str(), *input);
}

std::optional<ParsedToolCall> parse_tag(const std::string& content) {
    static const std::regex pattern(
        R"re(<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{[\s\S]*?)\s*(?:</[a-zA-Z][\w.-]*>|$))re");
    auto match = last_match(content, pattern);
    if (!match) return std::nullopt;
    auto input = parse_input_json((*match)[2].str());
    if (!input) return std::nullopt;
    return base_call((*match)[1].str(), *input);
}

std::optional<ParsedToolCall> parse_plain(const std::string& content) {
    static const std::regex pattern(
        R"re((?:^|\n)\s*([a-zA-Z][\w.-]*)\s+(\{[\s\S]*\})\s*(?:\n|$))re");
    auto match = last_match(content, pattern);
    if (!match) return std::nullopt;
    std::string name = (*match)[1].str();
    if (name.find('.') == std::string::npos) return std::nullopt;
    auto input = parse_input_json((*match)[2].str());
    if (!input) return std::nullopt;
    return base_call(name, *input);
}

}  // namespace

std::optional<Json> parse_input_json(const std::string& raw) {
    try {
        Json value = Json::parse(trim(raw));
        if (value.is_object()) return value;
    } catch (...) {
    }
    std::string escaped;
    escaped.reserve(raw.size() + 8);
    for (char c : trim(raw)) {
        if (c == '\\') escaped += "\\\\";
        else escaped.push_back(c);
    }
    try {
        Json value = Json::parse(escaped);
        if (value.is_object()) return value;
    } catch (...) {
    }
    return std::nullopt;
}

std::optional<ParsedToolCall> parse_toolcall(const std::string& content) {
    auto call = parse_json_call(content);
    if (!call) call = parse_xml(content);
    if (!call) call = parse_tag(content);
    if (!call) call = parse_plain(content);
    if (!call) return std::nullopt;
    auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    call->call_id = "tc-" + std::to_string(millis);
    return call;
}

std::string strip_markup(const std::string& content) {
    std::string output = content;
    static const std::regex xml(
        R"re(<tool_call\s+name="[^"]+"\s*>[\s\S]*?(?:</tool_call>|$))re");
    static const std::regex invoke(
        R"re(<tool_call_invoke>[\s\S]*?(?:</tool_call_invoke>|$))re");
    static const std::regex tag(
        R"re(<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{[\s\S]*?(?:</[a-zA-Z][\w.-]*>|$))re");
    output = std::regex_replace(output, xml, "");
    output = std::regex_replace(output, invoke, "");
    output = std::regex_replace(output, tag, "");
    static const std::regex blank_lines(R"re(\n{3,})re");
    output = std::regex_replace(output, blank_lines, "\n\n");
    return trim(output);
}

}  // namespace praxo
