package com.axisvela.praxo.hitl;

import com.axisvela.praxo.model.ToolCall;

public final class Interrupt {
    public final String runId;
    public final String sessionId;
    public final ToolCall call;

    public Interrupt(String runId, String sessionId, ToolCall call) {
        this.runId = runId;
        this.sessionId = sessionId;
        this.call = call;
    }
}
