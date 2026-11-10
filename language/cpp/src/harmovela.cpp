#include "praxo/harmovela.hpp"

#include <chrono>
#include <cstdio>
#include <ctime>
#include <utility>

#include "praxo/errors.hpp"

namespace praxo {

namespace {

long long now_nanos() {
    auto now = std::chrono::system_clock::now().time_since_epoch();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(now).count();
}

std::string trim_slashes(const std::string& value) {
    std::size_t length = value.size();
    while (length > 0 && value[length - 1] == '/') {
        --length;
    }
    return value.substr(0, length);
}

std::string bound(const std::string& value) {
    return value.size() > 512 ? value.substr(0, 512) : value;
}

std::string format_created(long long epoch_nanos) {
    long long seconds = epoch_nanos / 1000000000LL;
    long long nanos = epoch_nanos % 1000000000LL;
    if (nanos < 0) {
        nanos += 1000000000LL;
        seconds -= 1;
    }
    std::time_t value = static_cast<std::time_t>(seconds);
    std::tm parts{};
#ifdef _WIN32
    gmtime_s(&parts, &value);
#else
    gmtime_r(&value, &parts);
#endif
    char buffer[64];
    std::snprintf(
        buffer,
        sizeof(buffer),
        "%04d-%02d-%02dT%02d:%02d:%02d.%09lldZ",
        parts.tm_year + 1900,
        parts.tm_mon + 1,
        parts.tm_mday,
        parts.tm_hour,
        parts.tm_min,
        parts.tm_sec,
        nanos);
    return buffer;
}

}  // namespace

HarmovelaSink::HarmovelaSink(
    std::string base_url,
    std::string source,
    std::string spec_version,
    HarmovelaTransport transport,
    HarmovelaClock clock)
    : base_url_(std::move(base_url)),
      source_(std::move(source)),
      spec_version_(std::move(spec_version)),
      transport_(std::move(transport)),
      clock_(std::move(clock)) {}

std::string HarmovelaSink::source_value() const {
    return source_.empty() ? "praxo-core" : source_;
}

std::string HarmovelaSink::spec_value() const {
    return spec_version_.empty() ? "0.2" : spec_version_;
}

std::string HarmovelaSink::envelope(const Event& event) const {
    const long long epoch = clock_ ? clock_() : now_nanos();
    std::string prefix = "event";
    if (event.session_id.size() > 0) prefix = event.session_id;
    if (event.run_id && !event.run_id->empty()) prefix = *event.run_id;
    Json payload = event.data.is_object() ? event.data : Json::object();
    if (!event.session_id.empty()) payload["session_id"] = event.session_id;
    if (event.run_id && !event.run_id->empty()) payload["run_id"] = *event.run_id;
    Json root = Json::object();
    root["spec_version"] = spec_value();
    root["id"] = prefix + "-" + std::to_string(epoch);
    root["type"] = event.type;
    root["source"] = source_value();
    root["created_at"] = format_created(epoch);
    root["payload"] = payload;
    return root.dump();
}

void HarmovelaSink::emit(const Event& event) {
    if (base_url_.empty()) {
        throw PraxoError("HARMOVELA_BASE_URL", "harmovela: base URL is required");
    }
    HarmovelaHttpRequest request;
    request.method = "POST";
    request.url = trim_slashes(base_url_) + "/events";
    request.content_type = "application/json";
    request.body = envelope(event);
    if (!transport_) {
        throw PraxoError(
            "HARMOVELA_TRANSPORT",
            "harmovela: inject a transport; no HTTP client is bundled");
    }
    HarmovelaHttpResponse response = transport_(request);
    if (response.status < 200 || response.status >= 300) {
        throw PraxoError(
            "HARMOVELA_HTTP",
            "harmovela: HTTP " + std::to_string(response.status) + ": " + bound(response.body));
    }
}

}  // namespace praxo
