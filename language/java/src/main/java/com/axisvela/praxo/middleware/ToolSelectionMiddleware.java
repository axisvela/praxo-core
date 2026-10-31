package com.axisvela.praxo.middleware;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.ToolSpec;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class ToolSelectionMiddleware implements Middleware {
    private final ToolSelector selector;
    private final Map<String, Set<String>> selected = new HashMap<>();

    public ToolSelectionMiddleware(ToolSelector selector) {
        this.selector = selector;
    }

    @Override
    public String name() {
        return "tool-selection";
    }

    @Override
    public synchronized void beforeModel(ModelCall call) throws Exception {
        if (call.request == null || selector == null) {
            return;
        }
        List<String> names = selector.select(
                lastUserMessage(call.request.messages()),
                call.request.tools());
        Set<String> chosen = new HashSet<>(names == null ? List.of() : names);
        selected.put(call.runId, chosen);
        List<ToolSpec> filtered = new ArrayList<>();
        for (ToolSpec spec : call.request.tools()) {
            if (chosen.contains(spec.name())) {
                filtered.add(spec);
            }
        }
        call.request = new Request(
                call.request.model(), call.request.messages(), filtered,
                call.request.toolChoice(), call.request.responseFormat(),
                call.request.cacheHint(), call.request.temperature());
    }

    @Override
    public synchronized void beforeTool(MiddlewareToolCall call) {
        Set<String> chosen = selected.get(call.runId);
        if (chosen == null) {
            return;
        }
        if (!chosen.contains(call.call.name())) {
            throw PraxoException.toolNotSelected();
        }
    }

    @Override
    public synchronized void afterRun(Object result, Throwable error) {
        if (result instanceof com.axisvela.praxo.agent.Result value) {
            selected.remove(value.runId);
        }
    }

    static String lastUserMessage(List<Message> messages) {
        for (int index = messages.size() - 1; index >= 0; index--) {
            Message message = messages.get(index);
            if (message.role().equals(Message.USER)) {
                return message.content() == null ? "" : message.content();
            }
        }
        return "";
    }
}
