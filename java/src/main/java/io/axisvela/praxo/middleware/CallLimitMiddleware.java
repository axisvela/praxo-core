package io.axisvela.praxo.middleware;

import io.axisvela.praxo.PraxoException;

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
        if (result instanceof io.axisvela.praxo.agent.Result value) {
            counts.remove(value.runId);
        }
    }
}
