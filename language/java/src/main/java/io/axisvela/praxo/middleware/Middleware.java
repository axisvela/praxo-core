package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;

import java.util.List;

public interface Middleware {
    default String name() {
        return "";
    }

    default void beforeRun(RunState state) throws Exception {
    }

    default void beforeModel(ModelCall call) throws Exception {
    }

    default void afterModel(ModelCall call, Response response) throws Exception {
    }

    default void beforeTool(MiddlewareToolCall call) throws Exception {
    }

    default void afterTool(MiddlewareToolCall call, ToolResult result)
            throws Exception {
    }

    default void afterRun(Object result, Throwable error) throws Exception {
    }

    static List<Middleware> merge(List<Middleware> items) {
        java.util.List<Middleware> out = new java.util.ArrayList<>();
        java.util.Map<String, Integer> index = new java.util.HashMap<>();
        for (Middleware item : items) {
            if (item.name().isEmpty()) {
                out.add(item);
                continue;
            }
            Integer current = index.get(item.name());
            if (current != null) {
                out.set(current, item);
                continue;
            }
            index.put(item.name(), out.size());
            out.add(item);
        }
        return out;
    }

    @FunctionalInterface
    interface ModelHandler {
        Response handle(Request request) throws Exception;
    }

    @FunctionalInterface
    interface ModelMiddleware {
        ModelHandler apply(ModelHandler next);
    }
}
