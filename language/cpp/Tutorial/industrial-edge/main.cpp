#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* DEVICE_ID = "edge-100";

class DeviceAdapter {
public:
    virtual ~DeviceAdapter() = default;
    virtual praxo::Json read(const std::string& device) = 0;
};

class FixtureAdapter : public DeviceAdapter {
public:
    explicit FixtureAdapter(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& device) override {
        ++reads_;
        if (simulate_failure_) {
            throw praxo::PraxoError("DEVICE_READ_FAILED",
                                    "edge adapter read failed");
        }
        praxo::Json snapshot = praxo::Json::object();
        snapshot["device_id"] = device;
        snapshot["health"] = "degraded";
        snapshot["firmware"] = "edge-2.4.1";
        snapshot["temperature_c"] = 71;
        snapshot["vibration_mm_s"] = 4.2;
        snapshot["pressure_bar"] = 6.1;
        snapshot["link"] = "fieldbus";
        snapshot["source"] = "adapter_fixture";
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
    explicit FixtureModel(std::string device) : device_(std::move(device)) {}

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
            arguments["device_id"] = device_;
            response.message = praxo::assistant_message(
                "", {praxo::ToolCall{"read-1", "read_device", arguments}});
            return response;
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["device_id"] = device_;
            arguments["action"] = "schedule_maintenance";
            arguments["reason"] = "vibration drift beyond threshold";
            response.message = praxo::assistant_message(
                "",
                {praxo::ToolCall{"maintenance-1", "draft_maintenance",
                                 arguments}});
            return response;
        }

        praxo::Json report = praxo::Json::object();
        report["device"] = praxo::Json::parse(
            first != nullptr ? first->content.value_or("null") : "null");
        report["draft"] = praxo::Json::parse(
            second != nullptr ? second->content.value_or("null") : "null");
        report["policy"] =
            "read and draft only; device writes remain application-owned";
        report["device_writes"] = 0;
        response.message = praxo::assistant_message(report.dump());
        return response;
    }

private:
    std::string device_;
};

struct Outcome {
    std::string output;
    std::string error;
    bool denied = false;
    int reads = 0;
};

praxo::Decision policy(const praxo::Action& action) {
    if (action.kind == "model.generate") {
        return {true, "deterministic edge diagnosis"};
    }
    if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
        return {false, "unsupported action"};
    }
    const std::string device = argument_string(action.arguments, "device_id");
    const bool in_scope = device == DEVICE_ID;
    if (*action.tool_name == "read_device") {
        return {in_scope, "only edge-100 read is allowed"};
    }
    if (*action.tool_name == "draft_maintenance") {
        const std::string draft =
            argument_string(action.arguments, "action");
        const bool ok = in_scope && draft == "schedule_maintenance";
        return {ok, "only edge-100 schedule_maintenance draft is allowed"};
    }
    return {false, "unknown tool"};
}

Outcome run_scenario(const std::string& device, bool simulate_failure) {
    auto adapter = std::make_shared<FixtureAdapter>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    int writes = 0;
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_device",
        "Read an edge device snapshot through an application-owned adapter.",
        [adapter](const praxo::Json& arguments) {
            const std::string device_id = argument_string(arguments, "device_id");
            return adapter->read(device_id.empty() ? DEVICE_ID : device_id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_maintenance",
        "Draft an operator maintenance action without a device write.",
        [&writes](const praxo::Json& arguments) {
            const std::string device_id = argument_string(arguments, "device_id");
            const std::string action = argument_string(arguments, "action");
            praxo::Json draft = praxo::Json::object();
            draft["draft_id"] = "maintenance-100";
            draft["device_id"] =
                device_id.empty() ? DEVICE_ID : device_id;
            draft["action"] =
                action.empty() ? "schedule_maintenance" : action;
            draft["status"] = "draft_only";
            draft["review_required"] = true;
            draft["device_writes"] = writes;
            return draft;
        }));

    praxo::AgentOptions options(std::make_shared<FixtureModel>(device));
    options.tools = registry;
    options.allowed_tools = {"read_device", "draft_maintenance"};
    options.max_steps = 5;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.policy = policy;

    Outcome outcome;
    try {
        auto result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-industrial-edge", {}},
            "Diagnose the fixed edge device and draft an operator maintenance "
            "action.");
        outcome.output = result.output;
    } catch (const praxo::PraxoError& error) {
        outcome.error = error.code();
        outcome.output = error.what();
    }
    outcome.denied = outcome.error == "AGENT_POLICY_DENIED";
    outcome.reads = adapter->reads();
    return outcome;
}

bool parse_string(const praxo::Json& object, const char* key,
                  const char* expected) {
    return object.contains(key) && object.at(key).is_string() &&
           object.at(key).as_string() == expected;
}

int run_tests() {
    Outcome success = run_scenario(DEVICE_ID, false);
    if (!success.error.empty()) {
        std::cerr << "success path failed: " << success.error << "\n";
        return 1;
    }
    praxo::Json report = praxo::Json::parse(success.output);
    const praxo::Json& device = report.at("device");
    const praxo::Json& draft = report.at("draft");
    if (!parse_string(device, "health", "degraded") ||
        !(device.contains("temperature_c") &&
          device.at("temperature_c").is_number() &&
          device.at("temperature_c").as_number() == 71) ||
        !parse_string(draft, "status", "draft_only") ||
        !parse_string(draft, "action", "schedule_maintenance") ||
        !(report.contains("device_writes") &&
          report.at("device_writes").as_number() == 0) ||
        success.reads != 1) {
        std::cerr << "success verification failed: reads=" << success.reads
                  << "\n";
        return 1;
    }
    std::cout << "success: edge-100 health=degraded "
                 "action=schedule_maintenance status=draft_only writes=0 "
                 "reads=1\n";

    Outcome denied = run_scenario("edge-200", false);
    if (!denied.denied || denied.reads != 0) {
        std::cerr << "deny verification failed: reads=" << denied.reads
                  << " error=" << denied.error << "\n";
        return 1;
    }
    std::cout << "deny: AGENT_POLICY_DENIED reads=0\n";

    Outcome failure = run_scenario(DEVICE_ID, true);
    if (failure.error != "DEVICE_READ_FAILED" || failure.reads != 1) {
        std::cerr << "failure verification failed: reads=" << failure.reads
                  << " error=" << failure.error << "\n";
        return 1;
    }
    std::cout << "failure: DEVICE_READ_FAILED reads=1\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    bool test_mode = false;
    bool simulate_failure = false;
    std::string device = DEVICE_ID;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--device" && index + 1 < argc) {
            device = argv[++index];
        }
    }

    if (test_mode) {
        return run_tests();
    }

    Outcome outcome = run_scenario(device, simulate_failure);
    if (!outcome.error.empty()) {
        std::cerr << "error: " << outcome.error << " reads=" << outcome.reads
                  << "\n";
        return outcome.denied ? 2 : 1;
    }
    std::cout << outcome.output << "\nreads=" << outcome.reads << "\n";
    return 0;
}
