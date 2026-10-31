#include <cassert>
#include <chrono>
#include <filesystem>
#include <iostream>
#include <memory>
#include <stdexcept>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/jsonschema.hpp"
#include "praxo/middleware.hpp"
#include "praxo/models.hpp"
#include "praxo/plugin.hpp"
#include "praxo/runtime.hpp"
#include "praxo/toolcall.hpp"

using namespace praxo;

namespace {

class TestModel : public Model {
public:
    explicit TestModel(Json steps) : steps_(std::move(steps)) {}
    Response generate(const Request& request) override {
        (void)request;
        const Json& step = steps_.as_array()[next_++];
        Response response;
        response.message = assistant_message(step.at("content").as_string());
        if (step.contains("toolCalls")) {
            for (const auto& item : step.at("toolCalls").as_array()) {
                ToolCall call;
                call.id = item.at("id").as_string();
                call.name = item.at("name").as_string();
                call.arguments = item.at("arguments");
                response.message.tool_calls.push_back(call);
            }
        }
        return response;
    }

private:
    Json steps_;
    std::size_t next_ = 0;
};

void check(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

}  // namespace

int main() {
    try {
        auto call = parse_toolcall(R"({"name":"echo","input":{"text":"hi"}})");
        check(call.has_value(), "toolcall parsed");
        check(call->name == "echo", "toolcall name");
        check(call->input == Json::parse(R"({"text":"hi"})"), "toolcall input");
        check(strip_markup(
            "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world") ==
            "helloworld", "toolcall stripped");

        Json schema = Json::parse(
            R"({"type":"object","properties":{"name":{"type":"string"}},"required":["name"]})");
        auto errors = validate(schema, Json::object());
        check(errors.size() == 1 && errors[0].path == "$.name", "schema required");
        check(validate(schema, Json::parse(R"({"name":"ok"})")).empty(), "schema valid");

        auto manifest = parse_manifest(
            R"({"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",)"
            R"("kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},)"
            R"("protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},)"
            R"("health":{},"isolation":"process"})");
        check(manifest.id == "com.example.echo", "plugin manifest");

        MemoryStore store;
        store.put("s1", {"m1", "event", "Alpha", "2026-01-01T00:00:00Z"});
        store.put("s1", {"m2", "event", "ALPHABET", "2026-01-02T00:00:00Z"});
        auto records = store.search("s1", "alpha", 10);
        check(records.size() == 2 && records[0].id == "m2" && records[1].id == "m1", "memory");

        CheckpointAllowlist allowlist;
        allowlist.register_type("spec.payload");
        check(allowlist.unmarshal(allowlist.marshal("spec.payload",
            Json::parse(R"({"value":"x"})"))) == Json::parse(R"({"value":"x"})"),
            "checkpoint");

        auto root = std::filesystem::temp_directory_path() /
            ("praxo-cpp-tests-" + std::to_string(
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::system_clock::now().time_since_epoch()).count()));
        std::filesystem::create_directories(root / "root");
        std::filesystem::create_directories(root / "root-evil");
        PathChecker checker({{(root / "root").string(), "readwrite"}});
        check(checker.check((root / "root" / "a.txt").string(), "read").allowed, "policy allow");
        check(!checker.check((root / "root-evil" / "x.txt").string(), "read").allowed,
              "policy sibling");
        std::filesystem::remove_all(root);

        auto messages = [&]() {
            std::vector<Message> out;
            out.push_back(text_message(SYSTEM, "sys"));
            for (int i = 0; i < 10; ++i) out.push_back(text_message(USER, "message " + std::to_string(i)));
            return out;
        }();
        check(estimate_tokens(messages) == 64, "context estimate");
        ContextBudget budget{30, 2};
        auto [compacted, ok] = budget.compact(messages);
        check(ok, "context compact");
        check(estimate_tokens(compacted) == 25, "context compact tokens");
        check(compacted[1].content.value_or("") ==
              "[context compacted: 8 older messages omitted]", "context marker");

        check(PiiRedactor().redact("email a@b.com") == "email [REDACTED:email]", "pii");
        Json pii_history = Json::parse(
            R"({"messages":[{"content":"email a@b.com","toolCalls":[)"
            R"({"arguments":{"email":"a@b.com","nested":{"ssn":"123-45-6789"}}}]}]})");
        Json redacted_history = PiiRedactor().redact_value(pii_history);
        check(redacted_history.dump().find("[REDACTED:email]") != std::string::npos,
              "pii tool history email");
        check(redacted_history.dump().find("[REDACTED:ssn]") != std::string::npos,
              "pii tool history nested ssn");
        check(pii_history.dump().find("a@b.com") != std::string::npos,
              "pii input unchanged");
        Json structured_schema = Json::parse(
            R"({"type":"object","properties":{"value":{"type":"integer"}},"required":["value"]})");
        StructuredOutput structured(structured_schema, 0);
        auto [text, code] = structured.apply(R"({"value":1})");
        check(text.has_value() && *text == R"({"value":1})" && !code, "structured");

        CallLimit limit(1, 0);
        limit.before_model();
        bool caught = false;
        try { limit.before_model(); } catch (const PraxoError&) { caught = true; }
        check(caught, "call limit");

        CallLimit tool_limit(0, 1);
        tool_limit.before_tool();
        caught = false;
        try { tool_limit.before_tool(); } catch (const PraxoError&) { caught = true; }
        check(caught, "tool call limit");

        bool capacity_caught = false;
        try {
            AgentOptions tight(std::make_shared<StaticModel>("done"));
            tight.system_prompt = std::string(1000, 'x');
            tight.context = ContextBudget{10, 0};
            (void)run_agent(std::move(tight), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            capacity_caught = error.code() == "AGENT_CONTEXT_BUDGET";
        }
        check(capacity_caught, "capacity fail closed");

        ToolSelection selection({"echo"});
        std::vector<ToolSpec> tools;
        tools.push_back({"echo", "Echo", Json(nullptr), std::nullopt});
        tools.push_back({"other", "Other", Json(nullptr), std::nullopt});
        check(selection.filter(tools).size() == 1, "tool selection");
        caught = false;
        try { selection.reject("other"); } catch (const PraxoError&) { caught = true; }
        check(caught, "tool selection reject");

        auto handler = fallback_model([](const Request&) {
            Response response;
            response.message = assistant_message("fallback");
            return response;
        })([](const Request&) -> Response {
            throw PraxoError("PRIMARY_FAILED", "primary");
        });
        check(handler(Request()).message.content.value_or("") == "fallback", "fallback");

        int invocations = 0;
        auto registry = std::make_shared<ToolRegistry>();
        registry->register_tool(std::make_shared<FuncTool>("echo", "Echo",
            [&](const Json& arguments) { ++invocations; return arguments; }));
        AgentOptions options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{"text":"hi"}}]},)"
            R"({"content":"done"}])")));
        options.tools = registry;
        auto result = run_agent(options, Session{"s1", {}}, "go");
        check(result.output == "done" && result.steps == 2 && invocations == 1, "agent loop");

        std::cout << "cpp core tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
}
