module chain;

import core.time : Duration, seconds;
import std.json : JSONType, JSONValue;
import std.stdio : writeln;

import praxo.agent;
import praxo.errors : PraxoError;
import praxo.harmovela;
import praxo.hitl;
import praxo.json : get, getArray, getString, parse;
import praxo.mcp;
import praxo.models;
import praxo.otel;
import praxo.runtime;

class ChainState {
    int[string] effects;
    string[] otel;
    string[] harmovela;
    long childCalls;
}

class ChainModel : Model {
    Response[] steps;
    string finalContent;
    long calls;
    void delegate() onCall;

    this(Response[] steps, string finalContent, void delegate() onCall = null) {
        this.steps = steps;
        this.finalContent = finalContent;
        this.onCall = onCall;
    }

    override Response generate(Request request) {
        ++calls;
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
    if (action.kind != "tool.invoke") return Decision(false, "unsupported action");
    if (action.toolName == "record") {
        auto target = getString(action.arguments, "target");
        if (target == "blocked") return Decision(false, "blocked target");
        return Decision(true, "");
    }
    if (action.toolName == "delegate") return Decision(true, "");
    return Decision(false, "parent tool is not allowed");
}

Decision childPolicy(Action action) {
    if (action.kind == "model.generate") return Decision(true, "");
    if (action.kind == "tool.invoke" && action.toolName == "record") {
        return Decision(true, "");
    }
    return Decision(false, "child may only record");
}

Decision composedPolicy(Action action) {
    auto parent = parentPolicy(action);
    if (!parent.allowed) return parent;
    return childPolicy(action);
}

class RecordTransport : McpTransport {
    ChainState state;

    this(ChainState state) {
        this.state = state;
    }

    override JSONValue request(string method, JSONValue params, Duration timeout) {
        if (method == "initialize") {
            JSONValue[string] result;
            result["protocolVersion"] = JSONValue("2024-11-05");
            result["serverInfo"] = objectWith("name", "fake-mcp");
            return JSONValue(result);
        }
        if (method == "tools/list") {
            JSONValue[string] schema;
            schema["type"] = JSONValue("object");
            JSONValue[string] properties;
            properties["target"] = objectWith("type", "string");
            schema["properties"] = JSONValue(properties);
            schema["required"] = JSONValue([JSONValue("target")]);
            JSONValue[string] tool;
            tool["name"] = JSONValue("record");
            tool["description"] = JSONValue("Record a target");
            tool["inputSchema"] = JSONValue(schema);
            JSONValue[string] result;
            result["tools"] = JSONValue([JSONValue(tool)]);
            return JSONValue(result);
        }
        if (method == "tools/call") {
            auto arguments = get(params, "arguments");
            auto target = getString(arguments, "target");
            if (target is null) target = "";
            state.effects[target] = (target in state.effects ? state.effects[target] : 0) + 1;
            JSONValue[string] text;
            text["type"] = JSONValue("text");
            text["text"] = JSONValue("recorded:" ~ target);
            JSONValue[string] result;
            result["content"] = JSONValue([JSONValue(text)]);
            return JSONValue(result);
        }
        return JSONValue(null);
    }

