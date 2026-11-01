#pragma once

#include <exception>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "praxo/models.hpp"
#include "praxo/runtime.hpp"

namespace praxo {

class Tool {
public:
    virtual ~Tool() = default;
    virtual std::string name() const = 0;
    virtual std::string description() const = 0;
    virtual Json invoke(const Json& arguments) = 0;
};

class FuncTool : public Tool {
public:
    using Function = std::function<Json(const Json&)>;
    FuncTool(std::string name, std::string description, Function function)
        : name_(std::move(name)), description_(std::move(description)),
          function_(std::move(function)) {}
    std::string name() const override { return name_; }
    std::string description() const override { return description_; }
    Json invoke(const Json& arguments) override { return function_(arguments); }

private:
    std::string name_;
    std::string description_;
    Function function_;
};

class ToolRegistry {
public:
    void register_tool(std::shared_ptr<Tool> tool);
    std::shared_ptr<Tool> get(const std::string& name) const;
    std::vector<ToolSpec> specs() const;

private:
    std::map<std::string, std::shared_ptr<Tool>> tools_;
};

class Model {
public:
    virtual ~Model() = default;
    virtual Response generate(const Request& request) = 0;
};

class StaticModel : public Model {
public:
    explicit StaticModel(std::string content) : content_(std::move(content)) {}
    Response generate(const Request& request) override;

private:
    std::string content_;
};

struct Middleware {
    std::function<void(const std::string& run_id, const std::string& prompt)> before_run;
    std::function<void(const RunResult* result, const std::string* error)> after_run;
    std::function<ToolCall(ToolCall call)> before_tool;
};

class AgentOptions {
public:
    explicit AgentOptions(std::shared_ptr<Model> model) : model(std::move(model)) {}

    std::shared_ptr<Model> model;
    std::shared_ptr<ToolRegistry> tools;
    EventSink* events = nullptr;
    std::function<Decision(const Action&)> policy;
    std::string system_prompt;
    std::optional<ContextBudget> context;
    int max_steps = 8;
    int max_tokens = 0;
    std::vector<Middleware> middleware;
    std::vector<std::string> allowed_tools;
    std::function<bool()> cancellation;
    std::function<void(const StreamPart&)> on_stream;
    int max_parallel_tools = 1;
};

class Agent {
public:
    explicit Agent(AgentOptions options) : options_(std::move(options)) {}
    RunResult run(const Session& session, const std::string& prompt);

private:
    Message invoke_tool(const ToolCall& call, const std::string& run_id,
                        const std::string& session_id);
    std::vector<Message> invoke_tools(const std::vector<ToolCall>& calls,
                                      const std::string& run_id,
                                      const std::string& session_id);
    std::pair<std::shared_ptr<Tool>, ToolCall> prepare_tool(
        const ToolCall& call, const std::string& run_id,
        const std::string& session_id);
    Message execute_tool(const std::shared_ptr<Tool>& tool,
                         const ToolCall& call);
    void check_cancelled() const;
    void emit_stream(const std::string& run_id, const std::string& session_id,
                     const std::string& kind, int step, const Json& data) const;
    void authorize(const Action& action) const;
    bool allowed(const std::string& name) const;
    void before_run(const std::string& run_id, const std::string& prompt,
                    std::vector<size_t>& entered);
    std::exception_ptr after_run(const std::vector<size_t>& entered,
                                 const RunResult* result, const std::string* error);
    void emit(const std::string& type, const std::string& session_id,
              const std::string& run_id, const Json& data = Json(nullptr)) const;

    AgentOptions options_;
};

RunResult run_agent(AgentOptions options, const Session& session, const std::string& prompt);

}  // namespace praxo
