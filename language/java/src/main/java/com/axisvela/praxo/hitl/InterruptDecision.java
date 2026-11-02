package com.axisvela.praxo.hitl;

import java.util.Map;

public final class InterruptDecision {
    public final String action;
    public final Map<String, Object> arguments;
    public final String response;
    public final String reason;

    public InterruptDecision(
            String action,
            Map<String, Object> arguments,
            String response,
            String reason) {
        this.action = action;
        this.arguments = arguments;
        this.response = response == null ? "" : response;
        this.reason = reason == null ? "" : reason;
    }
}
