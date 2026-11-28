package com.axisvela.praxo.middleware;

import com.axisvela.praxo.PraxoException;

import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.Map;

public final class CallLimitMiddleware implements Middleware {
    private static final class Count {
        int models;
        int tools;
    }

    private final int modelLimit;
    private final int toolLimit;
    private final Map<String, Count> counts = new HashMap<>();
    private final ThreadLocal<ArrayDeque<String>> activeRuns =
            ThreadLocal.withInitial(ArrayDeque::new);

    private void pushRun(String runId) {
        activeRuns.get().push(runId);
    }

    private String popRun() {
        ArrayDeque<String> runs = activeRuns.get();
        if (runs.isEmpty()) {
            return null;
        }
        String runId = runs.pop();
        if (runs.isEmpty()) {
            activeRuns.remove();
        }
        return runId;
    }

    public CallLimitMiddleware(int modelLimit, int toolLimit) {
        this.modelLimit = modelLimit;
        this.toolLimit = toolLimit;
    }

    @Override
    public String name() {
        return "call-limit";
    }

    @Override
    public synchronized void beforeRun(RunState state) {
        pushRun(state.runId());
        counts.put(state.runId(), new Count());
    }

    @Override
    public synchronized void beforeModel(ModelCall call) {
        Count count = counts.computeIfAbsent(call.runId, key -> new Count());
        count.models += 1;
        if (modelLimit > 0 && count.models > modelLimit) {
            throw PraxoException.modelCallLimit();
        }
    }

    @Override
    public synchronized void beforeTool(MiddlewareToolCall call) {
        Count count = counts.computeIfAbsent(call.runId, key -> new Count());
        count.tools += 1;
        if (toolLimit > 0 && count.tools > toolLimit) {
            throw PraxoException.toolCallLimit();
        }
    }

    @Override
    public synchronized void afterRun(Object result, Throwable error) {
        String runId = popRun();
        if (runId == null && result instanceof com.axisvela.praxo.agent.Result value) {
            runId = value.runId;
        }
        if (runId != null) {
            counts.remove(runId);
        }
    }
}
