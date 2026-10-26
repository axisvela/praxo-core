module praxo.agent;

import std.algorithm : sort;
import std.array : array, join;
import std.conv : to;
import praxo.errors : PraxoError;
import praxo.json;
import praxo.models;
import praxo.runtime;

interface Model {
    Response generate(Request request);
}

interface Tool {
    string getName();
    string getDescription();
    JSONValue invoke(JSONValue arguments);
}

class FuncTool : Tool {
    private string name;
    private string description;
    private JSONValue delegate(JSONValue) fn;

    this(string name, string description, JSONValue delegate(JSONValue) fn) {
        this.name = name;
        this.description = description;
        this.fn = fn;
    }

    string getName() { return name; }
    string getDescription() { return description; }
    JSONValue invoke(JSONValue arguments) { return fn(arguments); }
}

class Registry {
    private Tool[string] tools;

    void register(Tool tool) {
        tools[tool.getName()] = tool;
    }

    Tool get(string name) {
        if (name !in tools) throw new PraxoError("TOOL_NOT_FOUND", "tool not found: " ~ name);
        return tools[name];
    }

    ToolSpec[] specs() {
        ToolSpec[] result;
        foreach (name, tool; tools) result ~= ToolSpec(tool.getName(), tool.getDescription());
        result.sort!((a, b) => a.name < b.name);
        return result;
    }
}

class StaticModel : Model {
    private string content;

    this(string content) {
        this.content = content;
    }

    Response generate(Request request) {
        return Response(Message.assistant(content), Usage());
    }
}

class AgentOptions {
    Model model;
    Registry tools;
    EventSink events;
    Decision delegate(Action) policy;
    string systemPrompt = "";
    ContextBudget* context;
    long maxSteps = 8;
    long maxTokens = 0;

    this(Model model) {
        this.model = model;
    }
}

class Agent {
    private AgentOptions options;

    this(AgentOptions options) {
        this.options = options;
    }

    RunResult run(Session session, string prompt) {
        auto maxSteps = options.maxSteps > 0 ? options.maxSteps : 8;
        static long runSequence = 0;
        auto runId = "run-" ~ to!string(++runSequence);
        Message[] messages = session.messages.dup;
        if (options.systemPrompt.length > 0) {
            messages = Message.text(SYSTEM, options.systemPrompt) ~ messages;
        }
        messages ~= Message.text(USER, prompt);
        Usage usage;
        emit("run.started", session.id, runId);
        try {
            for (long step = 1; step <= maxSteps; step++) {
                authorize(Action("model.generate", session.id));
                if (options.context !is null) {
                    auto result = compact(*options.context, messages);
                    if (!result.ok) throw new PraxoError("AGENT_CONTEXT_BUDGET", "context budget");
                    messages = result.messages;
                }
                auto request = Request(messages, options.tools is null ? [] : options.tools.specs());
                auto response = options.model.generate(request);
                usage = usage.plus(response.usage);
                if (options.maxTokens > 0 && usage.inputTokens + usage.outputTokens > options.maxTokens) {
                    throw new PraxoError("AGENT_MAX_TOKENS", "token budget");
                }
                messages ~= response.message;
                if (response.message.toolCalls.length == 0) {
                    emit("run.completed", session.id, runId);
                    return RunResult(runId, response.message.content is null ? "" : response.message.content,
                        step, usage);
                }
                foreach (call; response.message.toolCalls) {
                    messages ~= invokeTool(call, runId, session.id);
                }
            }
            throw new PraxoError("AGENT_MAX_STEPS", "maximum steps");
        } catch (Exception error) {
            emit("run.failed", session.id, runId);
            throw error;
        }
    }

    private Message invokeTool(ToolCall call, string runId, string sessionId) {
        authorize(Action("tool.invoke", sessionId, call.name, call.arguments));
        if (options.tools is null) throw new PraxoError("TOOL_NOT_FOUND", "tool is not registered");
        auto tool = options.tools.get(call.name);
        JSONValue[string] data;
        data["name"] = JSONValue(call.name);
        data["arguments"] = call.arguments;
        emit("tool.call", sessionId, runId, JSONValue(data));
        auto value = tool.invoke(call.arguments);
        return Message.tool(stringify(value), call.id);
    }

    private void authorize(Action action) {
        if (options.policy is null) return;
        if (!options.policy(action).allowed) throw new PraxoError("POLICY_ERROR", "policy denied the action");
    }

    private void emit(string type, string sessionId, string runId, JSONValue data = JSONValue.init) {
        if (options.events is null) return;
        options.events.emit(Event(type, sessionId, runId, data));
    }
}

RunResult runAgent(AgentOptions options, Session session, string prompt) {
    return new Agent(options).run(session, prompt);
}
