#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* BATCH_ID = "batch-100";

class MaterialAdapter {
public:
    virtual ~MaterialAdapter() = default;
    virtual praxo::Json read(const std::string& batch) = 0;
};

class FixtureAdapter : public MaterialAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& batch) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("MATERIAL_UNAVAILABLE",
                                    "candidate properties unavailable");
        }
        praxo::Json snapshot = praxo::Json::object();
        snapshot["batch_id"] = batch;
        snapshot["candidates"] = 3;
        snapshot["target_property"] = 0.85;
        snapshot["best"] = "mat-2";
        snapshot["best_value"] = 0.83;
        snapshot["source"] = "material_fixture";
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
    explicit FixtureModel(std::string batch) : batch_(std::move(batch)) {}

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
            arguments["batch_id"] = batch_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"batch-1", "read_candidates", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["batch_id"] = batch_;
            arguments["action"] = "draft_simulation";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"simulation-1", "draft_simulation", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["batch"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["simulation"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "evaluate and draft only; validated materials and fabrication remain application-owned";
        report["validated_materials"] = 0;
        report["fabrications"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string batch_;
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
        return {true, "deterministic materials design"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string batch = argument_string(action.arguments, "batch_id");
    const bool in_scope = batch == BATCH_ID;
    if (*action.tool_name == "read_candidates") {
        return {in_scope, "only batch-100 read is allowed"};
    }
    if (*action.tool_name == "draft_simulation") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_simulation";
        return {ok, "only batch-100 draft_simulation is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& batch, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_candidates",
        "Evaluate fixed candidate properties; no validated material claim.",
        [adapter](const praxo::Json& arguments) {
            const std::string batch_id = argument_string(arguments, "batch_id");
            return adapter->read(batch_id.empty() ? BATCH_ID : batch_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_simulation",
        "Draft a review-only next simulation; never fabricates material.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string batch_id = argument_string(arguments, "batch_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json parameters = praxo::Json::object();
            parameters["temperature_c"] = 1200;
            praxo::Json simulation = praxo::Json::object();
            simulation["simulation_id"] = "materials-100";
            simulation["batch_id"] = batch_id.empty() ? BATCH_ID : batch_id;
            simulation["action"] = action.empty() ? "draft_simulation" : action;
            simulation["next"] = "sim-2";
            simulation["parameters"] = parameters;
            simulation["status"] = "draft_only";
            simulation["review_required"] = true;
            simulation["validated_materials"] = 0;
            simulation["fabrications"] = 0;
            return simulation;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(batch));
    options.tools = registry;
    options.allowed_tools = {"read_candidates", "draft_simulation"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-materials-design", {}},
            "Evaluate the fixed candidates and draft the next review-only simulation.");
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
    Outcome success = run_scenario(BATCH_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& batch = report.at("batch");
    const praxo::Json& simulation = report.at("simulation");
    if (!parse_string(batch, "best", "mat-2") ||
        !(batch.contains("best_value") &&
          batch.at("best_value").as_number() == 0.83) ||
        !parse_string(simulation, "status", "draft_only") ||
        !(simulation.contains("validated_materials") &&
          simulation.at("validated_materials").as_number() == 0) ||
        !(report.contains("fabrications") &&
          report.at("fabrications").as_number() == 0) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: batch-100 candidates=3 best=mat-2 value=0.83 "
                 "status=draft_only validated=0 fabrications=0 reads=1\n";

    Outcome denied = run_scenario("batch-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(BATCH_ID, true);
    if (failure.error != "MATERIAL_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: MATERIAL_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string batch = BATCH_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--batch" && index + 1 < argc) {
            batch = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(batch, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
