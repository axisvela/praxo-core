package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;

public final class ModelCall {
    public final String runId;
    public final String sessionId;
    public Request request;
    public boolean skip;
    public Response response;

    public ModelCall(String runId, String sessionId, Request request) {
        this.runId = runId;
        this.sessionId = sessionId;
        this.request = request;
    }
}
