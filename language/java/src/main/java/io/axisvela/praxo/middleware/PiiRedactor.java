package io.axisvela.praxo.middleware;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class PiiRedactor {
    private final List<PiiRule> rules;

    public PiiRedactor(List<PiiRule> rules) {
        this.rules = List.copyOf(rules);
    }

    public static PiiRedactor defaults() {
        return new PiiRedactor(defaultRules());
    }

    public static List<PiiRule> defaultRules() {
        return List.of(
                PiiRule.of("email",
                        "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
                        "[REDACTED:email]"),
                PiiRule.of("ssn", "\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED:ssn]"),
                PiiRule.of("credit_card",
                        "\\b(?:\\d{4}[ -]?){3}\\d{4}\\b",
                        "[REDACTED:credit_card]"),
                PiiRule.of("phone",
                        "\\b(?:\\+?1[-. ]?)?\\(?\\d{3}\\)?[-. ]?\\d{3}[-. ]?\\d{4}\\b",
                        "[REDACTED:phone]"));
    }

    public String redact(String text) {
        String out = text == null ? "" : text;
        for (PiiRule rule : rules) {
            out = rule.pattern().matcher(out)
                    .replaceAll(rule.replacement().isEmpty()
                            ? "[REDACTED]" : rule.replacement());
        }
        return out;
    }

    public Object redactValue(Object value) {
        if (value instanceof String text) {
            return redact(text);
        }
        if (value instanceof byte[] data) {
            return redact(new String(data, java.nio.charset.StandardCharsets.UTF_8));
        }
        if (value instanceof Map<?, ?> map) {
            Map<String, Object> out = new LinkedHashMap<>();
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                out.put(String.valueOf(entry.getKey()),
                        redactValue(entry.getValue()));
            }
            return out;
        }
        if (value instanceof List<?> list) {
            List<Object> out = new ArrayList<>();
            for (Object item : list) {
                out.add(redactValue(item));
            }
            return out;
        }
        return value;
    }
}
