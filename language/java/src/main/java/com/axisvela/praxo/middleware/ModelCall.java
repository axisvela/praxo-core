package com.axisvela.praxo.middleware;

import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;

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
