package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.ToolCall;

public final class MiddlewareToolCall {
    public final String runId;
    public final String sessionId;
    public ToolCall call;
    public boolean skip;
    public Object result;
    public Throwable error;

    public MiddlewareToolCall(String runId, String sessionId, ToolCall call) {
        this.runId = runId;
        this.sessionId = sessionId;
        this.call = call;
    }
}
