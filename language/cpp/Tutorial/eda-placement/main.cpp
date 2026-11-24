#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* GRID_ID = "grid-100";

class GridAdapter {
public:
    virtual ~GridAdapter() = default;
    virtual praxo::Json read(const std::string& grid) = 0;
};

class FixtureAdapter : public GridAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& grid) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("GRID_UNAVAILABLE",
                                    "placement grid unavailable");
        }
        praxo::Json snapshot = praxo::Json::object();
        snapshot["grid_id"] = grid;
        snapshot["cells"] = 64;
        snapshot["nets"] = 40;
        snapshot["power_proxy"] = 12.5;
        snapshot["area_proxy"] = 0.82;
        snapshot["source"] = "grid_fixture";
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
    explicit FixtureModel(std::string grid) : grid_(std::move(grid)) {}

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
            arguments["grid_id"] = grid_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"grid-1", "read_grid", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["grid_id"] = grid_;
            arguments["action"] = "draft_placement";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"layout-1", "draft_layout", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["grid"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["layout"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "explore and draft only; foundry sign-off and tapeout remain application-owned";
        report["foundry_valid"] = false;
        report["tapeouts"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string grid_;
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
        return {true, "deterministic placement exploration"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string grid = argument_string(action.arguments, "grid_id");
    const bool in_scope = grid == GRID_ID;
    if (*action.tool_name == "read_grid") {
        return {in_scope, "only grid-100 read is allowed"};
    }
    if (*action.tool_name == "draft_layout") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_placement";
        return {ok, "only grid-100 draft_placement is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& grid, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_grid",
        "Read a fixed synthetic placement grid; no foundry access.",
        [adapter](const praxo::Json& arguments) {
            const std::string grid_id = argument_string(arguments, "grid_id");
            return adapter->read(grid_id.empty() ? GRID_ID : grid_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_layout",
        "Draft a review-only placement with stated PPA proxies; no tapeout.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string grid_id = argument_string(arguments, "grid_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json layout = praxo::Json::object();
            layout["layout_id"] = "placement-100";
            layout["grid_id"] = grid_id.empty() ? GRID_ID : grid_id;
            layout["action"] = action.empty() ? "draft_placement" : action;
            layout["placements"] = 64;
            layout["power_proxy"] = 12.5;
            layout["area_proxy"] = 0.82;
            layout["status"] = "draft_only";
            layout["review_required"] = true;
            layout["foundry_valid"] = false;
            layout["tapeouts"] = 0;
            return layout;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(grid));
    options.tools = registry;
    options.allowed_tools = {"read_grid", "draft_layout"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-eda-placement", {}},
            "Read the fixed grid and draft a review-only placement.");
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
    Outcome success = run_scenario(GRID_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& grid = report.at("grid");
    const praxo::Json& layout = report.at("layout");
    if (!parse_string(layout, "status", "draft_only") ||
        !(layout.contains("placements") &&
          layout.at("placements").as_number() == 64) ||
        !(layout.contains("foundry_valid") &&
          layout.at("foundry_valid").is_bool() &&
          !layout.at("foundry_valid").as_bool()) ||
        !(layout.contains("tapeouts") && layout.at("tapeouts").as_number() == 0) ||
        !(report.contains("foundry_valid") &&
          report.at("foundry_valid").is_bool() &&
          !report.at("foundry_valid").as_bool()) ||
        !(grid.contains("nets") && grid.at("nets").as_number() == 40) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: grid-100 cells=64 placements=64 status=draft_only "
                 "foundry_valid=false tapeouts=0 reads=1\n";

    Outcome denied = run_scenario("grid-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(GRID_ID, true);
    if (failure.error != "GRID_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: GRID_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string grid = GRID_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--grid" && index + 1 < argc) {
            grid = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(grid, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
