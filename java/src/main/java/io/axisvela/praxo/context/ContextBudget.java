package io.axisvela.praxo.context;

import io.axisvela.praxo.model.Message;

import java.util.ArrayList;
import java.util.List;

public record ContextBudget(int maxTokens, int keepRecent) {
    public record Result(List<Message> messages, boolean ok) {
    }

    public Result compact(List<Message> messages) {
        if (maxTokens <= 0 || Contexts.estimateTokens(messages) <= maxTokens) {
            return new Result(messages, true);
        }
        List<Message> system = Contexts.systemMessages(messages, false);
        List<Message> rest = Contexts.restMessages(messages);
        if (Contexts.estimateTokens(system) > maxTokens) {
            if (system.isEmpty()) {
                return new Result(List.of(), false);
            }
            Message first = Contexts.withContent(
                    system.get(0),
                    Contexts.truncateToTokens(system.get(0).content(), maxTokens - 4));
            system = List.of(first);
            if (Contexts.estimateTokens(system) > maxTokens) {
                return new Result(List.of(), false);
            }
        }
        int keep = keepRecent > 0 ? keepRecent : 4;
        int start = Math.max(0, rest.size() - keep);
        while (start > 0 && rest.get(start).role().equals(Message.TOOL)) {
            start -= 1;
        }
        Message marker = Message.of(
                Message.SYSTEM,
                Contexts.COMPACT_MARKER_PREFIX + " " + start
                        + " older messages omitted]");
        List<Message> kept = new ArrayList<>(rest.subList(start, rest.size()));
        List<Message> out = build(system, marker, start > 0, kept);
        while (Contexts.estimateTokens(out) > maxTokens && kept.size() > 1) {
            if (kept.get(1).role().equals(Message.TOOL)) {
                break;
            }
            kept = new ArrayList<>(kept.subList(1, kept.size()));
            out = build(system, marker, start > 0, kept);
        }
        if (Contexts.estimateTokens(out) > maxTokens) {
            return new Result(List.of(), false);
        }
        return new Result(out, true);
    }

    private static List<Message> build(
            List<Message> system,
            Message marker,
            boolean includeMarker,
            List<Message> kept) {
        List<Message> out = new ArrayList<>(system);
        if (includeMarker) {
            out.add(marker);
        }
        out.addAll(kept);
        return out;
    }
}
