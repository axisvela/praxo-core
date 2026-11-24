#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* MESH_ID = "mesh-100";

class MeshAdapter {
public:
    virtual ~MeshAdapter() = default;
    virtual praxo::Json read(const std::string& mesh) = 0;
};

class FixtureAdapter : public MeshAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& mesh) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("MESH_UNAVAILABLE",
                                    "mesh descriptor store unavailable");
        }
        praxo::Json snapshot = praxo::Json::object();
        snapshot["mesh_id"] = mesh;
        snapshot["vertices"] = 1200;
        snapshot["faces"] = 2400;
        snapshot["thickness_mm"] = 2.5;
        snapshot["min_thickness_mm"] = 2.0;
        snapshot["volume_cm3"] = 150.0;
        snapshot["source"] = "mesh_fixture";
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
    explicit FixtureModel(std::string mesh) : mesh_(std::move(mesh)) {}

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
            arguments["mesh_id"] = mesh_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"mesh-1", "read_mesh", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["mesh_id"] = mesh_;
            arguments["action"] = "draft_review";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"design-1", "draft_design", arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["mesh"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["design"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "compare and draft only; manufacturability and certification remain application-owned";
        report["certifications"] = 0;
        report["fabrications"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string mesh_;
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
        return {true, "deterministic mesh review"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string mesh = argument_string(action.arguments, "mesh_id");
    const bool in_scope = mesh == MESH_ID;
    if (*action.tool_name == "read_mesh") {
        return {in_scope, "only mesh-100 read is allowed"};
    }
    if (*action.tool_name == "draft_design") {
        const std::string draft = argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "draft_review";
        return {ok, "only mesh-100 draft_review is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& mesh, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int drafts = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_mesh",
        "Read fixed synthetic mesh descriptors; no CAD kernel or certification.",
        [adapter](const praxo::Json& arguments) {
            const std::string mesh_id = argument_string(arguments, "mesh_id");
            return adapter->read(mesh_id.empty() ? MESH_ID : mesh_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_design",
        "Draft a review-only design assessment against stated constraints.",
        [&drafts](const praxo::Json& arguments) {
            ++drafts;
            const std::string mesh_id = argument_string(arguments, "mesh_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json design = praxo::Json::object();
            design["design_id"] = "mesh-review-100";
            design["mesh_id"] = mesh_id.empty() ? MESH_ID : mesh_id;
            design["action"] = action.empty() ? "draft_review" : action;
            design["checks"] = 3;
            design["violations"] = 0;
            design["status"] = "draft_only";
            design["review_required"] = true;
            design["certifications"] = 0;
            design["fabrications"] = 0;
            return design;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(mesh));
    options.tools = registry;
    options.allowed_tools = {"read_mesh", "draft_design"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-mesh-review", {}},
            "Compare the fixed mesh descriptors and draft a review-only assessment.");
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
    Outcome success = run_scenario(MESH_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& mesh = report.at("mesh");
    const praxo::Json& design = report.at("design");
    if (!parse_string(design, "status", "draft_only") ||
        !(design.contains("violations") &&
          design.at("violations").as_number() == 0) ||
        !(design.contains("certifications") &&
          design.at("certifications").as_number() == 0) ||
        !(report.contains("fabrications") &&
          report.at("fabrications").as_number() == 0) ||
        !(mesh.contains("faces") && mesh.at("faces").as_number() == 2400) ||
        success.reads != 1 || success.drafts != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << " drafts=" << success.drafts << "\n";
        return 1;
    }
    std::cout << "success: mesh-100 faces=2400 checks=3 violations=0 "
                 "status=draft_only certifications=0 reads=1\n";

    Outcome denied = run_scenario("mesh-200", false);
    if (!denied.denied || denied.reads != 0 || denied.drafts != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " drafts=" << denied.drafts
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(MESH_ID, true);
    if (failure.error != "MESH_UNAVAILABLE" || failure.reads != 1 ||
        failure.drafts != 0) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " drafts=" << failure.drafts
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: MESH_UNAVAILABLE reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string mesh = MESH_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--mesh" && index + 1 < argc) {
            mesh = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(mesh, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << " drafts=" << outcome.drafts << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads
              << "\ndrafts=" << outcome.drafts << "\n";
    return 0;
}
