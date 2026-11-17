#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/harmovela.hpp"
#include "praxo/mcp.hpp"
#include "praxo/otel.hpp"
#include "praxo/runtime.hpp"

#include <algorithm>
#include <cassert>
#include <iostream>
#include <memory>
#include <string>
#include <utility>
#include <vector>

using namespace praxo;

namespace {

struct EventCapture {
    std::vector<std::string> otel;
    std::vector<std::string> harmovela;
};

class ScriptedModel : public Model {
public:
    ScriptedModel(std::vector<Response> steps, std::string final_text,
                  int* calls)
        : steps_(std::move(steps)),
          final_text_(std::move(final_text)),
          calls_(calls) {}

    Response generate(const Request& request) override {
        (void)request;
        if (calls_ != nullptr) ++*calls_;
        Response response;
        if (index_ < steps_.size()) return steps_[index_++];
        response.message = assistant_message(final_text_);
        return response;
    }

private:
    std::vector<Response> steps_;
    std::string final_text_;
    int* calls_;
    std::size_t index_ = 0;
};

Response tool_step(const std::string& id, const std::string& name,
                   Json arguments) {
    ToolCall call;
    call.id = id;
    call.name = name;
    call.arguments = std::move(arguments);
    Response response;
    response.message = assistant_message("", {call});
    return response;
}

struct Chain {
    int parent_effects = 0;
    int child_effects = 0;
    int blocked_effects = 0;
    int tool_calls = 0;
    int parent_calls = 0;
    int child_calls = 0;
    McpClient* client = nullptr;
    EventSink* events = nullptr;

    Json record(const Json& arguments) {
        return client->call_tool("record", arguments);
    }

    Json run_child() {
        auto registry = std::make_shared<ToolRegistry>();
        registry->register_tool(std::make_shared<FuncTool>(
            "record", "Record a target",
            [this](const Json& arguments) { return record(arguments); }));
        auto model = std::make_shared<ScriptedModel>(
            std::vector<Response>{tool_step(
                "child-record", "record", Json::parse(R"({"target":"child"})"))},
            "CHILD-DONE", &child_calls);
        AgentOptions options(model);
        options.tools = registry;
        options.max_steps = 3;
        options.allowed_tools = {"record"};
        options.policy = child_policy;
        options.require_policy = true;
        options.require_tool_scope = true;
        options.events = events;
        Agent agent(std::move(options));
        const RunResult result =
            agent.run(Session{"chain-child", {}}, "record child");
        Json output = Json::object();
        output["output"] = result.output;
        output["child"] = child_effects;
        return output;
    }

    static Decision parent_policy(const Action& action) {
        if (action.kind == "model.generate") return {true, ""};
        if (action.kind != "tool.invoke") return {false, "unsupported action"};
        const std::string name = action.tool_name.value_or("");
        if (name == "record") {
            if (action.arguments.is_object()) {
                const Json& target = action.arguments.at("target");
                if (target.is_string() && target.as_string() == "blocked") {
                    return {false, "blocked target"};
                }
            }
            return {true, ""};
        }
        if (name == "delegate") return {true, ""};
        return {false, "parent tool is not allowed"};
    }

    static Decision child_policy(const Action& action) {
        const Decision parent = parent_policy(action);
        if (!parent.allowed) return parent;
        if (action.kind == "model.generate") return {true, ""};
        if (action.kind == "tool.invoke" && action.tool_name.has_value() &&
            *action.tool_name == "record") {
            return {true, ""};
        }
        return {false, "child may only record"};
    }
};

Json mcp_transport(Chain& chain, const std::string& method,
                   const Json& params) {
    if (method == "initialize") {
        return Json::parse(
            R"({"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"fake-mcp","version":"0.0.1"}})");
    }
    if (method == "tools/list") {
        return Json::parse(
            R"({"tools":[{"name":"record","description":"Record a target","inputSchema":{"type":"object","properties":{"target":{"type":"string"}},"required":["target"]}}]})");
    }
    if (method == "tools/call") {
        chain.tool_calls++;
        const Json& name = params.at("name");
        if (!name.is_string() || name.as_string() != "record") {
            return Json::parse(R"({"isError":true})");
        }
        const Json& arguments = params.at("arguments");
        if (arguments.is_object()) {
            const Json& target = arguments.at("target");
            if (target.is_string()) {
                const std::string value = target.as_string();
                if (value == "parent") {
                    chain.parent_effects++;
                } else if (value == "child") {
                    chain.child_effects++;
                } else if (value == "blocked") {
                    chain.blocked_effects++;
                }
            }
        }
        return Json::parse(
            R"({"content":[{"type":"text","text":"recorded"}]})");
    }
    return Json::object();
}

class DelegateTool : public Tool {
public:
    explicit DelegateTool(Chain& chain) : chain_(chain) {}
    std::string name() const override { return "delegate"; }
    std::string description() const override {
        return "Run a governed child agent with the narrowed record scope";
    }
    Json invoke(const Json& arguments) override {
        (void)arguments;
        return chain_.run_child();
    }

private:
    Chain& chain_;
};

class OtelEventSink : public EventSink {
public:
    explicit OtelEventSink(OtelSink& sink) : sink_(sink) {}
    void emit(const Event& event) override { sink_.emit(event); }

private:
    OtelSink& sink_;
};

