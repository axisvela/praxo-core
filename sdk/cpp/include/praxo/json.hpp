#pragma once

#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <variant>
#include <vector>

namespace praxo {

class Json {
public:
    using Array = std::vector<Json>;
    using Object = std::map<std::string, Json>;

    Json() : value_(nullptr) {}
    Json(std::nullptr_t) : value_(nullptr) {}
    Json(bool value) : value_(value) {}
    Json(int value) : value_(static_cast<double>(value)) {}
    Json(double value) : value_(value) {}
    Json(const char* value) : value_(std::string(value)) {}
    Json(std::string value) : value_(std::move(value)) {}

    static Json array() { Json out; out.value_ = Array{}; return out; }
    static Json object() { Json out; out.value_ = Object{}; return out; }

    bool is_null() const { return std::holds_alternative<std::nullptr_t>(value_); }
    bool is_bool() const { return std::holds_alternative<bool>(value_); }
    bool is_number() const { return std::holds_alternative<double>(value_); }
    bool is_string() const { return std::holds_alternative<std::string>(value_); }
    bool is_array() const { return std::holds_alternative<Array>(value_); }
    bool is_object() const { return std::holds_alternative<Object>(value_); }

    bool as_bool() const { return std::get<bool>(value_); }
    double as_number() const { return std::get<double>(value_); }
    const std::string& as_string() const { return std::get<std::string>(value_); }
    const Array& as_array() const { return std::get<Array>(value_); }
    Array& as_array() { return std::get<Array>(value_); }
    const Object& as_object() const { return std::get<Object>(value_); }
    Object& as_object() { return std::get<Object>(value_); }

    bool contains(const std::string& key) const {
        return is_object() && as_object().find(key) != as_object().end();
    }
    const Json& at(const std::string& key) const {
        static const Json null_value;
        if (!is_object()) return null_value;
        auto it = as_object().find(key);
        return it == as_object().end() ? null_value : it->second;
    }
    Json& operator[](const std::string& key) {
        if (!is_object()) value_ = Object{};
        return as_object()[key];
    }
    const Json& operator[](const std::string& key) const { return at(key); }
    void push_back(Json value) {
        if (!is_array()) value_ = Array{};
        as_array().push_back(std::move(value));
    }
    std::size_t size() const {
        if (is_array()) return as_array().size();
        if (is_object()) return as_object().size();
        if (is_string()) return as_string().size();
        return 0;
    }

    static Json parse(const std::string& text);
    std::string dump() const;

