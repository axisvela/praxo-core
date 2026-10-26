#pragma once

#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
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
};

class Agent {
public:
    explicit Agent(AgentOptions options) : options_(std::move(options)) {}
    RunResult run(const Session& session, const std::string& prompt);

private:
    Message invoke_tool(const ToolCall& call, const std::string& run_id,
                        const std::string& session_id);
    void authorize(const Action& action) const;
    void emit(const std::string& type, const std::string& session_id,
              const std::string& run_id, const Json& data = Json(nullptr)) const;

    AgentOptions options_;
};

RunResult run_agent(AgentOptions options, const Session& session, const std::string& prompt);

}  // namespace praxo
