#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/models.hpp"

using namespace praxo;

namespace {

class FixtureModel : public Model {
public:
    Response generate(const Request& request) override {
        const Message& last = request.messages.back();
        if (last.role == TOOL) {
            Response response;
            response.message = assistant_message("done");
            return response;
        }
        ToolCall call;
        call.id = "write-note-1";
        call.name = "write_note";
        call.arguments["text"] = "hello";
        call.arguments["visibility"] = "public";
        Response response;
        response.message = assistant_message("", {call});
        return response;
    }
};

class WriteNoteTool : public Tool {
public:
    std::vector<std::string> notes;

    std::string name() const override { return "write_note"; }

    std::string description() const override {
        return "Write a short note with the requested visibility.";
    }

    Json invoke(const Json& arguments) override {
        notes.push_back(arguments["text"].as_string());
        return Json("written");
    }
};

Decision public_notes_policy(const Action& action) {
    if (action.kind == "model.generate") return {true, "model generation"};
    if (action.kind == "tool.invoke") {
        const bool allowed = action.tool_name.has_value() &&
            *action.tool_name == "write_note" &&
            action.arguments.contains("visibility") &&
            action.arguments["visibility"].as_string() == "public";
        return {allowed, "only public notes are permitted"};
    }
    return {false, "unsupported action"};
}

struct Built {
    Agent agent;
    std::shared_ptr<WriteNoteTool> tool;
};

Built build_agent(InterruptDecision decision) {
    auto tool = std::make_shared<WriteNoteTool>();
    auto tools = std::make_shared<ToolRegistry>();
    tools->register_tool(tool);
    AgentOptions options(std::make_shared<FixtureModel>());
    options.tools = tools;
    options.max_steps = 3;
    options.allowed_tools = {"write_note"};
    options.interrupt_on = {"write_note"};
    options.policy = public_notes_policy;
    options.on_interrupt_decision = [decision](const Interrupt&) {
        return decision;
    };
    return {Agent(std::move(options)), tool};
}

}  // namespace

int main() {
    auto approved = build_agent(InterruptDecision{InterruptAction::Approve});
    auto result = approved.agent.run(Session{"hitl-approve", {}}, "Write a note.");
    if (result.output != "done" || approved.tool->notes.size() != 1) {
        std::cerr << "approve scenario failed" << std::endl;
        return 1;
    }
    std::cout << "approve: written; effects=1" << std::endl;

    InterruptDecision edit;
    edit.action = InterruptAction::Edit;
    edit.arguments = Json::object();
    edit.arguments["text"] = "hello";
    edit.arguments["visibility"] = "private";
    auto edited = build_agent(edit);
    try {
        edited.agent.run(Session{"hitl-edit", {}}, "Write a note.");
    } catch (const PraxoError& error) {
        if (error.code() != "AGENT_POLICY_DENIED" || !edited.tool->notes.empty()) {
            std::cerr << "edit scenario failed: " << error.code() << std::endl;
            return 1;
        }
        std::cout << "edit: policy rejected; effects=0" << std::endl;
        return 0;
    }
    std::cerr << "edited private note was not denied" << std::endl;
    return 1;
}
