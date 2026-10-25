package io.axisvela.praxo.context;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;

import java.util.ArrayList;
import java.util.List;

public final class ModelSummarizer implements ContextCompactor {
    private final Model model;
    private final String prompt;
    private final int maxSummaryTokens;

    public ModelSummarizer(Model model) {
        this(model, "", 0);
    }

    public ModelSummarizer(Model model, String prompt, int maxSummaryTokens) {
        this.model = model;
        this.prompt = prompt;
        this.maxSummaryTokens = maxSummaryTokens;
    }

    @Override
    public List<Message> compact(List<Message> messages, ContextBudget budget)
            throws Exception {
        if (budget.maxTokens() <= 0
                || Contexts.estimateTokens(messages) <= budget.maxTokens()) {
            return messages;
        }
        if (model == null) {
            return fitBudget(messages, budget);
        }
        List<Message> system = Contexts.systemMessages(messages, true);
        List<Message> rest = Contexts.restMessages(messages);
        int keep = budget.keepRecent() > 0 ? budget.keepRecent() : 4;
        int start = Math.max(0, rest.size() - keep);
        while (start > 0 && rest.get(start).role().equals(Message.TOOL)) {
            start -= 1;
        }
        if (start == 0) {
            return fitBudget(messages, budget);
        }
        String summary = summarize(rest.subList(0, start));
        if (summary == null || summary.trim().isEmpty()) {
            return fitBudget(messages, budget);
        }
        int maxSummary = maxSummaryTokens > 0
                ? maxSummaryTokens
                : budget.maxTokens() / 4;
        String trimmed = Contexts.truncateToTokens(summary.trim(), maxSummary);
        List<Message> out = new ArrayList<>(system);
        out.add(Message.of(
                Message.SYSTEM,
                Contexts.SUMMARY_MARKER_PREFIX + " " + trimmed + "]"));
        out.addAll(rest.subList(start, rest.size()));
        return fitBudget(out, budget);
    }

    private String summarize(List<Message> messages) {
        String systemPrompt = prompt == null || prompt.trim().isEmpty()
                ? Contexts.DEFAULT_SUMMARY_PROMPT
                : prompt;
        List<Message> requestMessages = new ArrayList<>();
        requestMessages.add(Message.of(Message.SYSTEM, systemPrompt));
        requestMessages.addAll(messages);
        try {
            Response response = model.generate(Request.of(requestMessages));
            return response.message().content();
        } catch (Exception error) {
            return "";
        }
    }

    private static List<Message> fitBudget(
            List<Message> messages, ContextBudget budget) {
        ContextBudget.Result result = budget.compact(messages);
        if (!result.ok()) {
            throw PraxoException.contextBudget();
        }
        return result.messages();
    }
}
