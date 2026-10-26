#include "praxo/agent.hpp"

#include <chrono>

#include "praxo/errors.hpp"

namespace praxo {

void ToolRegistry::register_tool(std::shared_ptr<Tool> tool) {
    tools_[tool->name()] = std::move(tool);
}

std::shared_ptr<Tool> ToolRegistry::get(const std::string& name) const {
    auto it = tools_.find(name);
    if (it == tools_.end()) {
        throw PraxoError("TOOL_NOT_FOUND", "tool not found: " + name);
    }
    return it->second;
}

std::vector<ToolSpec> ToolRegistry::specs() const {
    std::vector<ToolSpec> out;
    for (const auto& [name, tool] : tools_) {
        (void)name;
        ToolSpec spec;
        spec.name = tool->name();
        spec.description = tool->description();
        out.push_back(spec);
    }
    return out;
}

Response StaticModel::generate(const Request& request) {
    (void)request;
    Response response;
    response.message = assistant_message(content_);
    return response;
}

Message Agent::invoke_tool(const ToolCall& call, const std::string& run_id,
                           const std::string& session_id) {
    Action action;
    action.kind = "tool.invoke";
    action.session_id = session_id;
    action.tool_name = call.name;
    action.arguments = call.arguments;
    authorize(action);
    if (!options_.tools) {
        throw PraxoError("TOOL_NOT_FOUND", "tool is not registered");
    }
    auto tool = options_.tools->get(call.name);
    Json data = Json::object();
    data["name"] = call.name;
    data["arguments"] = call.arguments;
    emit("tool.call", session_id, run_id, data);
    Json result = tool->invoke(call.arguments);
    return tool_message(result.dump(), call.id);
}

void Agent::authorize(const Action& action) const {
    if (!options_.policy) return;
    Decision decision = options_.policy(action);
    if (!decision.allowed) {
        throw PraxoError("POLICY_ERROR", "policy denied the action");
    }
}

void Agent::emit(const std::string& type, const std::string& session_id,
                 const std::string& run_id, const Json& data) const {
    if (!options_.events) return;
    Event event;
    event.type = type;
    event.session_id = session_id;
    event.run_id = run_id;
    event.data = data;
    options_.events->emit(event);
}

RunResult Agent::run(const Session& session, const std::string& prompt) {
    int max_steps = options_.max_steps > 0 ? options_.max_steps : 8;
    auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    std::string run_id = "run-" + std::to_string(millis);
    std::vector<Message> messages = session.messages;
    if (!options_.system_prompt.empty()) {
        messages.insert(messages.begin(), text_message(SYSTEM, options_.system_prompt));
    }
    messages.push_back(text_message(USER, prompt));
    Usage usage;
    emit("run.started", session.id, run_id);
    try {
        for (int step = 1; step <= max_steps; ++step) {
            Action action;
            action.kind = "model.generate";
            action.session_id = session.id;
            authorize(action);
            if (options_.context) {
                auto [compacted, ok] = options_.context->compact(messages);
                if (!ok) throw PraxoError("AGENT_CONTEXT_BUDGET", "context budget");
                messages = std::move(compacted);
            }
            Request request;
            request.messages = messages;
            if (options_.tools) request.tools = options_.tools->specs();
            Response response = options_.model->generate(request);
            usage = usage.plus(response.usage);
            if (options_.max_tokens > 0 &&
                usage.input_tokens + usage.output_tokens > options_.max_tokens) {
                throw PraxoError("AGENT_MAX_TOKENS", "token budget");
            }
            messages.push_back(response.message);
            if (response.message.tool_calls.empty()) {
                emit("run.completed", session.id, run_id);
                return {run_id, response.message.content.value_or(""), step, usage};
            }
            for (const auto& call : response.message.tool_calls) {
                messages.push_back(invoke_tool(call, run_id, session.id));
            }
        }
        throw PraxoError("AGENT_MAX_STEPS", "maximum steps");
    } catch (const std::exception& error) {
        Json data = Json::object();
        data["error"] = error.what();
        emit("run.failed", session.id, run_id, data);
        throw;
    }
}

RunResult run_agent(AgentOptions options, const Session& session, const std::string& prompt) {
    return Agent(std::move(options)).run(session, prompt);
}

}  // namespace praxo
