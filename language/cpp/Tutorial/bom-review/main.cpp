#include <iostream>
#include <memory>
#include <string>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* SCOPE_ID = "drawing-100";
constexpr const char* SCOPE_KEY = "drawing_id";
constexpr const char* TOOL_NAME = "review_drawing";
constexpr const char* ACTION_NAME = "draft_bom";
constexpr const char* ERROR_CODE = "DRAWING_UNAVAILABLE";

std::string argument_string(const praxo::Json& arguments, const char* key) {
    if (arguments.contains(key) && arguments.at(key).is_string()) {
        return arguments.at(key).as_string();
    }
    return {};
}

class FixtureModel : public praxo::Model {
public:
    explicit FixtureModel(std::string scope) : scope_(std::move(scope)) {}

    praxo::Response generate(const praxo::Request& request) override {
        const praxo::Message* last_tool = nullptr;
        int tool_count = 0;
        for (const auto& message : request.messages) {
            if (message.role == praxo::TOOL) {
                last_tool = &message;
                ++tool_count;
            }
        }
        praxo::Response response;
        if (tool_count == 0) {
            praxo::Json arguments = praxo::Json::object();
            arguments[SCOPE_KEY] = scope_;
            arguments["action"] = ACTION_NAME;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"tool-1", TOOL_NAME, arguments}});
            return response;
        }
        praxo::Json report = praxo::Json::object();
        report["stage"] = "bom_drafted";
        report["result"] = praxo::Json::parse(
            last_tool != nullptr ? last_tool->content.value_or("null") : "null");
        report["writes"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string scope_;
};

struct Outcome {
    std::string output;
    std::string error;
    bool denied = false;
    int reads = 0;
};

praxo::Decision policy(const praxo::Action& action) {
    if (action.kind == "model.generate") {
        return {true, "deterministic tutorial review"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string scope = argument_string(action.arguments, SCOPE_KEY);
    if (scope != SCOPE_ID) {
        return {false, "only drawing-100 is in scope"};
    }
    if (*action.tool_name == TOOL_NAME &&
        argument_string(action.arguments, "action") == ACTION_NAME) {
        return {true, "drawing-100 review-only draft"};
    }
    return {false, "only a review-only draft is allowed"};
}

Outcome run_scenario(const std::string& scope, bool simulate_failure) {
    int reads = 0;
    auto registry = std::make_shared<praxo::ToolRegistry>();
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        TOOL_NAME,
        "Read fixed bom review fixtures and draft a review-only result.",
        [&reads, simulate_failure](const praxo::Json& arguments) {
            ++reads;
            const std::string value = argument_string(arguments, SCOPE_KEY);
            if (value != SCOPE_ID) {
                throw praxo::PraxoError("AGENT_POLICY_DENIED",
                                        "scope outside fixture");
            }
            if (simulate_failure) {
                throw praxo::PraxoError(ERROR_CODE, "fixture unavailable");
            }
            praxo::Json result = praxo::Json::object();
            result["id"] = SCOPE_ID;
            result["count"] = 4;
            result["secondary"] = 3;
            result["status"] = "draft_only";
            result["review_required"] = true;
            result["writes"] = 0;
            result["source"] = "fixture";
            return result;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(scope));
    options.tools = registry;
    options.allowed_tools = {TOOL_NAME};
    options.max_steps = 3;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"bom-review", {}},
            "Read fixed bom review fixtures and draft a review-only result.");
        outcome.output = result.output;
    } catch (const praxo::PraxoError& error) {
        outcome.error = error.code();
        outcome.output = error.what();
    }
    outcome.denied = outcome.error == "AGENT_POLICY_DENIED";
    outcome.reads = reads;
    return outcome;
}

int run_tests() {
    Outcome success = run_scenario(SCOPE_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& result = report.at("result");
    if (!(result.contains("status") &&
          result.at("status").as_string() == "draft_only") ||
        !(result.contains("writes") && result.at("writes").as_number() == 0) ||
        !(report.contains("writes") && report.at("writes").as_number() == 0) ||
        success.reads != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << "\n";
        return 1;
    }
    std::cout << "success: drawing-100 status=draft_only writes=0 reads=1\n";

    Outcome denied = run_scenario("drawing-200", false);
    if (!denied.denied || denied.reads != 0) {
        std::cerr << "deny verification failed\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(SCOPE_ID, true);
    if (failure.error != ERROR_CODE || failure.reads != 1) {
        std::cerr << "failure verification failed: " << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: " << ERROR_CODE << " reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string scope = SCOPE_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--drawing" && index + 1 < argc) {
            scope = argv[++index];
        }
    }
    if (test_mode) {
        return run_tests();
    }
    Outcome outcome = run_scenario(scope, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads << "\n";
    return 0;
}
