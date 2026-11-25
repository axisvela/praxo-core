#include <algorithm>
#include <cctype>
#include <functional>
#include <iostream>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"

namespace {

constexpr const char* TENANT_SCOPE = "acme";
constexpr const char* DEVICE_SCOPE = "device-100";

struct Stats {
    int reads = 0;
    int drafts = 0;
    int executions = 0;

    praxo::Json json() const {
        praxo::Json value = praxo::Json::object();
        value["reads"] = reads;
        value["drafts"] = drafts;
        value["executions"] = executions;
        return value;
    }
};

struct Outcome {
    praxo::Json report = praxo::Json(nullptr);
    std::string error_code;
    std::string error_message;
    Stats stats;
    std::vector<praxo::Json> trace;
};

std::string argument_string(const praxo::Json& arguments, const char* key) {
    if (arguments.is_object() && arguments.contains(key) &&
        arguments.at(key).is_string()) {
        return arguments.at(key).as_string();
    }
    return {};
}

std::string lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

bool direct_execution(const std::string& intent) {
    const std::string value = lower(intent);
    return value.find("execute remediation") != std::string::npos ||
           value.find("remediate now") != std::string::npos;
}

std::string truncate(const std::string& value, std::size_t max) {
    if (value.size() <= max) return value;
    return value.substr(0, max) + "...";
}

class GatewayAdapter {
public:
    virtual ~GatewayAdapter() = default;
    virtual praxo::Json read(const std::string& device) = 0;
};

class FixtureGateway : public GatewayAdapter {
public:
    explicit FixtureGateway(bool simulate_failure)
        : simulate_failure_(simulate_failure) {}

