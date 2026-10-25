package io.axisvela.praxo.model;

import java.util.Map;

public record ToolSpec(
        String name,
        String description,
        Map<String, Object> parameters,
        String risk) {
    public ToolSpec(String name, String description) {
        this(name, description, null, null);
    }
}
