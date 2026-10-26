#include "praxo/jsonschema.hpp"

#include <cmath>
#include <regex>

namespace praxo {

namespace {

void visit(const Json& schema, const Json& data, const std::string& path,
           std::vector<ValidationError>& errors);

void check_enum(const Json& schema, const Json& data, const std::string& path,
                std::vector<ValidationError>& errors) {
    if (!schema.contains("enum") || !schema.at("enum").is_array()) return;
    for (const auto& value : schema.at("enum").as_array()) {
        if (value == data) return;
    }
    errors.push_back({path, "value not in enum"});
}

void visit_object(const Json& schema, const Json& data, const std::string& path,
                  std::vector<ValidationError>& errors) {
    if (!data.is_object()) {
        errors.push_back({path, "expected object"});
        return;
    }
    if (schema.contains("required") && schema.at("required").is_array()) {
        for (const auto& item : schema.at("required").as_array()) {
            if (!item.is_string()) continue;
            const std::string& name = item.as_string();
            if (!data.contains(name)) {
                errors.push_back({path + "." + name, "required field missing"});
            }
        }
    }
    if (schema.contains("properties") && schema.at("properties").is_object()) {
        for (const auto& [name, child] : schema.at("properties").as_object()) {
            if (data.contains(name)) {
                visit(child, data.at(name), path + "." + name, errors);
            }
        }
    }
}

void visit_array(const Json& schema, const Json& data, const std::string& path,
                 std::vector<ValidationError>& errors) {
    if (!data.is_array()) {
        errors.push_back({path, "expected array"});
        return;
    }
    if (schema.contains("items")) {
        const Json& items = schema.at("items");
        for (std::size_t i = 0; i < data.as_array().size(); ++i) {
            visit(items, data.as_array()[i], path + "[" + std::to_string(i) + "]", errors);
        }
    }
}

void visit_string(const Json& schema, const Json& data, const std::string& path,
                  std::vector<ValidationError>& errors) {
    if (!data.is_string()) {
        errors.push_back({path, "expected string"});
        return;
    }
    const std::string& text = data.as_string();
    std::size_t length = utf8_length(text);
    int min_length = schema.contains("minLength") && schema.at("minLength").is_number()
        ? static_cast<int>(schema.at("minLength").as_number()) : 0;
    int max_length = schema.contains("maxLength") && schema.at("maxLength").is_number()
        ? static_cast<int>(schema.at("maxLength").as_number()) : 0;
    if (min_length > 0 && length < static_cast<std::size_t>(min_length)) {
        errors.push_back({path, "min length " + std::to_string(min_length) +
                                  ", got " + std::to_string(length)});
    }
    if (max_length > 0 && length > static_cast<std::size_t>(max_length)) {
        errors.push_back({path, "max length " + std::to_string(max_length) +
                                  ", got " + std::to_string(length)});
    }
    if (schema.contains("pattern") && schema.at("pattern").is_string()) {
        try {
            std::regex pattern(schema.at("pattern").as_string());
            if (!std::regex_search(text, pattern)) {
                errors.push_back({path, "pattern '" + schema.at("pattern").as_string() +
                                          "' not matched"});
            }
        } catch (const std::regex_error&) {
            errors.push_back({path, "invalid pattern '" + schema.at("pattern").as_string() + "'"});
        }
    }
    check_enum(schema, data, path, errors);
}

void visit_number(const Json& schema, const std::string& kind, const Json& data,
                  const std::string& path, std::vector<ValidationError>& errors) {
    if (!data.is_number()) {
        errors.push_back({path, "expected number"});
        return;
    }
    double value = data.as_number();
    if (kind == "integer" && std::floor(value) != value) {
        errors.push_back({path, "expected integer"});
        return;
    }
    check_enum(schema, data, path, errors);
    if (schema.contains("minimum") && schema.at("minimum").is_number() &&
        schema.at("minimum").as_number() != 0 && value < schema.at("minimum").as_number()) {
        errors.push_back({path, "value below minimum"});
    }
    if (schema.contains("maximum") && schema.at("maximum").is_number() &&
        schema.at("maximum").as_number() != 0 && value > schema.at("maximum").as_number()) {
        errors.push_back({path, "value above maximum"});
    }
}

void visit_boolean(const Json& schema, const Json& data, const std::string& path,
                   std::vector<ValidationError>& errors) {
    if (!data.is_bool()) {
        errors.push_back({path, "expected boolean"});
        return;
    }
    check_enum(schema, data, path, errors);
}

void visit(const Json& schema, const Json& data, const std::string& path,
           std::vector<ValidationError>& errors) {
    std::string kind = schema.contains("type") && schema.at("type").is_string()
        ? schema.at("type").as_string() : "";
    if (data.is_null()) {
        if (!kind.empty()) errors.push_back({path, "expected " + kind + ", got null"});
        return;
    }
    if (kind == "object") visit_object(schema, data, path, errors);
    else if (kind == "array") visit_array(schema, data, path, errors);
    else if (kind == "string") visit_string(schema, data, path, errors);
    else if (kind == "number" || kind == "integer") visit_number(schema, kind, data, path, errors);
    else if (kind == "boolean") visit_boolean(schema, data, path, errors);
}

}  // namespace

std::vector<ValidationError> validate(const Json& schema, const Json& data) {
    std::vector<ValidationError> errors;
    visit(schema, data, "$", errors);
    return errors;
}

}  // namespace praxo
