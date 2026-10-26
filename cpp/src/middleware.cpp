#include "praxo/middleware.hpp"

#include <algorithm>
#include <cctype>
#include <regex>

#include "praxo/errors.hpp"
#include "praxo/jsonschema.hpp"

namespace praxo {

namespace {

std::string trim(const std::string& value) {
    std::size_t start = 0;
    std::size_t end = value.size();
    while (start < end && std::isspace(static_cast<unsigned char>(value[start]))) ++start;
    while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1]))) --end;
    return value.substr(start, end - start);
}

Json extract_json(const std::string& text) {
    std::string value = trim(text);
    if (value.rfind("```", 0) == 0) {
        auto newline = value.find('\n');
        if (newline != std::string::npos) value = value.substr(newline + 1);
        while (!value.empty() && value.front() == '`') value.erase(value.begin());
        while (!value.empty() && value.back() == '`') value.pop_back();
        value = trim(value);
    }
    auto object = value.find('{');
    auto array = value.find('[');
    std::size_t start = std::string::npos;
    if (object != std::string::npos && array != std::string::npos) start = std::min(object, array);
    else if (object != std::string::npos) start = object;
    else start = array;
    if (start == std::string::npos) {
        throw PraxoError("AGENT_STRUCTURED_OUTPUT", "output does not contain JSON");
    }
    return Json::parse(value.substr(start));
}

}  // namespace

PiiRedactor::PiiRedactor() {
    rules_.push_back({std::regex(R"([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})"),
                      "[REDACTED:email]"});
    rules_.push_back({std::regex(R"(\b\d{3}-\d{2}-\d{4}\b)"), "[REDACTED:ssn]"});
    rules_.push_back({std::regex(R"(\b(?:\d{4}[ -]?){3}\d{4}\b)"),
                      "[REDACTED:credit_card]"});
}

std::string PiiRedactor::redact(const std::string& text) const {
    std::string output = text;
    for (const auto& [pattern, replacement] : rules_) {
        output = std::regex_replace(output, pattern, replacement);
    }
    return output;
}

Json PiiRedactor::redact_value(const Json& value) const {
    if (value.is_string()) return Json(redact(value.as_string()));
    if (value.is_array()) {
        Json out = Json::array();
        for (const auto& item : value.as_array()) out.push_back(redact_value(item));
        return out;
    }
    if (value.is_object()) {
        Json out = Json::object();
        for (const auto& [key, item] : value.as_object()) out[key] = redact_value(item);
        return out;
    }
    return value;
}

StructuredOutput::StructuredOutput(
    Json schema, int max_repairs,
    std::function<std::optional<std::string>(const std::string&)> repairer)
    : schema_(std::move(schema)), max_repairs_(max_repairs), repairer_(std::move(repairer)) {}

std::pair<std::optional<std::string>, std::optional<std::string>> StructuredOutput::apply(
    const std::string& text) const {
    std::string output = text;
    for (int attempt = 0; attempt <= max_repairs_; ++attempt) {
        bool valid = false;
        try {
            Json data = extract_json(output);
            valid = validate(schema_, data).empty();
        } catch (...) {
            valid = false;
        }
        if (valid) return {output, std::nullopt};
        if (attempt == max_repairs_ && !repairer_) break;
        if (!repairer_) break;
        auto repaired = repairer_(output);
        if (!repaired || trim(*repaired).empty()) break;
        output = *repaired;
    }
    return {std::nullopt, "AGENT_STRUCTURED_OUTPUT"};
}

CallLimit::CallLimit(int model_limit, int tool_limit)
    : model_limit_(model_limit), tool_limit_(tool_limit) {}

void CallLimit::before_model() {
    ++models_;
    if (model_limit_ > 0 && models_ > model_limit_) {
        throw PraxoError("AGENT_MODEL_CALL_LIMIT", "model call limit");
    }
}

void CallLimit::before_tool() {
    ++tools_;
    if (tool_limit_ > 0 && tools_ > tool_limit_) {
        throw PraxoError("AGENT_TOOL_CALL_LIMIT", "tool call limit");
    }
}

ToolSelection::ToolSelection(std::vector<std::string> selected) {
    for (const auto& name : selected) selected_.insert(name);
}

std::vector<ToolSpec> ToolSelection::filter(const std::vector<ToolSpec>& tools) const {
    std::vector<ToolSpec> out;
    for (const auto& tool : tools) {
        if (selected_.find(tool.name) != selected_.end()) out.push_back(tool);
    }
    return out;
}

void ToolSelection::reject(const std::string& name) const {
    if (selected_.find(name) == selected_.end()) {
        throw PraxoError("AGENT_TOOL_NOT_SELECTED", "tool not selected");
    }
}

ModelMiddleware fallback_model(ModelHandler fallback) {
    return [fallback](ModelHandler next) {
        return [next, fallback](const Request& request) -> Response {
            try {
                return next(request);
            } catch (...) {
                if (!fallback) throw;
                return fallback(request);
            }
        };
    };
}

}  // namespace praxo