    bool operator==(const Json& other) const { return equals(other); }

private:
    bool equals(const Json& other) const;
    std::variant<std::nullptr_t, bool, double, std::string, Array, Object> value_;
};

inline std::size_t utf8_length(const std::string& text) {
    std::size_t count = 0;
    for (unsigned char byte : text) {
        if ((byte & 0xC0) != 0x80) ++count;
    }
    return count;
}

class JsonParser {
public:
    explicit JsonParser(const std::string& text) : text_(text) {}
    Json parse() {
        skip();
        Json value = parse_value();
        skip();
        if (pos_ != text_.size()) throw std::runtime_error("invalid JSON: trailing data");
        return value;
    }

private:
    void skip() {
        while (pos_ < text_.size() &&
               (text_[pos_] == ' ' || text_[pos_] == '\n' ||
                text_[pos_] == '\r' || text_[pos_] == '\t')) {
            ++pos_;
        }
    }
    char peek() {
        if (pos_ >= text_.size()) throw std::runtime_error("invalid JSON: unexpected end");
        return text_[pos_];
    }
    void expect(char expected) {
        if (peek() != expected) throw std::runtime_error("invalid JSON: expected token");
        ++pos_;
    }
    Json parse_value() {
        skip();
        char c = peek();
        if (c == 'n') return parse_literal("null", Json(nullptr));
        if (c == 't') return parse_literal("true", Json(true));
        if (c == 'f') return parse_literal("false", Json(false));
        if (c == '"') return Json(parse_string());
        if (c == '[') return parse_array();
        if (c == '{') return parse_object();
        return parse_number();
    }
    Json parse_literal(const char* text, Json value) {
        std::string literal(text);
        if (text_.compare(pos_, literal.size(), literal) != 0) {
            throw std::runtime_error("invalid JSON: bad literal");
        }
        pos_ += literal.size();
        return value;
    }
    Json parse_array() {
        expect('[');
        Json out = Json::array();
        skip();
        if (peek() == ']') { ++pos_; return out; }
        while (true) {
            out.push_back(parse_value());
            skip();
            char c = peek();
            ++pos_;
            if (c == ']') break;
            if (c != ',') throw std::runtime_error("invalid JSON: expected comma");
        }
        return out;
    }
    Json parse_object() {
        expect('{');
        Json out = Json::object();
        skip();
        if (peek() == '}') { ++pos_; return out; }
        while (true) {
            skip();
            if (peek() != '"') throw std::runtime_error("invalid JSON: expected key");
            std::string key = parse_string();
            skip();
            expect(':');
            out[key] = parse_value();
            skip();
            char c = peek();
            ++pos_;
            if (c == '}') break;
            if (c != ',') throw std::runtime_error("invalid JSON: expected comma");
        }
        return out;
    }
    std::string parse_string() {
        expect('"');
        std::string out;
        while (true) {
            if (pos_ >= text_.size()) throw std::runtime_error("invalid JSON: unterminated string");
            unsigned char c = static_cast<unsigned char>(text_[pos_++]);
            if (c == '"') break;
            if (c != '\\') {
                out.push_back(static_cast<char>(c));
                continue;
            }
            if (pos_ >= text_.size()) throw std::runtime_error("invalid JSON: bad escape");
            char escape = text_[pos_++];
            switch (escape) {
                case '"': out.push_back('"'); break;
                case '\\': out.push_back('\\'); break;
                case '/': out.push_back('/'); break;
                case 'b': out.push_back('\b'); break;
                case 'f': out.push_back('\f'); break;
                case 'n': out.push_back('\n'); break;
                case 'r': out.push_back('\r'); break;
                case 't': out.push_back('\t'); break;
                case 'u': append_codepoint(out, parse_unicode()); break;
                default: throw std::runtime_error("invalid JSON: unknown escape");
            }
        }
        return out;
    }
    uint32_t parse_unicode() {
        if (pos_ + 4 > text_.size()) throw std::runtime_error("invalid JSON: bad unicode");
        uint32_t value = 0;
        for (int i = 0; i < 4; ++i) {
            char c = text_[pos_++];
            value <<= 4;
            if (c >= '0' && c <= '9') value |= static_cast<uint32_t>(c - '0');
            else if (c >= 'a' && c <= 'f') value |= static_cast<uint32_t>(c - 'a' + 10);
            else if (c >= 'A' && c <= 'F') value |= static_cast<uint32_t>(c - 'A' + 10);
            else throw std::runtime_error("invalid JSON: bad unicode");
        }
        return value;
    }
    static void append_codepoint(std::string& out, uint32_t cp) {
        if (cp <= 0x7F) {
            out.push_back(static_cast<char>(cp));
        } else if (cp <= 0x7FF) {
            out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }
    Json parse_number() {
        std::size_t start = pos_;
        if (peek() == '-') ++pos_;
        while (pos_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[pos_]))) ++pos_;
        if (pos_ < text_.size() && text_[pos_] == '.') {
            ++pos_;
            while (pos_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[pos_]))) ++pos_;
        }
        if (pos_ < text_.size() && (text_[pos_] == 'e' || text_[pos_] == 'E')) {
            ++pos_;
            if (pos_ < text_.size() && (text_[pos_] == '+' || text_[pos_] == '-')) ++pos_;
            while (pos_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[pos_]))) ++pos_;
        }
        if (start == pos_) throw std::runtime_error("invalid JSON: expected value");
        return Json(std::stod(text_.substr(start, pos_ - start)));
    }

    const std::string& text_;
    std::size_t pos_ = 0;
};

inline Json Json::parse(const std::string& text) {
    return JsonParser(text).parse();
}

inline bool Json::equals(const Json& other) const {
    if (value_.index() != other.value_.index()) return false;
    if (is_null()) return true;
    if (is_bool()) return as_bool() == other.as_bool();
    if (is_number()) return as_number() == other.as_number();
    if (is_string()) return as_string() == other.as_string();
    if (is_array()) {
        if (as_array().size() != other.as_array().size()) return false;
        for (std::size_t i = 0; i < as_array().size(); ++i) {
            if (!as_array()[i].equals(other.as_array()[i])) return false;
        }
        return true;
    }
    if (as_object().size() != other.as_object().size()) return false;
    for (const auto& [key, value] : as_object()) {
        auto it = other.as_object().find(key);
        if (it == other.as_object().end() || !value.equals(it->second)) return false;
    }
    return true;
}

inline std::string escape_json(const std::string& value) {
    std::ostringstream out;
    out << '"';
    for (unsigned char c : value) {
        switch (c) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\b': out << "\\b"; break;
            case '\f': out << "\\f"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default:
                if (c < 0x20) {
                    char buffer[8];
                    std::snprintf(buffer, sizeof(buffer), "\\u%04x", c);
                    out << buffer;
                } else {
                    out << static_cast<char>(c);
                }
        }
    }
    out << '"';
    return out.str();
}

inline std::string Json::dump() const {
    if (is_null()) return "null";
    if (is_bool()) return as_bool() ? "true" : "false";
    if (is_number()) {
        double value = as_number();
        if (std::floor(value) == value && std::abs(value) < 1e15) {
            std::ostringstream out;
            out << static_cast<long long>(value);
            return out.str();
        }
        std::ostringstream out;
        out.precision(17);
        out << value;
        return out.str();
    }
    if (is_string()) return escape_json(as_string());
    if (is_array()) {
        std::string out = "[";
        for (std::size_t i = 0; i < as_array().size(); ++i) {
            if (i) out += ",";
            out += as_array()[i].dump();
        }
        out += "]";
        return out;
    }
    std::string out = "{";
    bool first = true;
    for (const auto& [key, value] : as_object()) {
        if (!first) out += ",";
        first = false;
        out += escape_json(key);
        out += ":";
        out += value.dump();
    }
    out += "}";
    return out;
}

}  // namespace praxo
