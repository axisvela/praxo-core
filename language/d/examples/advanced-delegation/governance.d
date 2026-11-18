module governance;

import std.json : JSONValue;
import std.stdio : writeln;

import praxo.agent;
import praxo.delegation;
import praxo.errors : PraxoError;
import praxo.hitl : INTERRUPT_EDIT, Interrupt, InterruptDecision;
import praxo.json : getString;
import praxo.models;

class GovState {
    int[string] effects;
    long budget;
    long children;
}

struct RunConfig {
    string[] allowed;
    Decision delegate(Action) policy;
    Tool[] tools;
    long depth;
    long maxDepth = -1;
    long maxChildren = -1;
    bool useBudget;
    bool useChildren;
    bool cancelled;
    bool editToBlocked;
}

class GovModel : Model {
    Response[] steps;

    this(Response[] steps) {
        this.steps = steps;
    }

    override Response generate(Request request) {
        if (steps.length > 0) {
            auto step = steps[0];
            steps = steps[1 .. $];
            return step;
        }
        return Response(Message.assistant("done"), Usage());
    }
}

JSONValue objectWith(string key, string value) {
    JSONValue[string] map;
    map[key] = JSONValue(value);
    return JSONValue(map);
}

string targetOf(Action action) {
    auto target = getString(action.arguments, "target");
    return target is null ? "" : target;
}

Decision permissiveRecord(Action action) {
    if (action.kind == "model.generate") return Decision(true, "");
    if (action.kind == "tool.invoke" && action.toolName == "record") {
        return Decision(true, "");
    }
    return Decision(false, "child may only record");
}

Decision parentBlocked(Action action) {
    if (action.kind == "model.generate") return Decision(true, "");
    if (action.kind != "tool.invoke" || action.toolName != "record") {
        return Decision(false, "parent tool is not allowed");
    }
    if (targetOf(action) == "blocked") return Decision(false, "blocked target");
    return Decision(true, "");
}

Decision composedPolicy(Action action) {
    auto parent = parentBlocked(action);
    if (!parent.allowed) return parent;
    return permissiveRecord(action);
}

SubagentTask deniedTask(string status, string code) {
    SubagentTask task;
    task.id = "subagent";
    task.parentSessionId = "governance-parent";
    task.agentId = "governance-child";
    task.mode = "isolated";
    task.status = status;
    task.error = code;
    return task;
}

Tool[] makeTools(GovState state) {
    auto record = new FuncTool("record", "record", (JSONValue args) {
        auto target = getString(args, "target");
        if (target is null) target = "";
        state.effects[target] = (target in state.effects ? state.effects[target] : 0) + 1;
        return JSONValue("ok");
    });
    auto write = new FuncTool("write", "write", (JSONValue args) {
        auto target = getString(args, "target");
        if (target is null) target = "";
        state.effects[target] = (target in state.effects ? state.effects[target] : 0) + 1;
        return JSONValue("ok");
    });
    return [cast(Tool) record, cast(Tool) write];
}

GovModel modelFor(string tool, string target) {
    return new GovModel([
        Response(Message.assistant("", [
            ToolCall("call-1", tool, objectWith("target", target)),
        ]), Usage()),
        Response(Message.assistant("done"), Usage()),
    ]);
}

SubagentTask runChild(GovState state, Model model, RunConfig config) {
    if (config.cancelled) return deniedTask("cancelled", "CANCELLED");
    if (config.maxDepth >= 0 && config.depth > config.maxDepth) {
        return deniedTask("denied", "DEPTH_LIMIT");
    }
    if (config.maxChildren >= 0 && state.children >= config.maxChildren) {
        return deniedTask("denied", "CHILD_LIMIT");
    }
    if (config.useBudget && state.budget <= 0) {
        return deniedTask("denied", "BUDGET_EXHAUSTED");
    }
    if (config.useChildren) ++state.children;

    auto registry = new Registry();
    foreach (tool; config.tools) registry.register(tool);
    auto options = new AgentOptions(model);
    options.tools = registry;
    options.maxSteps = 3;
    options.allowedTools = config.allowed;
    options.policy = config.policy;
    options.requirePolicy = true;
    options.requireToolScope = true;
    if (config.editToBlocked) {
        options.interruptOn = ["record"];
        options.onInterruptDecision = (Interrupt interrupt) {
            return InterruptDecision(INTERRUPT_EDIT, objectWith("target", "blocked"));
        };
    }
    auto manager = new SubagentManager((SubagentRequest request) {
        auto result = (new Agent(options)).run(Session("governance-child"), "run child");
        return SubagentResult(result.output, "child", "child");
    });
    auto task = manager.run(SubagentRequest("governance-parent", "governance-child", "run child"));
    if (config.useBudget && task.status == "completed") --state.budget;
    return task;
}

