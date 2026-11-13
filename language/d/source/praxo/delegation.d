module praxo.delegation;

import std.conv : to;
import std.datetime : Clock, UTC;
import std.json : JSONValue;

import praxo.errors : PraxoError, errorCode;
import praxo.models : Message, Usage;

struct SubagentRequest {
    string parentSessionId;
    string agentId;
    string prompt;
    JSONValue context;
    string mode = "isolated";
    Message[] history;

    this(string parentSessionId, string agentId, string prompt,
         JSONValue context = JSONValue.init, string mode = "isolated",
         Message[] history = []) {
        this.parentSessionId = parentSessionId;
        this.agentId = agentId;
        this.prompt = prompt;
        this.context = context;
        this.mode = mode;
        this.history = history;
    }
}

struct SubagentResult {
    string taskId = "";
    string agentId = "";
    string output = "";
    Usage usage;

    this(string output, string taskId = "", string agentId = "",
         Usage usage = Usage.init) {
        this.taskId = taskId;
        this.agentId = agentId;
        this.output = output;
        this.usage = usage;
    }
}

struct SubagentTask {
    string id = "";
    string parentSessionId = "";
    string agentId = "";
    string mode = "isolated";
    string status = "running";
    string output = "";
    string error = "";
    string createdAt;
    string updatedAt;
}

alias SubagentRunner = SubagentResult delegate(SubagentRequest request);

alias SubagentClock = string delegate();

private string defaultSubagentClock() {
    return Clock.currTime(UTC()).toISOString();
}

class SubagentManager {
    SubagentRunner runner;
    SubagentClock clock;

    this(SubagentRunner runner, SubagentClock clock = null) {
        this.runner = runner;
        this.clock = clock;
    }

    SubagentTask run(SubagentRequest request) {
        if (runner is null) {
            throw new PraxoError("SUBAGENT_INVALID",
                "agent: subagent runner is required");
        }
        if (request.parentSessionId.length == 0 || request.agentId.length == 0) {
            throw new PraxoError("SUBAGENT_INVALID",
                "agent: subagent parent session and agent id are required");
        }
        static long sequence = 0;
        auto stamp = clock is null ? defaultSubagentClock() : clock();
        SubagentTask task;
        task.id = "subagent-" ~ (++sequence).to!string;
        task.parentSessionId = request.parentSessionId;
        task.agentId = request.agentId;
        task.mode = request.mode == "fork" ? "fork" : "isolated";
        task.status = "running";
        task.output = "";
        task.error = "";
        task.createdAt = stamp;
        task.updatedAt = stamp;
        try {
            auto result = runner(request);
            task.status = "completed";
            task.output = result.output;
        } catch (Exception error) {
            task.status = "failed";
            auto code = errorCode(error);
            task.error = code.length > 0 ? code : "SUBAGENT_ERROR";
        }
        task.updatedAt = clock is null ? defaultSubagentClock() : clock();
        return task;
    }
}

SubagentTask runSubagent(SubagentRunner runner, SubagentRequest request, SubagentClock clock = null) {
    return (new SubagentManager(runner, clock)).run(request);
}
