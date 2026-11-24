#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* VOYAGE_ID = "voyage-100";

class VoyageAdapter {
public:
    virtual ~VoyageAdapter() = default;
    virtual praxo::Json read(const std::string& voyage) = 0;
};

class FixtureAdapter : public VoyageAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& voyage) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("VOYAGE_UNAVAILABLE",
                                    "route weather data unavailable");
        }
        praxo::Json great_circle = praxo::Json::object();
        great_circle["id"] = "great-circle";
        great_circle["cost"] = 100;
        great_circle["days"] = 12;
        praxo::Json coastal = praxo::Json::object();
        coastal["id"] = "coastal";
        coastal["cost"] = 115;
        coastal["days"] = 14;
        praxo::Json routes = praxo::Json::array();
        routes.push_back(great_circle);
        routes.push_back(coastal);
        praxo::Json snapshot = praxo::Json::object();
        snapshot["voyage_id"] = voyage;
        snapshot["routes"] = routes;
        snapshot["weather"] = "moderate";
        snapshot["recommended"] = "great-circle";
        snapshot["source"] = "voyage_fixture";
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
    explicit FixtureModel(std::string voyage) : voyage_(std::move(voyage)) {}

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
            arguments["voyage_id"] = voyage_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"voyage-1", "read_voyage", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["voyage_id"] = voyage_;
            arguments["action"] = "draft_route";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"route-1", "draft_route", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["voyage"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["route"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "compare and draft only; navigation and fuel decisions remain application-owned";
        report["navigation_commands"] = 0;
        report["fuel_claims"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string voyage_;
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
        return {true, "deterministic ocean routing"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string voyage = argument_string(action.arguments, "voyage_id");
    const bool in_scope = voyage == VOYAGE_ID;
    if (*action.tool_name == "read_voyage") {
        return {in_scope, "only voyage-100 read is allowed"};
    }
    if (*action.tool_name == "draft_route") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_route";
        return {ok, "only voyage-100 draft_route is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& voyage, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_voyage",
        "Compare fixed synthetic route and weather costs; no navigation access.",
        [adapter](const praxo::Json& arguments) {
            const std::string voyage_id = argument_string(arguments, "voyage_id");
            return adapter->read(voyage_id.empty() ? VOYAGE_ID : voyage_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_route",
        "Draft a review-only route recommendation; no navigation command.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string voyage_id = argument_string(arguments, "voyage_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json route = praxo::Json::object();
            route["route_id"] = "ocean-route-100";
            route["voyage_id"] = voyage_id.empty() ? VOYAGE_ID : voyage_id;
            route["action"] = action.empty() ? "draft_route" : action;
            route["route"] = "great-circle";
            route["estimated_days"] = 12;
            route["status"] = "draft_only";
            route["review_required"] = true;
            route["navigation_commands"] = 0;
            route["fuel_claims"] = 0;
            return route;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(voyage));
    options.tools = registry;
    options.allowed_tools = {"read_voyage", "draft_route"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-ocean-routing", {}},
            "Compare the fixed routes and draft a review-only route.");
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
    Outcome success = run_scenario(VOYAGE_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& voyage_report = report.at("voyage");
    const praxo::Json& route = report.at("route");
    if (!parse_string(route, "status", "draft_only") ||
        !parse_string(route, "route", "great-circle") ||
        !(route.contains("navigation_commands") &&
          route.at("navigation_commands").as_number() == 0) ||
        !(report.contains("fuel_claims") &&
          report.at("fuel_claims").as_number() == 0) ||
        !(voyage_report.contains("routes") &&
          voyage_report.at("routes").size() == 2) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: voyage-100 routes=2 route=great-circle status=draft_only "
                 "navigation=0 fuel_claims=0 reads=1\n";

    Outcome denied = run_scenario("voyage-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(VOYAGE_ID, true);
    if (failure.error != "VOYAGE_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: VOYAGE_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string voyage = VOYAGE_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--voyage" && index + 1 < argc) {
            voyage = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(voyage, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
