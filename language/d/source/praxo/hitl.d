module praxo.hitl;

import praxo.json : JSONValue;
import praxo.models : ToolCall;

enum string INTERRUPT_APPROVE = "approve";
enum string INTERRUPT_EDIT = "edit";
enum string INTERRUPT_REJECT = "reject";
enum string INTERRUPT_RESPOND = "respond";

struct Interrupt {
    string runId;
    string sessionId;
    ToolCall call;

    this(string runId, string sessionId, ToolCall call) {
        this.runId = runId;
        this.sessionId = sessionId;
        this.call = call;
    }
}

struct InterruptDecision {
    string action;
    JSONValue arguments;
    string response = "";
    string reason = "";

    this(string action, JSONValue arguments = JSONValue(null),
         string response = "", string reason = "") {
        this.action = action;
        this.arguments = arguments;
        this.response = response;
        this.reason = reason;
    }
}

alias InterruptHandler = InterruptDecision delegate(Interrupt interrupt);
alias InterruptApproval = bool delegate(Interrupt interrupt);