    praxo::Json read(const std::string& device) override {
        if (simulate_failure_) {
            throw praxo::PraxoError("DEVICE_READ_FAILED",
                                    "edge gateway adapter unavailable");
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

private:
    bool simulate_failure_;
};

class DeterministicModel : public praxo::Model {
public:
    DeterministicModel(std::string device, std::string intent)
        : device_(std::move(device)), intent_(std::move(intent)) {}

    praxo::Response generate(const praxo::Request& request) override {
        const praxo::Message* first = nullptr;
        int tool_count = 0;
        for (const auto& message : request.messages) {
            if (message.role != praxo::TOOL) continue;
            if (tool_count == 0) first = &message;
            ++tool_count;
        }

        if (tool_count == 0) {
            if (direct_execution(intent_)) {
                praxo::Json arguments = praxo::Json::object();
                arguments["device_id"] = device_;
                arguments["intent"] = intent_;
                return response_with_call("execute-1", "execute_remediation",
                                          arguments);
            }
            praxo::Json arguments = praxo::Json::object();
            arguments["device_id"] = device_;
            return response_with_call("read-1", "read_device", arguments);
        }

        praxo::Json first_value = praxo::Json(nullptr);
        if (first != nullptr && first->content.has_value()) {
            try {
                first_value = praxo::Json::parse(*first->content);
            } catch (...) {
                return text_response("INVALID_SIGNALS");
            }
        }
        if (first_value.is_object() && first_value.contains("error") &&
            first_value.at("error").is_string()) {
            return text_response(first_value.at("error").as_string());
        }
        if (tool_count == 1) {
            praxo::Json arguments = praxo::Json::object();
            arguments["device_id"] = device_;
            arguments["action"] = "review_remediation";
            arguments["diagnosis"] =
                "edge gateway shows degraded health and rising vibration";
            arguments["rationale"] =
                "temperature_c 71 and vibration_mm_s 4.2 exceed the review threshold";
            return response_with_call("draft-1", "draft_maintenance", arguments);
        }

        const praxo::Message* last = nullptr;
        for (const auto& message : request.messages) {
            if (message.role == praxo::TOOL) last = &message;
        }
        praxo::Json last_value = praxo::Json(nullptr);
        if (last != nullptr && last->content.has_value()) {
            try {
                last_value = praxo::Json::parse(*last->content);
            } catch (...) {
                return text_response("INVALID_DRAFT");
            }
        }
        praxo::Json report = praxo::Json::object();
        report["device"] = device_;
        report["signals"] = first_value;
        report["remediation"] = last_value;
        report["executions"] = 0;
        return text_response(report.dump());
    }

private:
    static praxo::Response text_response(const std::string& content) {
        praxo::Response response;
        response.message = praxo::assistant_message(content);
        return response;
    }

    static praxo::Response response_with_call(const std::string& id,
                                              const std::string& name,
                                              const praxo::Json& arguments) {
        praxo::Response response;
        response.message = praxo::assistant_message(
            "", {praxo::ToolCall{id, name, arguments}});
        return response;
    }

    std::string device_;
    std::string intent_;
};

class TracingModel : public praxo::Model {
public:
    explicit TracingModel(std::shared_ptr<praxo::Model> inner)
        : inner_(std::move(inner)) {}

    praxo::Response generate(const praxo::Request& request) override {
        try {
            praxo::Response response = inner_->generate(request);
            record(request, &response, nullptr);
            return response;
        } catch (const praxo::PraxoError& error) {
            record(request, nullptr, &error);
            throw;
        }
    }

    std::vector<praxo::Json> steps() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return steps_;
    }

private:
    void record(const praxo::Request& request, const praxo::Response* response,
                const praxo::PraxoError* error) {
        praxo::Json tool_calls = praxo::Json::array();
        praxo::Json tool_results = praxo::Json::array();
        for (const auto& message : request.messages) {
            for (const auto& call : message.tool_calls) {
                praxo::Json item = praxo::Json::object();
                item["name"] = call.name;
                item["arguments"] = call.arguments;
                tool_calls.push_back(item);
            }
            if (message.role == praxo::TOOL) {
                praxo::Json item = praxo::Json::object();
                item["tool_id"] = message.tool_id.value_or("");
                item["content"] = message.content.value_or("");
                tool_results.push_back(item);
            }
        }

        praxo::Json output = praxo::Json::object();
        if (error != nullptr) {
            output["error"] = error->code();
        } else if (response != nullptr) {
            praxo::Json output_calls = praxo::Json::array();
            for (const auto& call : response->message.tool_calls) {
                praxo::Json item = praxo::Json::object();
                item["name"] = call.name;
                item["arguments"] = call.arguments;
                output_calls.push_back(item);
            }
            output["content"] =
                truncate(response->message.content.value_or(""), 1000);
            output["tool_calls"] = output_calls;
        }

        praxo::Json step = praxo::Json::object();
        step["tool_calls"] = tool_calls;
        step["tool_results"] = tool_results;
        step["model_output"] = output;
        std::lock_guard<std::mutex> lock(mutex_);
        steps_.push_back(std::move(step));
    }

    std::shared_ptr<praxo::Model> inner_;
    mutable std::mutex mutex_;
    std::vector<praxo::Json> steps_;
};

std::function<praxo::Decision(const praxo::Action&)> ops_policy(
        const std::string& tenant) {
    return [tenant](const praxo::Action& action) -> praxo::Decision {
        if (tenant != TENANT_SCOPE) {
            return {false, "tenant mismatch"};
        }
        if (action.kind == "model.generate") {
            return {true, "ops generation"};
        }
        if (action.kind != "tool.invoke" || !action.tool_name.has_value()) {
            return {false, "unsupported action"};
        }
        const std::string device =
            argument_string(action.arguments, "device_id");
        if (*action.tool_name == "execute_remediation") {
            return {false, "execution requires an approved host workflow"};
        }
        if (device != DEVICE_SCOPE) {
            return {false, "only device-100 is in scope"};
        }
        if (*action.tool_name == "read_device") {
            return {true, "read-only telemetry"};
        }
        if (*action.tool_name == "draft_maintenance") {
            const std::string draft =
                argument_string(action.arguments, "action");
            const std::string diagnosis =
                argument_string(action.arguments, "diagnosis");
            const std::string rationale =
                argument_string(action.arguments, "rationale");
            if (draft == "review_remediation" && !diagnosis.empty() &&
                !rationale.empty()) {
                return {true, "review-only remediation"};
            }
            return {false,
                    "review_remediation with diagnosis and rationale is required"};
        }
        return {false, "unsupported tool"};
    };
}

std::string map_error_code(const std::string& code) {
    if (code == "DEVICE_READ_FAILED") return "TOOL_ERROR";
    if (code == "AGENT_TOOL_NOT_ALLOWED") return "AGENT_POLICY_DENIED";
    return code;
}

std::string classify_exception(const std::exception& error) {
    const std::string message = lower(error.what());
    if (message.find("policy") != std::string::npos ||
        message.find("denied") != std::string::npos) {
        return "AGENT_POLICY_DENIED";
    }
    if (message.find("tool") != std::string::npos) {
        return "TOOL_ERROR";
    }
    return "AGENT_RUNTIME_ERROR";
}

praxo::Json parse_report(const std::string& output) {
    try {
        return praxo::Json::parse(output);
    } catch (...) {
    }
    const auto start = output.find('{');
    const auto end = output.rfind('}');
    if (start != std::string::npos && end != std::string::npos && start < end) {
        try {
            return praxo::Json::parse(output.substr(start, end - start + 1));
        } catch (...) {
        }
    }
    throw praxo::PraxoError("AGENT_INVALID_OUTPUT",
                            "agent did not return the required edge package");
}

const praxo::Json* find_payload(const std::vector<praxo::Json>& payloads,
                                const char* key) {
    for (const auto& payload : payloads) {
        if (payload.is_object() && payload.contains(key)) return &payload;
    }
    return nullptr;
}

void normalize_report(praxo::Json& report, const std::string& device,
                      const std::vector<praxo::Json>& trace) {
    std::vector<praxo::Json> payloads;
    for (const auto& step : trace) {
        if (!step.contains("tool_results") ||
            !step.at("tool_results").is_array()) {
            continue;
        }
        for (const auto& result : step.at("tool_results").as_array()) {
            if (!result.contains("content") ||
                !result.at("content").is_string()) {
                continue;
            }
            try {
                payloads.push_back(
                    praxo::Json::parse(result.at("content").as_string()));
            } catch (...) {
            }
        }
    }
    if (const praxo::Json* value = find_payload(payloads, "remediation_id")) {
        report["remediation"] = *value;
    }
    if (const praxo::Json* value = find_payload(payloads, "temperature_c")) {
        report["signals"] = *value;
    }
    if (const praxo::Json* value = find_payload(payloads, "review_id")) {
        report["review"] = *value;
    }
    report["device"] = device;
    report["executions"] = 0;
}

bool valid_report(const praxo::Json& report) {
    for (const char* key : {"device", "signals", "remediation", "executions"}) {
        if (!report.is_object() || !report.contains(key)) return false;
    }
    return report.at("executions").is_number() &&
           report.at("executions").as_number() == 0;
}

bool trace_has_tool(const std::vector<praxo::Json>& trace,
                    const std::string& name) {
    for (const auto& step : trace) {
        if (step.contains("tool_calls") && step.at("tool_calls").is_array()) {
            for (const auto& call : step.at("tool_calls").as_array()) {
                if (call.contains("name") && call.at("name").is_string() &&
                    call.at("name").as_string() == name) {
                    return true;
                }
            }
        }
        if (step.contains("model_output") &&
            step.at("model_output").contains("tool_calls") &&
            step.at("model_output").at("tool_calls").is_array()) {
            for (const auto& call :
                 step.at("model_output").at("tool_calls").as_array()) {
                if (call.contains("name") && call.at("name").is_string() &&
                    call.at("name").as_string() == name) {
                    return true;
                }
            }
        }
    }
    return false;
}

Outcome failure(const std::string& code, const std::string& message,
                const Stats& stats, const std::vector<praxo::Json>& trace) {
    Outcome outcome;
    outcome.error_code = code;
    outcome.error_message = message;
    outcome.stats = stats;
    outcome.trace = trace;
    return outcome;
}

Outcome run_scenario(const std::string& tenant, const std::string& device,
                     const std::string& intent, bool simulate_failure,
                     std::shared_ptr<praxo::Model> model_override = nullptr) {
    Stats stats;
    auto adapter = std::make_shared<FixtureGateway>(simulate_failure);
    auto registry = std::make_shared<praxo::ToolRegistry>();
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "read_device",
        "Read an edge device snapshot through an application-owned adapter.",
        [adapter, &stats](const praxo::Json& arguments) {
            ++stats.reads;
            const std::string id = argument_string(arguments, "device_id");
            return adapter->read(id.empty() ? DEVICE_SCOPE : id);
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "draft_maintenance",
        "Draft a model-written review-only maintenance action; never writes.",
        [&stats](const praxo::Json& arguments) {
            ++stats.drafts;
            praxo::Json draft = praxo::Json::object();
            draft["remediation_id"] = "remediation-100";
            draft["device_id"] =
                argument_string(arguments, "device_id");
            draft["action"] = argument_string(arguments, "action");
            draft["diagnosis"] = argument_string(arguments, "diagnosis");
            draft["rationale"] = argument_string(arguments, "rationale");
            draft["status"] = "draft_only";
            draft["review_required"] = true;
            draft["executions"] = 0;
            return draft;
        }));
    registry->register_tool(std::make_shared<praxo::FuncTool>(
        "execute_remediation",
        "Would execute remediation. Always denied in the agent path.",
        [&stats](const praxo::Json& arguments) {
            ++stats.executions;
            praxo::Json result = praxo::Json::object();
            result["device_id"] = argument_string(arguments, "device_id");
            result["status"] = "executed";
            return result;
        }));

