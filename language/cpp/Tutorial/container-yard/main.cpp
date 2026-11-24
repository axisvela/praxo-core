#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* YARD_ID = "yard-100";

class YardAdapter {
public:
    virtual ~YardAdapter() = default;
    virtual praxo::Json read(const std::string& yard) = 0;
};

class FixtureAdapter : public YardAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& yard) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("YARD_UNAVAILABLE",
                                    "yard job data unavailable");
        }
        praxo::Json snapshot = praxo::Json::object();
        snapshot["yard_id"] = yard;
        snapshot["jobs"] = 8;
        snapshot["cranes"] = 2;
        snapshot["agvs"] = 3;
        snapshot["source"] = "yard_fixture";
        return snapshot;
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
    explicit FixtureModel(std::string yard) : yard_(std::move(yard)) {}

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
            arguments["yard_id"] = yard_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"yard-1", "read_yard", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["yard_id"] = yard_;
            arguments["action"] = "draft_schedule";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"schedule-1", "draft_plan", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["yard"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["plan"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "replan and draft only; crane and AGV commands remain application-owned";
        report["crane_commands"] = 0;
        report["agv_commands"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string yard_;
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
        return {true, "deterministic yard scheduling"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string yard = argument_string(action.arguments, "yard_id");
    const bool in_scope = yard == YARD_ID;
    if (*action.tool_name == "read_yard") {
        return {in_scope, "only yard-100 read is allowed"};
    }
    if (*action.tool_name == "draft_plan") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_schedule";
        return {ok, "only yard-100 draft_schedule is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& yard, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_yard",
        "Read fixed container jobs and resource limits; no crane access.",
        [adapter](const praxo::Json& arguments) {
            const std::string yard_id = argument_string(arguments, "yard_id");
            return adapter->read(yard_id.empty() ? YARD_ID : yard_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_plan",
        "Draft a review-only container schedule; never commands cranes or AGVs.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string yard_id = argument_string(arguments, "yard_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json plan = praxo::Json::object();
            plan["plan_id"] = "yard-plan-100";
            plan["yard_id"] = yard_id.empty() ? YARD_ID : yard_id;
            plan["action"] = action.empty() ? "draft_schedule" : action;
            plan["assigned_jobs"] = 8;
            plan["status"] = "draft_only";
            plan["review_required"] = true;
            plan["crane_commands"] = 0;
            plan["agv_commands"] = 0;
            return plan;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(yard));
    options.tools = registry;
    options.allowed_tools = {"read_yard", "draft_plan"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-container-yard", {}},
            "Replan the fixed container jobs and draft a review-only schedule.");
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
    Outcome success = run_scenario(YARD_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& yard = report.at("yard");
    const praxo::Json& plan = report.at("plan");
    if (!parse_string(plan, "status", "draft_only") ||
        !(plan.contains("assigned_jobs") &&
          plan.at("assigned_jobs").as_number() == 8) ||
        !(plan.contains("crane_commands") &&
          plan.at("crane_commands").as_number() == 0) ||
        !(report.contains("agv_commands") &&
          report.at("agv_commands").as_number() == 0) ||
        !(yard.contains("jobs") && yard.at("jobs").as_number() == 8) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: yard-100 jobs=8 assigned=8 status=draft_only "
                 "crane_commands=0 agv_commands=0 reads=1\n";

    Outcome denied = run_scenario("yard-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(YARD_ID, true);
    if (failure.error != "YARD_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: YARD_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string yard = YARD_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--yard" && index + 1 < argc) {
            yard = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(yard, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
