module starter;

import core.stdc.stdlib : exit;
import std.stdio : stderr, writeln;
import praxo.agent;
import praxo.errors : PraxoError;
import praxo.hitl : INTERRUPT_APPROVE, INTERRUPT_EDIT, Interrupt,
    InterruptDecision;
import praxo.json : JSONValue, getString;
import praxo.models;

class FixtureModel : Model {
    Response generate(Request request) {
        if (request.messages[$ - 1].role == TOOL) {
            return Response(Message.assistant("done"), Usage());
        }
        return Response(Message.assistant("",
            [ToolCall("write-note-1", "write_note", noteArguments("public"))]),
            Usage());
    }
}

class WriteNoteTool : Tool {
    string[] notes;

    string getName() { return "write_note"; }
    string getDescription() { return "Write a short note with the requested visibility."; }
    JSONValue invoke(JSONValue arguments) {
        notes ~= getString(arguments, "text");
        return JSONValue("written");
    }
}

JSONValue noteArguments(string visibility) {
    JSONValue[string] arguments;
    arguments["text"] = JSONValue("hello");
    arguments["visibility"] = JSONValue(visibility);
    return JSONValue(arguments);
}

Decision authorize(Action action) {
    if (action.kind == "model.generate") return Decision(true);
    if (action.kind == "tool.invoke") {
        return Decision(
            action.toolName == "write_note"
                && getString(action.arguments, "visibility") == "public",
            "only public notes are permitted");
    }
    return Decision(false, "unsupported action");
}

struct HitlResult {
    string output = "";
    string errorCode = "";
    int effects = 0;
}

HitlResult runScenario(string sessionId, InterruptDecision decision) {
    auto tool = new WriteNoteTool();
    auto registry = new Registry();
    registry.register(tool);
    auto options = new AgentOptions(new FixtureModel());
    options.tools = registry;
    options.maxSteps = 3;
    options.allowedTools = ["write_note"];
    options.policy = delegate Decision(Action action) {
        return authorize(action);
    };
    options.interruptOn = ["write_note"];
    options.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        return decision;
    };
    HitlResult result;
    try {
        auto run = runAgent(options, Session(sessionId), "Write a note.");
        result.output = run.output;
    } catch (PraxoError error) {
        result.errorCode = error.code;
    }
    result.effects = cast(int) tool.notes.length;
    return result;
}

HitlResult approveScenario() {
    return runScenario("hitl-approve", InterruptDecision(INTERRUPT_APPROVE));
}

HitlResult editScenario() {
    return runScenario("hitl-edit",
        InterruptDecision(INTERRUPT_EDIT, noteArguments("private")));
}

version (HitlExampleTest) {
} else {
    void main() {
        auto approve = approveScenario();
        if (approve.errorCode.length != 0 || approve.output != "done"
            || approve.effects != 1) {
            stderr.writeln("approve scenario failed: output=", approve.output,
                " effects=", approve.effects, " error=", approve.errorCode);
            exit(1);
        }
        writeln("approve: written; effects=1");

        auto edit = editScenario();
        if (edit.errorCode != "POLICY_ERROR" || edit.effects != 0) {
            stderr.writeln("edit scenario failed: effects=", edit.effects,
                " error=", edit.errorCode);
            exit(1);
        }
        writeln("edit: policy rejected; effects=0");
    }
}
