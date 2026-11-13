#pragma once

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <functional>
#include <string>
#include <utility>
#include <vector>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"
#include "praxo/models.hpp"

namespace praxo {

struct OtelHttpRequest {
    std::string method;
    std::string url;
    std::map<std::string, std::string> headers;
    std::string body;
};

struct OtelHttpResponse {
    int status = 0;
    std::string body;
};

using OtelTransport = std::function<OtelHttpResponse(const OtelHttpRequest&)>;

class OtelSink {
public:
    OtelSink(std::string endpoint, OtelTransport transport)
        : endpoint_(std::move(endpoint)), transport_(std::move(transport)) {}

    OtelSink(std::string endpoint, std::string service_name,
             OtelTransport transport)
        : endpoint_(std::move(endpoint)),
          service_name_(std::move(service_name)),
          transport_(std::move(transport)) {}

    void emit(const Event& event) const {
        if (!transport_) {
            throw PraxoError("OTEL_TRANSPORT", "otel: transport is required");
        }
        const std::string at = timestamp();
        const std::string key = event.session_id + "|" +
            (event.run_id ? *event.run_id : "") + "|" + event.type + "|" +
            at + "|" + event.data.dump();
        const std::string trace_id = hex64(fnv1a(key, 0xcbf29ce484222325ULL)) +
            hex64(fnv1a(key, 0x84222325cbf29ce4ULL));
        const std::string span_id = hex64(fnv1a(key + "|span", 0x100000001b3ULL));
        const auto nanos = std::to_string(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count());

        Json attributes = Json::array();
        attributes.push_back(attribute("praxo.event.type", event.type));
        if (!event.session_id.empty()) {
            attributes.push_back(attribute("praxo.session.id", event.session_id));
        }
        if (event.run_id && !event.run_id->empty()) {
            attributes.push_back(attribute("praxo.run.id", *event.run_id));
        }
        attributes.push_back(attribute("praxo.event.at", at));
        if (event.data.is_object()) {
            for (const auto& name : allowed_data_keys) {
                const Json& value = event.data.at(name);
                if (!value.is_null()) {
                    attributes.push_back(attribute(
                        "praxo.event.data." + name, text(value)));
                }
            }
        }

        Json span = Json::object();
        span["traceId"] = trace_id;
        span["spanId"] = span_id;
        span["name"] = "praxo." + event.type;
        span["kind"] = 1;
        span["startTimeUnixNano"] = nanos;
        span["endTimeUnixNano"] = nanos;
        span["attributes"] = attributes;

        Json scope = Json::object();
        scope["name"] = "praxo-core";
        Json spans = Json::array();
        spans.push_back(span);
        Json scope_span = Json::object();
        scope_span["scope"] = scope;
        scope_span["spans"] = spans;
        Json scope_spans = Json::array();
        scope_spans.push_back(scope_span);

        Json resource_attributes = Json::array();
        resource_attributes.push_back(attribute("service.name", service_name_));
        Json resource = Json::object();
        resource["attributes"] = resource_attributes;
        Json resource_span = Json::object();
        resource_span["resource"] = resource;
        resource_span["scopeSpans"] = scope_spans;
        Json resource_spans = Json::array();
        resource_spans.push_back(resource_span);
        Json payload = Json::object();
        payload["resourceSpans"] = resource_spans;

        const OtelHttpResponse response = transport_(OtelHttpRequest{
            "POST",
            endpoint_,
            {{"content-type", "application/json"}},
            payload.dump(),
        });
        if (response.status < 200 || response.status >= 300) {
            std::string body = response.body;
            if (body.size() > 512) body.resize(512);
            throw PraxoError(
                "OTEL_HTTP",
                "otel: HTTP " + std::to_string(response.status) + ": " + body);
        }
    }

    std::vector<std::string> allowed_data_keys;

private:
    static Json attribute(const std::string& key, const std::string& value) {
        Json object = Json::object();
        object["key"] = key;
        Json wrapped = Json::object();
        wrapped["stringValue"] = value;
        object["value"] = wrapped;
        return object;
    }

    static std::string text(const Json& value) {
        return value.is_string() ? value.as_string() : value.dump();
    }

    static std::string timestamp() {
        const std::time_t now = std::time(nullptr);
        std::tm value{};
#ifdef _WIN32
        gmtime_s(&value, &now);
#else
        gmtime_r(&now, &value);
#endif
        char buffer[32];
        std::snprintf(buffer, sizeof(buffer),
            "%04d-%02d-%02dT%02d:%02d:%02dZ",
            value.tm_year + 1900, value.tm_mon + 1, value.tm_mday,
            value.tm_hour, value.tm_min, value.tm_sec);
        return buffer;
    }

    static std::uint64_t fnv1a(const std::string& text, std::uint64_t seed) {
        std::uint64_t value = seed;
        for (const unsigned char byte : text) {
            value ^= byte;
            value *= 1099511628211ULL;
        }
        return value;
    }

    static std::string hex64(std::uint64_t value) {
        char buffer[17];
        std::snprintf(buffer, sizeof(buffer), "%016llx",
            static_cast<unsigned long long>(value));
        return buffer;
    }

    std::string endpoint_;
    std::string service_name_ = "praxo-core";
    OtelTransport transport_;
};

}  // namespace praxo
