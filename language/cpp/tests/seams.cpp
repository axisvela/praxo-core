#include "praxo/delegation.hpp"
#include "praxo/otel.hpp"
#include "praxo/retriever.hpp"

#include <cassert>
#include <stdexcept>
#include <string>
#include <vector>

using namespace praxo;

namespace {

void otel_test() {
    std::vector<OtelHttpRequest> calls;
    OtelTransport capture = [&calls](const OtelHttpRequest& request) {
        calls.push_back(request);
        return OtelHttpResponse{200, ""};
    };
    OtelSink sink("http://otel.test/v1/traces", "praxo-test", capture);
    sink.allowed_data_keys = {"name"};
    Event event;
    event.type = "tool.call";
    event.session_id = "s1";
    event.run_id = "run-123";
    event.data = Json::parse("{\"name\":\"echo\",\"secret\":\"hidden\"}");
    sink.emit(event);
    assert(calls.size() == 1);
    assert(calls[0].url == "http://otel.test/v1/traces");
    Json payload = Json::parse(calls[0].body);
    Json span = payload.at("resourceSpans").as_array()[0]
        .at("scopeSpans").as_array()[0]
        .at("spans").as_array()[0];
    assert(span.at("name").as_string() == "praxo.tool.call");
    assert(span.at("traceId").as_string().size() == 32);
    assert(span.at("spanId").as_string().size() == 16);
    bool found_name = false;
    bool found_secret = false;
    for (const Json& item : span.at("attributes").as_array()) {
        const std::string key = item.at("key").as_string();
        const std::string value = item.at("value").at("stringValue").as_string();
        if (key == "praxo.event.data.name" && value == "echo") {
            found_name = true;
        }
        if (key == "praxo.event.data.secret") {
            found_secret = true;
        }
    }
    assert(found_name && !found_secret);

    OtelSink failing("http://otel.test/v1/traces", "praxo-test",
        [](const OtelHttpRequest&) {
            return OtelHttpResponse{503, "down"};
        });
    try {
        failing.emit(event);
        throw std::runtime_error("expected otel error");
    } catch (const PraxoError& error) {
        assert(error.code() == "OTEL_HTTP");
    }
}

void retriever_test() {
    Retriever retriever = [](const std::string& query, int limit) {
        Document document;
        document.id = "doc-1";
        document.content = query + ":" + std::to_string(limit);
        document.score = 0.5;
        return std::vector<Document>{document};
    };
    const auto documents = retrieve(retriever, "hello", 3);
    assert(documents.size() == 1);
    assert(documents[0].id == "doc-1");
    assert(documents[0].content == "hello:3");
    assert(documents[0].wire().at("score").as_number() == 0.5);
}

void delegation_test() {
    SubagentRequest request;
    request.parent_session_id = "parent";
    request.agent_id = "child";
    request.prompt = "do";
    request.mode = "fork";
    const SubagentTask completed = subagent_run(
        [](const SubagentRequest&) {
            return SubagentResult{"", "", "done", std::nullopt};
        },
        request);
    assert(completed.status == "completed");
    assert(completed.output == "done");
    assert(completed.mode == "fork");

    const SubagentTask failed = subagent_run(
        [](const SubagentRequest&) -> SubagentResult {
            throw std::runtime_error("boom");
        },
        request);
    assert(failed.status == "failed");
    assert(failed.error.find("boom") != std::string::npos);

    SubagentRequest invalid;
    bool threw = false;
    try {
        subagent_run([](const SubagentRequest&) {
            return SubagentResult{};
        }, invalid);
    } catch (const PraxoError& error) {
        threw = error.code() == "SUBAGENT_INVALID";
    }
    assert(threw);
}

}  // namespace

int main() {
    otel_test();
    retriever_test();
    delegation_test();
    return 0;
}
