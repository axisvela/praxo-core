#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* TARGET_ID = "target-100";

class MoleculeAdapter {
public:
    virtual ~MoleculeAdapter() = default;
    virtual praxo::Json read(const std::string& target) = 0;
};

class FixtureAdapter : public MoleculeAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& target) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("MOLECULE_UNAVAILABLE",
                                    "molecule descriptors unavailable");
        }
        praxo::Json snapshot = praxo::Json::object();
        snapshot["target_id"] = target;
        snapshot["candidates"] = 4;
        snapshot["top"] = "mol-2";
        snapshot["constraints_ok"] = true;
        snapshot["mw"] = 342.1;
        snapshot["logp"] = 2.4;
        snapshot["source"] = "molecule_fixture";
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
    explicit FixtureModel(std::string target) : target_(std::move(target)) {}

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
            arguments["target_id"] = target_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"molecule-1", "read_candidates", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["target_id"] = target_;
            arguments["action"] = "draft_review";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"review-1", "draft_review", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["ranking"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["review"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "rank and draft only; efficacy, toxicity and synthesis remain application-owned";
        report["efficacy_claims"] = 0;
        report["toxicity_claims"] = 0;
        report["syntheses"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string target_;
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
        return {true, "deterministic molecule screen"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string target = argument_string(action.arguments, "target_id");
    const bool in_scope = target == TARGET_ID;
    if (*action.tool_name == "read_candidates") {
        return {in_scope, "only target-100 read is allowed"};
    }
    if (*action.tool_name == "draft_review") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_review";
        return {ok, "only target-100 draft_review is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& target, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_candidates",
        "Rank fixed synthetic molecular descriptors; no synthesis.",
        [adapter](const praxo::Json& arguments) {
            const std::string target_id = argument_string(arguments, "target_id");
            return adapter->read(target_id.empty() ? TARGET_ID : target_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_review",
        "Draft a review-only molecular assessment; no efficacy or toxicity claim.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string target_id = argument_string(arguments, "target_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json review = praxo::Json::object();
            review["review_id"] = "molecule-review-100";
            review["target_id"] = target_id.empty() ? TARGET_ID : target_id;
            review["action"] = action.empty() ? "draft_review" : action;
            review["top"] = "mol-2";
            review["status"] = "draft_only";
            review["review_required"] = true;
            review["efficacy_claims"] = 0;
            review["toxicity_claims"] = 0;
            review["syntheses"] = 0;
            return review;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(target));
    options.tools = registry;
    options.allowed_tools = {"read_candidates", "draft_review"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-molecule-screen", {}},
            "Rank the fixed candidates and draft a review-only assessment.");
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
    Outcome success = run_scenario(TARGET_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& ranking = report.at("ranking");
    const praxo::Json& review = report.at("review");
    if (!parse_string(ranking, "top", "mol-2") ||
        !(ranking.contains("constraints_ok") &&
          ranking.at("constraints_ok").is_bool() &&
          ranking.at("constraints_ok").as_bool()) ||
        !parse_string(review, "status", "draft_only") ||
        !(review.contains("efficacy_claims") &&
          review.at("efficacy_claims").as_number() == 0) ||
        !(report.contains("syntheses") &&
          report.at("syntheses").as_number() == 0) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: target-100 candidates=4 top=mol-2 status=draft_only "
                 "efficacy=0 toxicity=0 syntheses=0 reads=1\n";

    Outcome denied = run_scenario("target-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(TARGET_ID, true);
    if (failure.error != "MOLECULE_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: MOLECULE_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string target = TARGET_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--target" && index + 1 < argc) {
            target = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(target, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