    std::shared_ptr<praxo::Model> base_model;
    std::string mode = "deterministic";
    if (model_override != nullptr) {
        base_model = std::move(model_override);
        mode = "injected";
    } else {
        base_model = std::make_shared<DeterministicModel>(device, intent);
    }
    auto tracing = std::make_shared<TracingModel>(base_model);
    praxo::AgentOptions options(tracing);
    options.tools = registry;
    options.allowed_tools = {"read_device", "draft_maintenance",
                             "execute_remediation"};
    options.policy = ops_policy(tenant);
    options.require_policy = true;
    options.require_tool_scope = true;
    options.max_steps = 4;
    options.max_tokens = 60000;
    options.system_prompt =
        "You are an edge operations copilot for tenant " + tenant +
        ". The only authorized device id is device-100. Use that exact id in "
        "tool arguments. Search telemetry, diagnose, and draft a review-only "
        "remediation. Never execute remediation; return JSON with device, "
        "signals, remediation, and executions.";

    try {
        praxo::RunResult result = praxo::run_agent(
            std::move(options), praxo::Session{"cpp-ai-edge", {}}, intent);
        const auto trace = tracing->steps();
        praxo::Json report = parse_report(result.output);
        normalize_report(report, device, trace);
        if (!valid_report(report)) {
            return failure("AGENT_INVALID_OUTPUT",
                           "agent did not return the required edge package",
                           stats, trace);
        }
        report["tenant"] = tenant;
        report["model"] = mode;
        praxo::Json trace_json = praxo::Json::array();
        for (const auto& step : trace) trace_json.push_back(step);
        report["agent_trace"] = trace_json;
        Outcome outcome;
        outcome.report = report;
        outcome.stats = stats;
        outcome.trace = trace;
        return outcome;
    } catch (const praxo::PraxoError& error) {
        return failure(map_error_code(error.code()), error.what(), stats,
                       tracing->steps());
    } catch (const std::exception& error) {
        return failure(classify_exception(error), error.what(), stats,
                       tracing->steps());
    }
}

bool report_string(const praxo::Json& object, const char* key,
                   const char* expected) {
    return object.contains(key) && object.at(key).is_string() &&
           object.at(key).as_string() == expected;
}

int run_tests() {
    Outcome success = run_scenario(TENANT_SCOPE, DEVICE_SCOPE,
                                   "Investigate the edge gateway.", false);
    if (!success.error_code.empty()) {
        std::cerr << "success path failed: " << success.error_code << " "
                  << success.error_message << "\n";
        return 1;
    }
    const praxo::Json& report = success.report;
    const praxo::Json& remediation = report.at("remediation");
    if (!report_string(report, "model", "deterministic") ||
        !report_string(remediation, "status", "draft_only") ||
        !remediation.contains("diagnosis") ||
        !remediation.at("diagnosis").is_string() ||
        remediation.at("diagnosis").as_string().empty() ||
        !remediation.contains("rationale") ||
        !remediation.at("rationale").is_string() ||
        remediation.at("rationale").as_string().empty() ||
        !report.contains("executions") ||
        !report.at("executions").is_number() ||
        report.at("executions").as_number() != 0 ||
        success.stats.reads != 1 || success.stats.drafts != 1 ||
        success.stats.executions != 0 ||
        !trace_has_tool(success.trace, "read_device") ||
        !trace_has_tool(success.trace, "draft_maintenance")) {
        std::cerr << "success verification failed\n";
        return 1;
    }
    std::cout << "success: draft_only executions=0 reads=1 drafts=1\n";

    Outcome direct = run_scenario(TENANT_SCOPE, DEVICE_SCOPE,
                                  "Remediate now for device-100.", false);
    if (direct.error_code != "AGENT_POLICY_DENIED" || direct.stats.reads != 0 ||
        direct.stats.executions != 0) {
        std::cerr << "direct denial failed: " << direct.error_code << "\n";
        return 1;
    }
    std::cout << "deny: direct remediation rejected with zero effects\n";

    Outcome denied =
        run_scenario(TENANT_SCOPE, "device-200", "Investigate.", false);
    if (denied.error_code != "AGENT_POLICY_DENIED" || denied.stats.reads != 0) {
        std::cerr << "device scope denial failed: " << denied.error_code
                  << "\n";
        return 1;
    }
    std::cout << "deny: device-200 rejected before read\n";

    Outcome tenant =
        run_scenario("other", DEVICE_SCOPE, "Investigate.", false);
    if (tenant.error_code != "AGENT_POLICY_DENIED" ||
        tenant.stats.reads != 0) {
        std::cerr << "tenant denial failed: " << tenant.error_code << "\n";
        return 1;
    }
    std::cout << "deny: tenant mismatch rejected before read\n";

    Outcome failure =
        run_scenario(TENANT_SCOPE, DEVICE_SCOPE, "Investigate.", true);
    if (failure.error_code != "TOOL_ERROR" || failure.stats.reads != 1 ||
        failure.stats.drafts != 0) {
        std::cerr << "gateway failure mapping failed: " << failure.error_code
                  << " reads=" << failure.stats.reads << "\n";
        return 1;
    }
    std::cout << "failure: TOOL_ERROR after one read\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    std::string tenant = TENANT_SCOPE;
    std::string device = DEVICE_SCOPE;
    std::string intent =
        "Investigate the edge gateway telemetry and draft a review-only "
        "remediation.";
    bool test_mode = false;
    bool simulate_failure = false;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--test") {
            test_mode = true;
        } else if (argument == "--simulate-failure") {
            simulate_failure = true;
        } else if (argument == "--tenant" && index + 1 < argc) {
            tenant = argv[++index];
        } else if (argument == "--device" && index + 1 < argc) {
            device = argv[++index];
        } else if (argument == "--intent" && index + 1 < argc) {
            intent = argv[++index];
        }
    }
    if (test_mode) return run_tests();

    Outcome outcome =
        run_scenario(tenant, device, intent, simulate_failure);
    praxo::Json response = praxo::Json::object();
    if (outcome.error_code.empty()) {
        response["report"] = outcome.report;
        response["agent"] = outcome.stats.json();
        std::cout << response.dump() << "\n";
        return 0;
    }
    response["error"] = outcome.error_code;
    response["message"] = outcome.error_message;
    response["agent"] = outcome.stats.json();
    std::cout << response.dump() << "\n";
    std::cerr << "error: " << outcome.error_code << ": "
              << outcome.error_message << "\n";
    return outcome.error_code == "AGENT_POLICY_DENIED" ? 2 : 1;
}
