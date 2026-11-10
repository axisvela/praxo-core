#pragma once

#include <functional>
#include <string>

#include "praxo/models.hpp"
#include "praxo/runtime.hpp"

namespace praxo {

struct HarmovelaHttpRequest {
    std::string method;
    std::string url;
    std::string content_type;
    std::string body;
};

struct HarmovelaHttpResponse {
    int status = 0;
    std::string body;
};

using HarmovelaTransport = std::function<HarmovelaHttpResponse(const HarmovelaHttpRequest&)>;
using HarmovelaClock = std::function<long long()>;

class HarmovelaSink : public EventSink {
public:
    explicit HarmovelaSink(
        std::string base_url,
        std::string source = "praxo-core",
        std::string spec_version = "0.2",
        HarmovelaTransport transport = {},
        HarmovelaClock clock = {});

    void emit(const Event& event) override;

    std::string envelope(const Event& event) const;

private:
    std::string source_value() const;
    std::string spec_value() const;

    std::string base_url_;
    std::string source_;
    std::string spec_version_;
    HarmovelaTransport transport_;
    HarmovelaClock clock_;
};

}  // namespace praxo
