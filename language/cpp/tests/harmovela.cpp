#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>

#include "praxo/errors.hpp"
#include "praxo/harmovela.hpp"

using namespace praxo;

namespace {

void check(bool condition, const char* message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::string text_field(const Json& object, const std::string& key) {
    const Json& value = object.at(key);
    check(value.is_string(), "expected string field");
    return value.as_string();
}

}  // namespace

int main() {
    try {
        int calls = 0;
        HarmovelaHttpRequest captured;
        HarmovelaTransport transport = [&](const HarmovelaHttpRequest& request) {
            calls++;
            captured = request;
            return HarmovelaHttpResponse{201, ""};
        };
        HarmovelaClock clock = []() { return 1794294000000000000LL; };
        HarmovelaSink sink(
            "http://harmovela.test/aep/api/",
            "praxo-core",
            "0.2",
            transport,
            clock);
        Event event;
        event.type = "tool.call";
        event.session_id = "s1";
        event.run_id = "run-123";
        event.data = Json::object();
        event.data["name"] = Json("echo");
        sink.emit(event);
        check(calls == 1, "harmovela single request");
        check(captured.method == "POST", "harmovela method");
        check(captured.url == "http://harmovela.test/aep/api/events", "harmovela path");
        check(captured.content_type == "application/json", "harmovela content type");
        Json envelope = Json::parse(captured.body);
        check(text_field(envelope, "spec_version") == "0.2", "harmovela spec");
        check(text_field(envelope, "id") == "run-123-1794294000000000000", "harmovela id");
        check(text_field(envelope, "type") == "tool.call", "harmovela type");
        check(text_field(envelope, "source") == "praxo-core", "harmovela source");
        check(
            text_field(envelope, "created_at") == "2026-11-10T07:00:00.000000000Z",
            "harmovela created_at");
        const Json& payload = envelope.at("payload");
        check(text_field(payload, "name") == "echo", "harmovela payload data");
        check(text_field(payload, "session_id") == "s1", "harmovela payload session");
        check(text_field(payload, "run_id") == "run-123", "harmovela payload run");

        HarmovelaSink custom(
            "http://harmovela.test", "custom", "0.3", transport, clock);
        Event merged;
        merged.type = "tool.call";
        merged.session_id = "s1";
        merged.run_id = std::nullopt;
        merged.data = Json::object();
        merged.data["name"] = Json("echo");
        merged.data["session_id"] = Json("event-side");
        merged.data["run_id"] = Json("old");
        custom.emit(merged);
        Json merged_envelope = Json::parse(captured.body);
        check(text_field(merged_envelope, "source") == "custom", "harmovela custom source");
        check(text_field(merged_envelope, "spec_version") == "0.3", "harmovela custom spec");
        check(
            text_field(merged_envelope, "id").rfind("s1-", 0) == 0,
            "harmovela session id");
        const Json& merged_payload = merged_envelope.at("payload");
        check(text_field(merged_payload, "session_id") == "s1", "harmovela session override");
        check(text_field(merged_payload, "run_id") == "old", "harmovela data run retained");

        for (int status : {200, 201, 204, 299}) {
            HarmovelaTransport accepted = [status](const HarmovelaHttpRequest&) {
                return HarmovelaHttpResponse{status, ""};
            };
            HarmovelaSink accepted_sink(
                "http://harmovela.test", "praxo-core", "0.2", accepted, clock);
            accepted_sink.emit(event);
        }

        std::string repeated;
        for (int index = 0; index < 100; index++) {
            repeated += "service down ";
        }
        HarmovelaTransport failing = [&](const HarmovelaHttpRequest&) {
            return HarmovelaHttpResponse{503, repeated};
        };
        HarmovelaSink failing_sink(
            "http://harmovela.test", "praxo-core", "0.2", failing, clock);
        bool caught = false;
        try {
            failing_sink.emit(event);
        } catch (const PraxoError& error) {
            caught = error.code() == "HARMOVELA_HTTP";
            std::string message = error.what();
            check(message.find("503") != std::string::npos, "harmovela error status");
            check(
                message.find("service down") != std::string::npos,
                "harmovela error body");
            check(message.size() <= 600, "harmovela bounded error");
        }
        check(caught, "harmovela non-2xx fails");

        std::cout << "cpp harmovela tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
}
