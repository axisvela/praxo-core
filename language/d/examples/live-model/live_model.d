import core.stdc.stdlib : exit;
import std.datetime : Clock;
import std.process : environment;
import std.stdio;
import praxo.agent;
import praxo.json : JSONValue, getString;
import praxo.models;
import praxo.openai_compatible : OpenAICompatibleModel;

class SchemaRegistry : Registry {
    private ToolSpec schemaSpec;

    this(ToolSpec schemaSpec, Tool tool) {
        this.schemaSpec = schemaSpec;
        register(tool);
    }

    override ToolSpec[] specs() {
        return [schemaSpec];
    }
}

string envOr(string name, string fallback) {
    auto value = environment.get(name);
    return value is null || value.length == 0 ? fallback : value;
}

string getTime(JSONValue arguments) {
    auto zone = getString(arguments, "zone");
    auto now = Clock.currTime();
    if (zone == "local") {
        return now.toLocalTime().toISOExtString();
    }
    return now.toUTC().toISOExtString();
}

Decision authorize(Action action) {
    if (action.kind == "model.generate") {
        return Decision(true);
    }
    if (action.kind == "tool.invoke") {
        return Decision(action.toolName == "get_time", "only get_time is permitted");
    }
    return Decision(false, "unsupported action");
}

void main() {
    auto baseUrl = envOr("PRAXO_BASE_URL", "http://localhost:11434/v1");
    auto modelName = envOr("PRAXO_MODEL", "qwen3.5:4b");
    auto apiKey = envOr("PRAXO_API_KEY", "");
    auto prompt = envOr(
        "PRAXO_PROMPT",
        "What time is it? Use get_time with zone set to utc and reply with the time.",
    );

    auto tool = new FuncTool(
        "get_time",
        "Return the current time in ISO 8601 format for the requested zone.",
        (JSONValue arguments) => JSONValue(getTime(arguments)),
    );

    JSONValue[string] zone;
    zone["type"] = JSONValue("string");
    zone["enum"] = JSONValue([JSONValue("utc"), JSONValue("local")]);
    zone["description"] = JSONValue("utc or local; defaults to utc");
    JSONValue[string] properties;
    properties["zone"] = JSONValue(zone);
    JSONValue[string] parameters;
    parameters["type"] = JSONValue("object");
    parameters["properties"] = JSONValue(properties);

    auto registry = new SchemaRegistry(
        ToolSpec("get_time", tool.getDescription(), JSONValue(parameters), "read"),
        tool,
    );

    auto options = new AgentOptions(new OpenAICompatibleModel(baseUrl, modelName, apiKey));
    options.tools = registry;
    options.systemPrompt = "You are a concise assistant. Use the provided tools when they help.";
    options.maxSteps = 4;
    options.allowedTools = ["get_time"];
    options.policy = (Action action) => authorize(action);

    try {
        auto result = runAgent(options, Session("live-model"), prompt);
        writeln(result.output);
    } catch (Exception error) {
        stderr.writeln(
            "live model run failed: ", error.msg, "\n\n",
            "Check PRAXO_BASE_URL (", baseUrl, "), PRAXO_MODEL (", modelName, "), and PRAXO_API_KEY",
        );
        exit(1);
    }
}