OtelTransport otel_transport(EventCapture& capture) {
    return [&capture](const OtelHttpRequest& request) {
        const Json payload = Json::parse(request.body);
        const Json& span = payload.at("resourceSpans").as_array()[0]
            .at("scopeSpans").as_array()[0]
            .at("spans").as_array()[0];
        capture.otel.push_back(span.at("name").as_string());
        return OtelHttpResponse{200, ""};
    };
}

HarmovelaTransport harmovela_transport(EventCapture& capture) {
    return [&capture](const HarmovelaHttpRequest& request) {
        const Json payload = Json::parse(request.body);
        capture.harmovela.push_back(payload.at("type").as_string());
        return HarmovelaHttpResponse{202, ""};
    };
}

bool contains(const std::vector<std::string>& values,
              const std::string& value) {
    return std::find(values.begin(), values.end(), value) != values.end();
}

}

int main() {
    EventCapture capture;
    OtelSink otel("http://otel.test/v1/traces", "praxo-chain",
                  otel_transport(capture));
    OtelEventSink otel_event(otel);
    HarmovelaSink harmovela(
        "http://harmovela.test", "praxo-chain", "0.2",
        harmovela_transport(capture),
        []() { return 1794294000000000000LL; });
    MultiSink multi(std::vector<EventSink*>{&otel_event, &harmovela});

    Chain chain;
    chain.events = &multi;
    McpClient client([&chain](const std::string& method, const Json& params) {
        return mcp_transport(chain, method, params);
    });
    chain.client = &client;
    const Json tools = client.list_tools();
    assert(tools.is_array() && tools.size() == 1);

    auto registry = std::make_shared<ToolRegistry>();
    registry->register_tool(std::make_shared<FuncTool>(
        "record", "Record a target",
        [&chain](const Json& arguments) {
            return chain.record(arguments);
        }));
    registry->register_tool(std::make_shared<DelegateTool>(chain));

    auto parent_model = std::make_shared<ScriptedModel>(
        std::vector<Response>{
            tool_step("parent-record", "record",
                      Json::parse(R"({"target":"parent"})")),
            tool_step("parent-delegate", "delegate",
                      Json::parse(R"({"task":"child"})")),
        },
        "DONE", &chain.parent_calls);
    AgentOptions options(parent_model);
    options.tools = registry;
    options.max_steps = 6;
    options.allowed_tools = {"record", "delegate"};
    options.policy = Chain::parent_policy;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.events = &multi;
    Agent parent(std::move(options));
    const RunResult result =
        parent.run(Session{"chain-parent", {}}, "run the chain");

    assert(result.output == "DONE");
    assert(chain.parent_effects == 1);
    assert(chain.child_effects == 1);
    assert(chain.child_calls >= 2);
    assert(chain.tool_calls == 2);
    for (const std::string& name :
         {"praxo.run.started", "praxo.tool.call", "praxo.run.completed"}) {
        assert(contains(capture.otel, name));
    }
    for (const std::string& kind :
         {"run.started", "tool.call", "run.completed"}) {
        assert(contains(capture.harmovela, kind));
    }

    Chain denial;
    McpClient denial_client(
        [&denial](const std::string& method, const Json& params) {
            return mcp_transport(denial, method, params);
        });
    denial.client = &denial_client;
    auto denial_registry = std::make_shared<ToolRegistry>();
    denial_registry->register_tool(std::make_shared<FuncTool>(
        "record", "Record a target",
        [&denial](const Json& arguments) {
            return denial.record(arguments);
        }));
    int denial_calls = 0;
    auto denial_model = std::make_shared<ScriptedModel>(
        std::vector<Response>{tool_step(
            "denied-record", "record", Json::parse(R"({"target":"safe"})"))},
        "UNEXPECTED", &denial_calls);
    AgentOptions denial_options(denial_model);
    denial_options.tools = denial_registry;
    denial_options.max_steps = 2;
    denial_options.allowed_tools = {"record"};
    denial_options.policy = Chain::parent_policy;
    denial_options.require_policy = true;
    denial_options.require_tool_scope = true;
    Middleware edit;
    edit.before_tool = [](ToolCall call) {
        call.arguments["target"] = "blocked";
        return call;
    };
    denial_options.middleware.push_back(edit);

    std::string denial_code = "NO_DENIAL";
    try {
        Agent denial_agent(std::move(denial_options));
        (void)denial_agent.run(Session{"chain-denial", {}}, "call record");
    } catch (const PraxoError& error) {
        denial_code = error.code();
    }
    assert(denial_code == "AGENT_POLICY_DENIED");
    assert(denial.blocked_effects == 0);
    assert(denial.tool_calls == 0);

    std::cout << "output: " << result.output << "\n";
    std::cout << "effects parent=1 child=1 tool_calls=" << chain.tool_calls
              << "\n";
    std::cout << "child calls: " << chain.child_calls << "\n";
    std::cout << "otel spans: " << capture.otel.size() << "\n";
    std::cout << "harmovela events: " << capture.harmovela.size() << "\n";
    std::cout << "denied effect: " << denial.blocked_effects << "\n";
    return 0;
}