void main() {
    auto scopeState = new GovState();
    auto scopeResult = runChild(scopeState, modelFor("write", "escape"), RunConfig(
        ["record"], (Action action) { return permissiveRecord(action); },
        makeTools(scopeState)));
    assert(scopeResult.status == "failed");
    assert(("escape" in scopeState.effects ? scopeState.effects["escape"] : 0) == 0);

    auto policyState = new GovState();
    auto composed = runChild(policyState, modelFor("record", "blocked"), RunConfig(
        ["record"], (Action action) { return composedPolicy(action); },
        makeTools(policyState)));
    assert(composed.status == "failed");
    assert(("blocked" in policyState.effects ? policyState.effects["blocked"] : 0) == 0);

    auto budgetState = new GovState();
    budgetState.budget = 1;
    RunConfig budgetConfig;
    budgetConfig.allowed = ["record"];
    budgetConfig.policy = (Action action) { return permissiveRecord(action); };
    budgetConfig.tools = makeTools(budgetState);
    budgetConfig.useBudget = true;
    auto first = runChild(budgetState, modelFor("record", "sibling"), budgetConfig);
    auto second = runChild(budgetState, modelFor("record", "sibling"), budgetConfig);
    assert(first.status == "completed");
    assert(second.status == "denied");
    assert(second.error == "BUDGET_EXHAUSTED");
    assert(("sibling" in budgetState.effects ? budgetState.effects["sibling"] : 0) == 1);

    auto limitState = new GovState();
    RunConfig limitConfig;
    limitConfig.allowed = ["record"];
    limitConfig.policy = (Action action) { return permissiveRecord(action); };
    limitConfig.tools = makeTools(limitState);
    limitConfig.maxChildren = 1;
    limitConfig.useChildren = true;
    auto firstLimit = runChild(limitState, modelFor("record", "limit"), limitConfig);
    auto secondLimit = runChild(limitState, modelFor("record", "limit"), limitConfig);
    auto deepConfig = limitConfig;
    deepConfig.depth = 2;
    deepConfig.maxDepth = 1;
    auto deep = runChild(limitState, modelFor("record", "limit"), deepConfig);
    assert(firstLimit.status == "completed");
    assert(secondLimit.error == "CHILD_LIMIT");
    assert(deep.error == "DEPTH_LIMIT");
    assert(("limit" in limitState.effects ? limitState.effects["limit"] : 0) == 1);

    auto cancelState = new GovState();
    auto cancelConfig = limitConfig;
    cancelConfig.tools = makeTools(cancelState);
    cancelConfig.cancelled = true;
    auto cancelled = runChild(cancelState, modelFor("record", "cancel"), cancelConfig);
    assert(cancelled.status == "cancelled");
    assert(("cancel" in cancelState.effects ? cancelState.effects["cancel"] : 0) == 0);

    auto editState = new GovState();
    auto editConfig = limitConfig;
    editConfig.tools = makeTools(editState);
    editConfig.policy = (Action action) { return parentBlocked(action); };
    editConfig.editToBlocked = true;
    auto edited = runChild(editState, modelFor("record", "edit-me"), editConfig);
    assert(edited.status == "failed");
    assert(("edit-me" in editState.effects ? editState.effects["edit-me"] : 0) == 0);
    assert(("blocked" in editState.effects ? editState.effects["blocked"] : 0) == 0);

    writeln("D advanced delegation governance: 6/6 passed");
}
