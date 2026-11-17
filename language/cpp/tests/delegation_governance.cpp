#include "praxo/agent.hpp"
#include "praxo/delegation.hpp"
#include "praxo/errors.hpp"

#include <algorithm>
#include <cassert>
#include <functional>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

using namespace praxo;

namespace {

struct EffectLog {
    int count = 0;
};

struct ToolScope {
    std::vector<std::string> tools;
};

struct ChildHarness {
    std::string tool = "read";
    Json arguments = Json::parse(R"({"target":"safe"})");
    std::string mutate_key;
    std::string mutate_to;
    std::string deny_key;
    std::string deny_value;
    int* budget = nullptr;
    EffectLog* effects = nullptr;
    bool* cancel_source = nullptr;
    bool cancel_after_generate = false;
    int generate_calls = 0;
    int invoke_calls = 0;
    int policy_calls = 0;
    std::string output;
};

class ScriptedModel : public Model {
public:
    explicit ScriptedModel(ChildHarness& harness) : harness_(harness) {}

    Response generate(const Request& request) override {
        (void)request;
        harness_.generate_calls++;
        Response response;
        if (harness_.generate_calls == 1) {
            ToolCall call;
            call.id = "call-1";
            call.name = harness_.tool;
            call.arguments = harness_.arguments;
            response.message = assistant_message("", {call});
        } else {
            response.message = assistant_message("done");
        }
        return response;
    }

private:
    ChildHarness& harness_;
};

struct GovNode {
    std::vector<std::string> delegable;
    int depth = 0;
    int max_depth = 2;
    int active_children = 0;
    int max_children = 2;
    int budget_remaining = 1;
    bool cancelled = false;
};

GovNode make_gov(std::vector<std::string> delegable, int max_depth,
                 int max_children, int budget) {
    GovNode node;
    node.delegable = std::move(delegable);
    node.max_depth = max_depth;
    node.max_children = max_children;
    node.budget_remaining = budget;
    return node;
}

std::string run_child_agent(ChildHarness& harness, const ToolScope& scope) {
    auto registry = std::make_shared<ToolRegistry>();
    registry->register_tool(std::make_shared<FuncTool>(
        harness.tool, "test tool", [&harness](const Json&) -> Json {
            harness.invoke_calls++;
            if (harness.budget != nullptr) {
                if (*harness.budget <= 0) return Json("BUDGET_EXHAUSTED");
                (*harness.budget)--;
            }
            if (harness.effects != nullptr) harness.effects->count++;
            return Json("ok");
        }));
    AgentOptions options(std::make_shared<ScriptedModel>(harness));
    options.tools = registry;
    options.max_steps = 2;
    options.allowed_tools = scope.tools;
    options.require_tool_scope = true;
    options.require_policy = true;
    options.policy = [&harness](const Action& action) {
        if (action.kind != "tool.invoke") return Decision{true, "ok"};
        harness.policy_calls++;
        if (!harness.deny_key.empty() && action.arguments.is_object()) {
            const Json& value = action.arguments.at(harness.deny_key);
            if (value.is_string() && value.as_string() == harness.deny_value) {
                return Decision{false, "denied"};
            }
        }
        return Decision{true, "ok"};
    };
    if (!harness.mutate_key.empty()) {
        Middleware middleware;
        middleware.before_tool = [&harness](ToolCall call) {
            Json next = Json::object();
            next[harness.mutate_key] = harness.mutate_to;
            call.arguments = next;
            return call;
        };
        options.middleware.push_back(middleware);
    }
    options.cancellation = [&harness]() {
        if (harness.cancel_source != nullptr && *harness.cancel_source) {
            return true;
        }
        return harness.cancel_after_generate && harness.generate_calls > 0;
    };
    try {
        Agent agent(std::move(options));
        const RunResult result = agent.run(Session{"child-session", {}}, "go");
        harness.output = result.output;
        return "";
    } catch (const PraxoError& error) {
        return error.code();
    } catch (const std::exception& error) {
        return error.what();
    }
}

using ChildRun = std::function<std::string()>;

std::string gov_delegate(GovNode& parent, const ToolScope& child_scope,
                         const ChildRun& run) {
    if (parent.depth + 1 > parent.max_depth) {
        return "DELEGATION_DEPTH_EXCEEDED";
    }
    if (parent.active_children >= parent.max_children) {
        return "DELEGATION_CHILDREN_EXCEEDED";
    }
    for (const auto& tool : child_scope.tools) {
        if (std::find(parent.delegable.begin(), parent.delegable.end(), tool) ==
            parent.delegable.end()) {
            return "DELEGATION_SCOPE_EXCEEDED";
        }
    }
    if (parent.budget_remaining <= 0) {
        return "DELEGATION_BUDGET_EXHAUSTED";
    }
    parent.active_children++;
    std::string run_error;
    SubagentRequest request;
    request.parent_session_id = "parent";
    request.agent_id = "child";
    request.prompt = "go";
    const SubagentTask task = subagent_run(
        [&run, &run_error](const SubagentRequest&) -> SubagentResult {
            run_error = run();
            if (!run_error.empty()) {
                throw std::runtime_error(run_error);
            }
            return SubagentResult{"", "", "done", std::nullopt};
        },
        request);
    parent.active_children--;
    if (task.status != "completed") {
        return run_error.empty() ? task.error : run_error;
    }
    return "";
}

void test_tool_scope() {
    EffectLog effects;
    GovNode parent = make_gov({"read"}, 2, 2, 2);
    ToolScope scope{{"read"}};
    ToolScope wide{{"read", "write"}};

    ChildHarness blocked;
    blocked.tool = "write";
    blocked.effects = &effects;
    std::string error = gov_delegate(parent, wide, [&]() {
        return run_child_agent(blocked, wide);
    });
    assert(error == "DELEGATION_SCOPE_EXCEEDED");
    assert(blocked.generate_calls == 0);
    assert(blocked.invoke_calls == 0);
    assert(effects.count == 0);

    ChildHarness allowed;
    allowed.effects = &effects;
    error = gov_delegate(parent, scope, [&]() {
        return run_child_agent(allowed, scope);
    });
    assert(error.empty());
    assert(effects.count == 1);
}

void test_depth_limit() {
    GovNode parent = make_gov({"read"}, 1, 2, 2);
    GovNode child_node = parent;
    child_node.depth = 1;
    ToolScope scope{{"read"}};
    int grandchild_invoked = 0;
    std::string nested_error;

    const std::string error = gov_delegate(parent, scope, [&]() {
        nested_error = gov_delegate(child_node, scope, [&]() {
            grandchild_invoked++;
            return std::string();
        });
        return std::string();
    });
    assert(error.empty());
    assert(nested_error == "DELEGATION_DEPTH_EXCEEDED");
    assert(grandchild_invoked == 0);
}

void test_child_count() {
    GovNode parent = make_gov({"read"}, 2, 1, 2);
    ToolScope scope{{"read"}};
    int attempts = 0;
    int inner_invoked = 0;
    std::string inner_error;
    const ChildRun outer = [&]() {
        attempts++;
        inner_error = gov_delegate(parent, scope, [&]() {
            inner_invoked++;
            return std::string();
        });
        return std::string();
    };

    std::string error = gov_delegate(parent, scope, outer);
    assert(error.empty());
    assert(attempts == 1);
    assert(inner_error == "DELEGATION_CHILDREN_EXCEEDED");
    assert(inner_invoked == 0);
    assert(parent.active_children == 0);

    error = gov_delegate(parent, scope, outer);
    assert(error.empty());
    assert(attempts == 2);
    assert(inner_invoked == 0);
    assert(parent.active_children == 0);
}

void test_sibling_budget() {
    EffectLog effects;
    GovNode parent = make_gov({"read"}, 2, 2, 1);
    ToolScope scope{{"read"}};

    ChildHarness first;
    first.budget = &parent.budget_remaining;
    first.effects = &effects;
    std::string error = gov_delegate(parent, scope, [&]() {
        return run_child_agent(first, scope);
    });
    assert(error.empty());
    assert(effects.count == 1);
    assert(parent.budget_remaining == 0);

    ChildHarness second;
    second.budget = &parent.budget_remaining;
    second.effects = &effects;
    error = gov_delegate(parent, scope, [&]() {
        return run_child_agent(second, scope);
    });
    assert(error == "DELEGATION_BUDGET_EXHAUSTED");
    assert(second.generate_calls == 0);
    assert(second.invoke_calls == 0);
    assert(effects.count == 1);
}

void test_cancellation() {
    EffectLog effects;
    GovNode parent = make_gov({"read"}, 2, 2, 2);
    ToolScope scope{{"read"}};
    parent.cancelled = true;

    ChildHarness cancelled;
    cancelled.cancel_source = &parent.cancelled;
    cancelled.effects = &effects;
    std::string error = gov_delegate(parent, scope, [&]() {
        return run_child_agent(cancelled, scope);
    });
    assert(error == "AGENT_CANCELLED");
    assert(cancelled.generate_calls == 0);
    assert(cancelled.invoke_calls == 0);
    assert(effects.count == 0);

    parent.cancelled = false;
    ChildHarness late;
    late.cancel_after_generate = true;
    late.effects = &effects;
    error = gov_delegate(parent, scope, [&]() {
        return run_child_agent(late, scope);
    });
    assert(error == "AGENT_CANCELLED");
    assert(late.generate_calls == 1);
    assert(late.invoke_calls == 0);
    assert(effects.count == 0);
}

void test_final_arguments() {
    EffectLog effects;
    GovNode parent = make_gov({"read"}, 2, 2, 2);
    ToolScope scope{{"read"}};
    ChildHarness child;
    child.mutate_key = "target";
    child.mutate_to = "secret";
    child.deny_key = "target";
    child.deny_value = "secret";
    child.effects = &effects;

    const std::string error = gov_delegate(parent, scope, [&]() {
        return run_child_agent(child, scope);
    });
    assert(error == "AGENT_POLICY_DENIED");
    assert(child.generate_calls == 1);
    assert(child.invoke_calls == 0);
    assert(child.policy_calls >= 2);
    assert(effects.count == 0);
}

}  // namespace

int main() {
    test_tool_scope();
    test_depth_limit();
    test_child_count();
    test_sibling_budget();
    test_cancellation();
    test_final_arguments();
    return 0;
}
