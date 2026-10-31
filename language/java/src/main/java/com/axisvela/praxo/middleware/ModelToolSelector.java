package com.axisvela.praxo.middleware;

import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class ModelToolSelector implements ToolSelector {
    public static final String DEFAULT_PROMPT =
            "Select the tools needed to answer the user query.\n"
                    + "Return only JSON in the form {\"tools\":[\"tool_name\"]}.\n"
                    + "Prefer the smallest sufficient set. Return {\"tools\":[]} "
                    + "when no tool is needed.";

    private final Model model;
    private final String prompt;
    private final int maxTools;

    public ModelToolSelector(Model model, String prompt, int maxTools) {
        this.model = model;
        this.prompt = prompt == null ? "" : prompt;
        this.maxTools = maxTools;
    }

    @Override
    public List<String> select(String query, List<ToolSpec> tools)
            throws Exception {
        if (model == null) {
            throw new IllegalArgumentException(
                    "agent: tool selector model is required");
        }
        if (tools.isEmpty()) {
            return List.of();
        }
        String systemPrompt = prompt.trim().isEmpty()
                ? DEFAULT_PROMPT : prompt;
        StringBuilder catalog = new StringBuilder();
        for (ToolSpec spec : tools) {
            catalog.append("\n- ").append(spec.name()).append(": ")
                    .append(spec.description());
        }
        List<Message> messages = List.of(
                Message.of(Message.SYSTEM, systemPrompt),
                Message.of(Message.USER,
                        "Query: " + query + "\nAvailable tools:" + catalog));
        Response response = model.generate(Request.of(messages));
        Object parsed;
        try {
            parsed = StructuredOutput.extractJson(
                    response.message().content() == null
                            ? "" : response.message().content());
        } catch (RuntimeException error) {
            throw new IllegalArgumentException(
                    "agent: tool selector response: " + error.getMessage(), error);
        }
        List<String> requested;
        try {
            Object raw = Json.asObject(parsed).get("tools");
            requested = raw == null ? List.of() : Json.strings(raw);
        } catch (RuntimeException error) {
            return List.of();
        }
        Set<String> known = new HashSet<>();
        for (ToolSpec spec : tools) {
            known.add(spec.name());
        }
        Set<String> seen = new HashSet<>();
        List<String> out = new ArrayList<>();
        for (String name : requested) {
            if (!known.contains(name) || !seen.add(name)) {
                continue;
            }
            out.add(name);
            if (maxTools > 0 && out.size() >= maxTools) {
                break;
            }
        }
        return out;
    }
}
