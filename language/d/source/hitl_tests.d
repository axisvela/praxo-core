module hitl_tests;

import praxo.agent;
import praxo.errors : PraxoError;
import praxo.hitl;
import praxo.json : JSONValue, getString;
import praxo.models;
import praxo.runtime : EventSink;

private void check(bool condition, string message) {
    if (!condition) throw new Error(message);
}

void runHitlTests() {
    auto approveRegistry = new Registry();
    auto approveTool = new HitlRecordingTool();
    approveRegistry.register(approveTool);
    auto approveSink = new TestSink();
    auto approveOptions = new AgentOptions(new HitlToolCallModel());
    approveOptions.tools = approveRegistry;
    approveOptions.events = approveSink;
    approveOptions.interruptOn = ["echo"];
    approveOptions.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        check(interrupt.runId.length > 0, "hitl interrupt run id");
        check(interrupt.sessionId == "hitl-approve", "hitl interrupt session");
        check(interrupt.call.name == "echo", "hitl interrupt tool");
        check(getString(interrupt.call.arguments, "value") == "original",
            "hitl interrupt arguments");
        return InterruptDecision(INTERRUPT_APPROVE);
    };
    auto approveResult = runAgent(approveOptions, Session("hitl-approve"), "go");
    check(approveResult.output == "final" && approveTool.calls.length == 1,
        "hitl approve");
    check(getString(approveTool.calls[0], "value") == "original",
        "hitl approve original arguments");
    check(approveSink.types == ["run.started", "tool.interrupt", "tool.call", "run.completed"],
        "hitl interrupt event");

    auto editRegistry = new Registry();
    auto editTool = new HitlRecordingTool();
    editRegistry.register(editTool);
    Action[] editActions;
    string[] editOrder;
    auto editOptions = new AgentOptions(new HitlToolCallModel());
    editOptions.tools = editRegistry;
    editOptions.interruptOn = ["echo"];
    editOptions.policy = delegate Decision(Action action) {
        if (action.kind == "model.generate") return Decision(true);
        editOrder ~= "policy";
        editActions ~= action;
        return Decision(getString(action.arguments, "value") == "original",
            "only original arguments are permitted");
    };
    editOptions.beforeToolMiddleware = [
        delegate void(ToolCall call, string runId, string sessionId) {
            check(call.name == "echo", "hitl before tool name");
            editOrder ~= "before";
        },
    ];
    editOptions.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        check(interrupt.sessionId == "hitl-edit", "hitl edit session");
        editOrder ~= "interrupt";
        JSONValue[string] arguments;
        arguments["value"] = JSONValue("edited");
        return InterruptDecision(INTERRUPT_EDIT, JSONValue(arguments));
    };
    string editCode;
    try {
        runAgent(editOptions, Session("hitl-edit"), "go");
    } catch (PraxoError error) {
        editCode = error.code;
    }
    check(editCode == "POLICY_ERROR", "hitl edit reauthorization denied");
    check(editTool.calls.length == 0, "hitl edit no effects");
    check(editActions.length == 2, "hitl edit authorizes twice");
    check(getString(editActions[0].arguments, "value") == "original",
        "hitl edit initial arguments");
    check(getString(editActions[1].arguments, "value") == "edited",
        "hitl edit final arguments");
    check(editOrder == ["policy", "before", "interrupt", "policy"],
        "hitl tool preparation order");

    auto rejectRegistry = new Registry();
    auto rejectTool = new HitlRecordingTool();
    rejectRegistry.register(rejectTool);
    auto rejectOptions = new AgentOptions(new HitlToolCallModel());
    rejectOptions.tools = rejectRegistry;
    rejectOptions.interruptOn = ["echo"];
    rejectOptions.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        return InterruptDecision(INTERRUPT_REJECT, JSONValue(null), "", "not allowed");
    };
    string rejectCode;
    try {
        runAgent(rejectOptions, Session("hitl-reject"), "go");
    } catch (PraxoError error) {
        rejectCode = error.code;
    }
    check(rejectCode == "AGENT_APPROVAL_DENIED", "hitl reject code");
    check(rejectTool.calls.length == 0, "hitl reject no effects");

    auto respondRegistry = new Registry();
    auto respondTool = new HitlRecordingTool();
    respondRegistry.register(respondTool);
    auto respondOptions = new AgentOptions(new HitlToolCallModel(true));
    respondOptions.tools = respondRegistry;
    respondOptions.interruptOn = ["echo"];
    respondOptions.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        return InterruptDecision(INTERRUPT_RESPOND, JSONValue(null), "human answer");
    };
    auto respondResult = runAgent(respondOptions, Session("hitl-respond"), "go");
    check(respondResult.output == "\"human answer\"", "hitl respond output");
    check(respondTool.calls.length == 0, "hitl respond no effects");

    auto unhandledRegistry = new Registry();
    auto unhandledTool = new HitlRecordingTool();
    unhandledRegistry.register(unhandledTool);
    auto unhandledOptions = new AgentOptions(new HitlToolCallModel());
    unhandledOptions.tools = unhandledRegistry;
    unhandledOptions.interruptOn = ["echo"];
    string unhandledCode;
    try {
        runAgent(unhandledOptions, Session("hitl-unhandled"), "go");
    } catch (PraxoError error) {
        unhandledCode = error.code;
    }
    check(unhandledCode == "AGENT_INTERRUPT_UNHANDLED", "hitl unhandled code");
    check(unhandledTool.calls.length == 0, "hitl unhandled no effects");

    auto invalidRegistry = new Registry();
    auto invalidTool = new HitlRecordingTool();
    invalidRegistry.register(invalidTool);
    auto invalidOptions = new AgentOptions(new HitlToolCallModel());
    invalidOptions.tools = invalidRegistry;
    invalidOptions.interruptOn = ["echo"];
    invalidOptions.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        return InterruptDecision("invalid");
    };
    string invalidCode;
    try {
        runAgent(invalidOptions, Session("hitl-invalid"), "go");
    } catch (PraxoError error) {
        invalidCode = error.code;
    }
    check(invalidCode == "AGENT_INTERRUPT_DECISION_INVALID", "hitl invalid decision code");
    check(invalidTool.calls.length == 0, "hitl invalid decision no effects");

    auto missingArgumentsRegistry = new Registry();
    auto missingArgumentsTool = new HitlRecordingTool();
    missingArgumentsRegistry.register(missingArgumentsTool);
    auto missingArgumentsOptions = new AgentOptions(new HitlToolCallModel());
    missingArgumentsOptions.tools = missingArgumentsRegistry;
    missingArgumentsOptions.interruptOn = ["echo"];
    missingArgumentsOptions.onInterruptDecision = delegate InterruptDecision(Interrupt interrupt) {
        return InterruptDecision(INTERRUPT_EDIT);
    };
    string missingArgumentsCode;
    try {
        runAgent(missingArgumentsOptions, Session("hitl-missing-arguments"), "go");
    } catch (PraxoError error) {
        missingArgumentsCode = error.code;
    }
    check(missingArgumentsCode == "AGENT_INTERRUPT_DECISION_INVALID",
        "hitl edit requires arguments");
    check(missingArgumentsTool.calls.length == 0, "hitl edit missing arguments no effects");

    auto approvalRegistry = new Registry();
    auto approvalTool = new HitlRecordingTool();
    approvalRegistry.register(approvalTool);
    auto approvalOptions = new AgentOptions(new HitlToolCallModel());
    approvalOptions.tools = approvalRegistry;
    approvalOptions.interruptOn = ["echo"];
    approvalOptions.onInterrupt = delegate bool(Interrupt interrupt) {
        return false;
    };
    string approvalCode;
    try {
        runAgent(approvalOptions, Session("hitl-approval"), "go");
    } catch (PraxoError error) {
        approvalCode = error.code;
    }
    check(approvalCode == "AGENT_APPROVAL_DENIED", "hitl approval denial code");
    check(approvalTool.calls.length == 0, "hitl approval denial no effects");
}

private class TestSink : EventSink {
    string[] types;

    void emit(Event event) { types ~= event.type; }
}

private class HitlRecordingTool : Tool {
    JSONValue[] calls;

    string getName() { return "echo"; }
    string getDescription() { return "Echo"; }
    JSONValue invoke(JSONValue arguments) {
        calls ~= arguments;
        return arguments;
    }
}

private class HitlToolCallModel : Model {
    private bool echoToolResult;
    private bool started = false;

    this(bool echoToolResult = false) {
        this.echoToolResult = echoToolResult;
    }

    Response generate(Request request) {
        if (!started) {
            started = true;
            JSONValue[string] arguments;
            arguments["value"] = JSONValue("original");
            return Response(Message.assistant("",
                [ToolCall("call-1", "echo", JSONValue(arguments))]), Usage());
        }
        if (echoToolResult) {
            for (size_t index = request.messages.length; index > 0; index--) {
                auto message = request.messages[index - 1];
                if (message.role == TOOL) {
                    return Response(Message.assistant(message.content), Usage());
                }
            }
        }
        return Response(Message.assistant("final"), Usage());
    }
}
