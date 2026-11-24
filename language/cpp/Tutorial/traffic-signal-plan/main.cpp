#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* JUNCTION_ID = "junction-100";

class JunctionAdapter {
public:
    virtual ~JunctionAdapter() = default;
    virtual praxo::Json read(const std::string& junction) = 0;
};

class FixtureAdapter : public JunctionAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& junction) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("JUNCTION_UNAVAILABLE",
                                    "junction telemetry unavailable");
        }
        praxo::Json north = praxo::Json::object();
        north["id"] = "north";
        north["queue"] = 12;
        praxo::Json east = praxo::Json::object();
        east["id"] = "east";
        east["queue"] = 4;
        praxo::Json south = praxo::Json::object();
        south["id"] = "south";
        south["queue"] = 9;
        praxo::Json approaches = praxo::Json::array();
        approaches.push_back(north);
        approaches.push_back(east);
        approaches.push_back(south);
        praxo::Json junction_snapshot = praxo::Json::object();
        junction_snapshot["junction_id"] = junction;
        junction_snapshot["approaches"] = approaches;
        junction_snapshot["cycle_s"] = 90;
        praxo::Json limits = praxo::Json::object();
        limits["min_green_s"] = 10;
        limits["max_green_s"] = 45;
        junction_snapshot["limits"] = limits;
        junction_snapshot["source"] = "junction_fixture";
        return junction_snapshot;
    }

    int reads() const { return reads_; }

private:
    bool simulate_failure_;
    int reads_ = 0;
};

std::string argument_string(const praxo::Json& arguments, const char* key) {
    if (arguments.contains(key) && arguments.at(key).is_string()) {
        return arguments.at(key).as_string();
    }
    return {};
}

class FixtureModel : public praxo::Model {
public:
    explicit FixtureModel(std::string junction)
        : junction_(std::move(junction)) {}

    praxo::Response generate(const praxo::Request& request) override {
        const praxo::Message* first = nullptr;
        const praxo::Message* second = nullptr;
        int tool_count = 0;
        for (const auto& message : request.messages) {
            if (message.role != praxo::TOOL) continue;
            if (tool_count == 0) first = &message;
            if (tool_count == 1) second = &message;
            ++tool_count;
        }

        praxo::Response response;
        if (tool_count == 0) {
            praxo::Json arguments = praxo::Json::object();
            arguments["junction_id"] = junction_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"junction-1", "read_junction", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["junction_id"] = junction_;
            arguments["action"] = "draft_timing";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"timing-1", "draft_signal_plan", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["junction"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["plan"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "read and draft only; signal commands remain application-owned";
        report["signal_commands"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string junction_;
};

struct Outcome {
    std::string output;
    std::string error;
    bool denied = false;
    int reads = 0;
    int drafts = 0;
};

praxo::Decision policy(const praxo::Action& action) {
    if (action.kind == "model.generate") {
        return {true, "deterministic traffic plan"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string junction = argument_string(action.arguments, "junction_id");
    const bool in_scope = junction == JUNCTION_ID;
    if (*action.tool_name == "read_junction") {
        return {in_scope, "only junction-100 read is allowed"};
    }
    if (*action.tool_name == "draft_signal_plan") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_timing";
        return {ok, "only junction-100 draft_timing is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& junction, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_junction",
        "Read fixed junction queues and timing limits; no signal access.",
        [adapter](const praxo::Json& arguments) {
            const std::string junction_id =
                argument_string(arguments, "junction_id");
            return adapter->read(junction_id.empty() ? JUNCTION_ID : junction_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_signal_plan",
        "Draft a review-only signal timing plan; never commands a signal.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string junction_id =
                argument_string(arguments, "junction_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json green = praxo::Json::object();
            green["north"] = 30;
            green["east"] = 10;
            green["south"] = 20;
            praxo::Json plan = praxo::Json::object();
            plan["plan_id"] = "timing-100";
            plan["junction_id"] =
                junction_id.empty() ? JUNCTION_ID : junction_id;
            plan["action"] = action.empty() ? "draft_timing" : action;
            plan["green_s"] = green;
            plan["total_s"] = 60;
            plan["within_limits"] = true;
            plan["status"] = "draft_only";
            plan["review_required"] = true;
            plan["signal_commands"] = 0;
            return plan;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(junction));
    options.tools = registry;
    options.allowed_tools = {"read_junction", "draft_signal_plan"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-traffic-signal-plan", {}},
            "Read the fixed junction and draft a review-only timing plan.");
        outcome.output = result.output;
    } catch (const praxo::PraxoError& error) {
        outcome.error = error.code();
        outcome.output = error.what();
    }
    outcome.denied = outcome.error == "AGENT_POLICY_DENIED";
    outcome.reads = adapter->reads();
    outcome.drafts = drafts;
    return outcome;
}

bool parse_string(const praxo::Json& object, const char* key,
                  const char* expected) {
    return object.contains(key) && object.at(key).is_string() &&
           object.at(key).as_string() == expected;
}

int run_tests() {
    Outcome success = run_scenario(JUNCTION_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& junction = report.at("junction");
    const praxo::Json& plan = report.at("plan");
    if (!parse_string(plan, "status", "draft_only") ||
        !parse_string(plan, "action", "draft_timing") ||
        !(plan.contains("within_limits") && plan.at("within_limits").is_bool() &&
          plan.at("within_limits").as_bool()) ||
        !(plan.contains("signal_commands") &&
          plan.at("signal_commands").as_number() == 0) ||
        !(report.contains("signal_commands") &&
          report.at("signal_commands").as_number() == 0) ||
        !(junction.contains("cycle_s") &&
          junction.at("cycle_s").as_number() == 90) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: junction-100 cycle_s=90 green_s=60 "
                 "within_limits=true status=draft_only commands=0 "
                 "reads=1\n";

    Outcome denied = run_scenario("junction-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(JUNCTION_ID, true);
    if (failure.error != "JUNCTION_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: JUNCTION_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string junction = JUNCTION_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--junction" && index + 1 < argc) {
            junction = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(junction, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
