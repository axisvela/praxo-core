module praxo.agent;

import std.algorithm : canFind, sort;
import std.array : array, join;
import std.conv : to;
import praxo.errors : ApprovalDeniedError, InterruptDecisionInvalidError,
    InterruptUnhandledError, PraxoError;
import praxo.hitl : INTERRUPT_APPROVE, INTERRUPT_EDIT, INTERRUPT_REJECT,
    INTERRUPT_RESPOND, Interrupt, InterruptApproval, InterruptHandler;
import praxo.json;
import praxo.models;
import praxo.runtime;

interface Model {
    Response generate(Request request);
}

interface StreamingModel : Model {
    Response generateStream(Request request, void delegate(string) onDelta);
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

alias BeforeToolHandler = void delegate(ToolCall call, string runId, string sessionId);

class AgentOptions {
    Model model;
    Registry tools;
    EventSink events;
    Decision delegate(Action) policy;
    string systemPrompt = "";
    ContextBudget* context;
    long maxSteps = 8;
    long maxTokens = 0;
    string[] allowedTools;
    string[] interruptOn;
    InterruptHandler onInterruptDecision;
    InterruptApproval onInterrupt;
    BeforeToolHandler[] beforeToolMiddleware;
    void delegate(string) onDelta;
    bool requirePolicy = false;
    bool requireToolScope = false;

    this(Model model) {
        this.model = model;
    }
}

private struct InterruptOutcome {
    bool skip;
    bool edited;
    string response;
}

class Agent {
    private AgentOptions options;

    this(AgentOptions options) {
        if (options.requirePolicy && options.policy is null) {
            throw new PraxoError("AGENT_INVALID_OPTIONS",
                "agent: require policy: policy is required");
        }
        if (options.requireToolScope && options.allowedTools.length == 0) {
            throw new PraxoError("AGENT_INVALID_OPTIONS",
                "agent: require tool scope: allowedTools must not be empty");
        }
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
                auto request = Request(messages, advertisedTools());
                Response response;
                if (options.onDelta is null) {
                    response = options.model.generate(request);
                } else {
                    auto streaming = cast(StreamingModel) options.model;
                    if (streaming is null) {
                        throw new PraxoError("AGENT_STREAM",
                            "agent: model does not support streaming");
                    }
                    response = streaming.generateStream(request, options.onDelta);
                }
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
        auto originalName = call.name;
        auto originalArguments = call.arguments;
        if (options.allowedTools.length > 0 && !options.allowedTools.canFind(originalName)) {
            throw new PraxoError("AGENT_TOOL_NOT_ALLOWED", "tool not allowed");
        }
        authorize(Action("tool.invoke", sessionId, originalName, originalArguments));
        foreach (handler; options.beforeToolMiddleware) handler(call, runId, sessionId);
        auto active = call;
        auto outcome = applyInterrupt(active, runId, sessionId);
        if (outcome.skip) return Message.tool(stringify(JSONValue(outcome.response)), active.id);
        if (options.allowedTools.length > 0 && !options.allowedTools.canFind(active.name)) {
            throw new PraxoError("AGENT_TOOL_NOT_ALLOWED", "tool not allowed");
        }
        if (outcome.edited || active.name != originalName
            || !equals(active.arguments, originalArguments)) {
            authorize(Action("tool.invoke", sessionId, active.name, active.arguments));
        }
        if (options.tools is null) throw new PraxoError("TOOL_NOT_FOUND", "tool is not registered");
        auto tool = options.tools.get(active.name);
        JSONValue[string] data;
        data["name"] = JSONValue(active.name);
        data["arguments"] = active.arguments;
        emit("tool.call", sessionId, runId, JSONValue(data));
        auto value = tool.invoke(active.arguments);
        return Message.tool(stringify(value), active.id);
    }

    private InterruptOutcome applyInterrupt(ref ToolCall call, string runId, string sessionId) {
        InterruptOutcome outcome;
        if (!options.interruptOn.canFind(call.name)) return outcome;
        if (options.onInterruptDecision is null && options.onInterrupt is null) {
            throw new InterruptUnhandledError(
                "agent: approval handler not configured: " ~ call.name);
        }
        JSONValue[string] data;
        data["name"] = JSONValue(call.name);
        data["arguments"] = call.arguments;
        emit("tool.interrupt", sessionId, runId, JSONValue(data));
        auto interrupt = Interrupt(runId, sessionId, call);
        if (options.onInterruptDecision !is null) {
            auto decision = options.onInterruptDecision(interrupt);
            if (decision.action == INTERRUPT_APPROVE) return outcome;
            if (decision.action == INTERRUPT_EDIT) {
                if (decision.arguments.type == JSONType.null_) {
                    throw new InterruptDecisionInvalidError("agent: edit requires arguments");
                }
                call.arguments = decision.arguments;
                outcome.edited = true;
                return outcome;
            }
            if (decision.action == INTERRUPT_REJECT) {
                throw new ApprovalDeniedError(
                    "agent: tool call denied by approval: " ~ call.name ~ ": "
                    ~ decision.reason);
            }
            if (decision.action == INTERRUPT_RESPOND) {
                outcome.skip = true;
                outcome.response = decision.response;
                return outcome;
            }
            throw new InterruptDecisionInvalidError(
                "agent: invalid interrupt decision: " ~ decision.action);
        }
        if (!options.onInterrupt(interrupt)) {
            throw new ApprovalDeniedError(
                "agent: tool call denied by approval: " ~ call.name);
        }
        return outcome;
    }

    private ToolSpec[] advertisedTools() {
        if (options.tools is null) return [];
        auto specs = options.tools.specs();
        if (options.allowedTools.length == 0) return specs;
        ToolSpec[] filtered;
        foreach (spec; specs) {
            if (options.allowedTools.canFind(spec.name)) filtered ~= spec;
        }
        return filtered;
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
