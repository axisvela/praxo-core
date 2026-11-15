#include <iostream>
#include <memory>
#include <optional>
#include <string>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

class FixtureModel : public praxo::Model {
public:
    explicit FixtureModel(std::string target) : target_(std::move(target)) {}

    praxo::Response generate(const praxo::Request& request) override {
        praxo::Response response;
        if (!request.messages.empty() &&
            request.messages.back().role == praxo::TOOL) {
            response.message = praxo::assistant_message("recorded");
            return response;
        }
        praxo::Json arguments = praxo::Json::object();
        arguments["target"] = target_;
        response.message = praxo::assistant_message(
            "", {praxo::ToolCall{"record-1", "record", arguments}});
        return response;
    }

private:
    std::string target_;
};

static int run_scenario(const std::string& target, std::string* output,
                        bool* denied) {
    int effects = 0;
    auto registry = std::make_shared<praxo::ToolRegistry>();
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "record", "Record a target in an in-memory counter.",
        [&effects](const praxo::Json&) {
            ++effects;
            return praxo::Json("recorded");
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(target));
    options.tools = registry;
    options.allowed_tools = {"record"};
    options.max_steps = 3;
    options.policy = [](const praxo::Action& action) {
        if (action.kind == "model.generate") {
            return praxo::Decision{true, "model generation"};
        }
        if (action.kind == "tool.invoke") {
            const bool allowed =
                action.tool_name.has_value() &&
                *action.tool_name == "record" &&
                action.arguments.contains("target") &&
                action.arguments.at("target").is_string() &&
                action.arguments.at("target").as_string() == "public";
            return praxo::Decision{
                allowed,
                allowed ? "the public target is permitted"
                        : "only the public target is permitted"};
        }
        return praxo::Decision{false, "unsupported action"};
    };

    try {
        auto result = praxo::run_agent(
            std::move(options),
            praxo::Session{"consumer-" + target, {}},
            "Record the requested target.");
        *output = result.output;
        *denied = false;
    } catch (const praxo::PraxoError& error) {
        *output = error.what();
        *denied = error.code() == "AGENT_POLICY_DENIED";
    }
    return effects;
}

int main() {
    int effects = 0;
    std::string output;
    bool denied = false;

    effects = run_scenario("public", &output, &denied);
    if (denied || output != "recorded" || effects != 1) {
        std::cerr << "allow verification failed: output=" << output
                  << " effects=" << effects << "\n";
        return 1;
    }
    std::cout << "allow: recorded; effects=" << effects << "\n";

    effects = run_scenario("private", &output, &denied);
    if (!denied || effects != 0) {
        std::cerr << "deny verification failed: effects=" << effects
                  << " output=" << output << "\n";
        return 1;
    }
    std::cout << "deny: policy rejected; effects=" << effects << "\n";
    return 0;
}
