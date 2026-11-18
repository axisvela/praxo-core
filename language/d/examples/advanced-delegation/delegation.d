module delegation;

import std.json : JSONValue;
import std.stdio : writeln;

import praxo.agent;
import praxo.delegation;
import praxo.errors : PraxoError;
import praxo.json : getString;
import praxo.models;

class DemoState {
    int[string] effects;
    long childCalls;
}

class DemoModel : Model {
    Response[] steps;
    string finalContent;
    void delegate() onCall;

    this(Response[] steps, string finalContent, void delegate() onCall = null) {
        this.steps = steps;
        this.finalContent = finalContent;
        this.onCall = onCall;
    }

    override Response generate(Request request) {
        if (onCall !is null) onCall();
        if (steps.length > 0) {
            auto step = steps[0];
            steps = steps[1 .. $];
            return step;
        }
        return Response(Message.assistant(finalContent), Usage());
    }
}

JSONValue objectWith(string key, string value) {
    JSONValue[string] map;
    map[key] = JSONValue(value);
    return JSONValue(map);
}

ToolCall recordCall(string id, string target) {
    return ToolCall(id, "record", objectWith("target", target));
}

Response toolResponse(ToolCall call) {
    return Response(Message.assistant("", [call]), Usage());
}

Decision parentPolicy(Action action) {
    if (action.kind == "model.generate") return Decision(true, "");
    if (action.kind == "tool.invoke" && action.toolName == "delegate") {
        return Decision(true, "");
    }
    return Decision(false, "parent may only delegate");
}

Decision childPolicy(Action action) {
    if (action.kind == "model.generate") return Decision(true, "");
    if (action.kind == "tool.invoke" && action.toolName == "record") {
        return Decision(true, "");
    }
    return Decision(false, "child may only record");
}

void main() {
    auto state = new DemoState();
    auto record = new FuncTool("record", "Record a target in an in-memory counter",
        (JSONValue args) {
            auto target = getString(args, "target");
            if (target is null) target = "";
            state.effects[target] = (target in state.effects ? state.effects[target] : 0) + 1;
            return JSONValue("recorded:" ~ target);
        });
    auto childModel = new DemoModel([
        toolResponse(recordCall("child-record", "child")),
    ], "child done", () { ++state.childCalls; });
    auto delegateTool = new FuncTool("delegate",
        "Run a child agent with a narrowed record scope",
        (JSONValue args) {
            auto registry = new Registry();
            registry.register(record);
            auto options = new AgentOptions(childModel);
            options.tools = registry;
            options.maxSteps = 3;
            options.allowedTools = ["record"];
            options.policy = (Action action) { return childPolicy(action); };
            options.requirePolicy = true;
            options.requireToolScope = true;
            auto result = (new Agent(options)).run(Session("demo-child"), "record child");
            return JSONValue(result.output);
        });
    auto parentModel = new DemoModel([
        toolResponse(ToolCall("parent-delegate", "delegate", objectWith("task", "record child"))),
    ], "parent done");
    auto registry = new Registry();
    registry.register(record);
    registry.register(delegateTool);
    auto options = new AgentOptions(parentModel);
    options.tools = registry;
    options.allowedTools = ["delegate"];
    options.policy = (Action action) { return parentPolicy(action); };
    options.requirePolicy = true;
    options.requireToolScope = true;
    auto result = (new Agent(options)).run(Session("demo-parent"), "delegate");
    writeln("delegation: child recorded; parent scope enforced");

    auto directModel = new DemoModel([
        toolResponse(recordCall("direct-record", "child")),
    ], "parent done");
    auto directOptions = new AgentOptions(directModel);
    directOptions.tools = registry;
    directOptions.allowedTools = ["delegate"];
    directOptions.policy = (Action action) { return parentPolicy(action); };
    directOptions.requirePolicy = true;
    directOptions.requireToolScope = true;
    bool denied = false;
    try {
        (new Agent(directOptions)).run(Session("demo-direct"), "record directly");
    } catch (PraxoError) {
        denied = true;
    }
    writeln("deny: parent record blocked; child effect unchanged");
    assert(result.output == "parent done");
    assert(("child" in state.effects ? state.effects["child"] : 0) == 1);
    assert(denied);
}