    override void notify(string method, JSONValue params) {}
    override void close() {}
}

void main() {
    auto state = new ChainState();
    auto client = new McpClient(new RecordTransport(state));
    client.start();
    auto tools = client.listTools();
    assert(tools.length == 1);

    auto record = new FuncTool("record", "Record a target through the MCP client",
        (JSONValue arguments) {
            return client.callTool("record", arguments);
        });

    auto otel = new OtelSink("http://otel.local/v1/traces", "praxo-core", [],
        (string endpoint, string body, string[string] headers) {
            auto payload = parse(body);
            foreach (resource; getArray(payload, "resourceSpans")) {
                foreach (scopeSpan; getArray(resource, "scopeSpans")) {
                    foreach (span; getArray(scopeSpan, "spans")) {
                        auto name = getString(span, "name");
                        state.otel ~= name is null ? "" : name;
                    }
                }
            }
            return OtelResponse(200, "");
        });
    auto harmovela = new HarmovelaSink("http://harmovela.local", "praxo-core", "0.2",
        (string baseUrl, string path, string body, string[string] headers) {
            auto payload = parse(body);
            auto kind = getString(payload, "type");
            state.harmovela ~= kind is null ? "" : kind;
            return HarmovelaResponse(202, "");
        });
    auto events = new MultiSink([cast(EventSink) otel, cast(EventSink) harmovela]);

    auto delegateTool = new FuncTool("delegate",
        "Run a governed child agent with the narrowed record scope",
        (JSONValue arguments) {
            auto childModel = new ChainModel([
                toolResponse(recordCall("child-record", "child")),
            ], "DONE", () { ++state.childCalls; });
            auto registry = new Registry();
            registry.register(record);
            auto options = new AgentOptions(childModel);
            options.tools = registry;
            options.maxSteps = 3;
            options.allowedTools = ["record"];
            options.policy = (Action action) { return composedPolicy(action); };
            options.requirePolicy = true;
            options.requireToolScope = true;
            options.events = events;
            auto result = (new Agent(options)).run(Session("chain-child"), "record child");
            return objectWith("output", result.output);
        });

    auto parentModel = new ChainModel([
        toolResponse(recordCall("parent-record", "parent")),
        toolResponse(ToolCall("parent-delegate", "delegate", objectWith("task", "record child"))),
    ], "DONE");
    auto registry = new Registry();
    registry.register(record);
    registry.register(delegateTool);
    auto options = new AgentOptions(parentModel);
    options.tools = registry;
    options.maxSteps = 4;
    options.allowedTools = ["record", "delegate"];
    options.policy = (Action action) { return parentPolicy(action); };
    options.requirePolicy = true;
    options.requireToolScope = true;
    options.events = events;
    auto parent = (new Agent(options)).run(Session("chain-parent"),
        "record parent, then delegate");

    auto deniedModel = new ChainModel([
        toolResponse(recordCall("denied-record", "edit-me")),
    ], "DONE");
    auto deniedRegistry = new Registry();
    deniedRegistry.register(record);
    auto deniedOptions = new AgentOptions(deniedModel);
    deniedOptions.tools = deniedRegistry;
    deniedOptions.maxSteps = 2;
    deniedOptions.allowedTools = ["record"];
    deniedOptions.policy = (Action action) { return parentPolicy(action); };
    deniedOptions.requirePolicy = true;
    deniedOptions.requireToolScope = true;
    deniedOptions.events = events;
    deniedOptions.interruptOn = ["record"];
    deniedOptions.onInterruptDecision = (Interrupt interrupt) {
        return InterruptDecision(INTERRUPT_EDIT, objectWith("target", "blocked"));
    };
    string deniedError = "";
    try {
        (new Agent(deniedOptions)).run(Session("chain-denied"), "attempt a denied edit");
    } catch (PraxoError error) {
        deniedError = error.code;
    }

    client.close();
    writeln("output: ", parent.output);
    writeln("effects: parent=", ("parent" in state.effects ? state.effects["parent"] : 0),
        " child=", ("child" in state.effects ? state.effects["child"] : 0));
    writeln("child calls: ", state.childCalls);
    writeln("otel spans: ", state.otel.length);
    writeln("harmovela events: ", state.harmovela.length);
    writeln("denied effects: ", ("blocked" in state.effects ? state.effects["blocked"] : 0));
    assert(parent.output == "DONE");
    assert(("parent" in state.effects ? state.effects["parent"] : 0) == 1);
    assert(("child" in state.effects ? state.effects["child"] : 0) == 1);
    assert(state.childCalls == 2);
    assert(state.otel.length >= 3);
    assert(state.harmovela.length >= 3);
    assert(("blocked" in state.effects ? state.effects["blocked"] : 0) == 0);
    assert(deniedError.length > 0);
}
