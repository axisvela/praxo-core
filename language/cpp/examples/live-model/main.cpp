#include <ctime>
#include <iostream>
#include <map>
#include <memory>
#include <string>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/openai_compat.hpp"

static const char* kSchema = R"({
  "type": "object",
  "properties": {
    "zone": {
      "type": "string",
      "enum": ["utc", "local"],
      "description": "utc or local; defaults to utc"
    }
  }
})";

class SchematizedModel : public praxo::Model {
public:
    SchematizedModel(praxo::OpenAICompatibleOptions options,
                     praxo::OpenAICompatibleTransport transport)
        : inner_(std::move(options), std::move(transport)) {}

    praxo::Response generate(const praxo::Request& request) override {
        praxo::Request copy = request;
        praxo::ToolSpec spec;
        spec.name = "get_time";
        spec.description =
            "Return the current time in ISO 8601 format for the requested zone.";
        spec.parameters = praxo::Json::parse(kSchema);
        spec.risk = "read";
        copy.tools = {std::move(spec)};
        return inner_.generate(copy);
    }

private:
    praxo::OpenAICompatible inner_;
};

static std::string env_or(const char* name, const std::string& fallback) {
    const char* value = std::getenv(name);
    return value != nullptr && value[0] != '\0' ? value : fallback;
}

static std::string current_time(const std::string& zone) {
    std::time_t now = std::time(nullptr);
    const bool local = zone == "local";
    std::tm value = local ? *std::localtime(&now) : *std::gmtime(&now);
    char text[64];
    std::strftime(text, sizeof(text),
                  local ? "%Y-%m-%dT%H:%M:%S" : "%Y-%m-%dT%H:%M:%SZ",
                  &value);
    return text;
}

int main() {
    const std::string base_url =
        env_or("PRAXO_BASE_URL", "http://localhost:11434/v1");
    const std::string model_name = env_or("PRAXO_MODEL", "qwen3.5:4b");
    const std::string prompt = env_or(
        "PRAXO_PROMPT",
        "What time is it? Use get_time with zone set to utc and reply with the time.");

    praxo::OpenAICompatibleOptions provider;
    provider.base_url = base_url;
    provider.model = model_name;
    provider.api_key = env_or("PRAXO_API_KEY", "");

    praxo::OpenAICompatibleTransport transport =
        [](const std::string&, const praxo::Json&,
           const std::map<std::string, std::string>&)
        -> praxo::Json {
        throw praxo::PraxoError(
            "PROVIDER_HTTP",
            "no HTTP transport configured; supply one in examples/live-model/main.cpp");
    };

    auto tool = std::make_shared<praxo::FuncTool>(
        "get_time",
        "Return the current time in ISO 8601 format for the requested zone.",
        [](const praxo::Json& arguments) {
            std::string zone = "utc";
            if (arguments.contains("zone") && arguments.at("zone").is_string()) {
                zone = arguments.at("zone").as_string();
            }
            return praxo::Json(current_time(zone));
        });
    auto registry = std::make_shared<praxo::ToolRegistry>();
    registry->register_tool(tool);

    praxo::AgentOptions options(
        std::make_shared<SchematizedModel>(std::move(provider),
                                           std::move(transport)));
    options.tools = registry;
    options.system_prompt =
        "You are a concise assistant. Use the provided tools when they help.";
    options.max_steps = 4;
    options.allowed_tools = {"get_time"};
    options.policy = [](const praxo::Action& action) {
        if (action.kind == "model.generate") {
            return praxo::Decision{true, "model generation"};
        }
        if (action.kind == "tool.invoke") {
            const bool allowed =
                action.tool_name.has_value() && *action.tool_name == "get_time";
            return praxo::Decision{allowed, allowed ? "get_time is permitted"
                                                    : "only get_time is permitted"};
        }
        return praxo::Decision{false, "unsupported action"};
    };

    try {
        auto result = praxo::run_agent(std::move(options),
                                       praxo::Session{"live-model", {}}, prompt);
        std::cout << result.output << "\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "live model run failed: " << error.what() << "\n\n"
                  << "Check PRAXO_BASE_URL (" << base_url
                  << "), PRAXO_MODEL (" << model_name
                  << "), and PRAXO_API_KEY.\n"
                  << "The C++ Core bundles no HTTP client; supply a caller-owned\n"
                  << "OpenAICompatibleTransport in examples/live-model/main.cpp.\n";
        return 1;
    }
}
