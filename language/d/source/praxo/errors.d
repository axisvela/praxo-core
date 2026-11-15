module praxo.errors;

class PraxoError : Exception {
    string code;

    this(string code, string message) {
        super(message);
        this.code = code;
    }
}

class ApprovalDeniedError : PraxoError {
    this(string message) {
        super("AGENT_APPROVAL_DENIED", message);
    }
}

class InterruptUnhandledError : PraxoError {
    this(string message) {
        super("AGENT_INTERRUPT_UNHANDLED", message);
    }
}

class InterruptDecisionInvalidError : PraxoError {
    this(string message) {
        super("AGENT_INTERRUPT_DECISION_INVALID", message);
    }
}

string errorCode(Throwable error) {
    auto praxo = cast(PraxoError) error;
    return praxo is null ? "" : praxo.code;
}
