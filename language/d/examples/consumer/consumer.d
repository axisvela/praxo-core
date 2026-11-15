import core.stdc.stdlib : exit;
import std.stdio;
import praxo.agent;
import praxo.errors : PraxoError;
import praxo.json : JSONValue, getString;
import praxo.models;

class FixtureModel : Model {
    private string target;

    this(string target) {
        this.target = target;
    }

    Response generate(Request request) {
        auto last = request.messages[$ - 1];
        if (last.role == TOOL) {
            return Response(Message.assistant("recorded"), Usage());
        }
        JSONValue[string] arguments;
        arguments["target"] = JSONValue(target);
        ToolCall[] calls = [ToolCall("record-1", "record", JSONValue(arguments))];
        return Response(Message.assistant("", calls), Usage());
    }
}

class RecordTool : Tool {
    int calls = 0;

    string getName() {
        return "record";
    }

    string getDescription() {
        return "Record a target in an in-memory counter.";
    }

    JSONValue invoke(JSONValue arguments) {
        calls++;
        return JSONValue("recorded");
    }
}

Decision authorize(Action action) {
    if (action.kind == "model.generate") {
        return Decision(true);
    }
    if (action.kind == "tool.invoke") {
        auto target = getString(action.arguments, "target");
        return Decision(
            action.toolName == "record" && target == "public",
            "only the public target is permitted",
        );
    }
    return Decision(false, "unsupported action");
}

RunResult runScenario(string target, out int effects) {
    auto tool = new RecordTool();
    auto registry = new Registry();
    registry.register(tool);
    auto options = new AgentOptions(new FixtureModel(target));
    options.tools = registry;
    options.maxSteps = 3;
    options.allowedTools = ["record"];
    options.policy = (Action action) => authorize(action);
    auto result = runAgent(options, Session("consumer-" ~ target), "Record the requested target.");
    effects = tool.calls;
    return result;
}

void main() {
    int effects;
    auto allowed = runScenario("public", effects);
    if (allowed.output != "recorded" || effects != 1) {
        stderr.writeln("allow verification failed: output=", allowed.output, " effects=", effects);
        exit(1);
    }
    writeln("allow: recorded; effects=1");

    effects = 0;
    bool denied = false;
    try {
        runScenario("private", effects);
    } catch (PraxoError error) {
        denied = error.code == "POLICY_ERROR";
    }
    if (!denied || effects != 0) {
        stderr.writeln("deny verification failed: effects=", effects);
        exit(1);
    }
    writeln("deny: policy rejected; effects=0");
}
