package com.axisvela.praxo.adapters;

import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.util.Json;

import java.util.Map;

public record McpTool(
        String name,
        String description,
        Map<String, Object> inputSchema,
        String title,
        Map<String, Object> annotations) {
    public McpTool {
        description = description == null ? "" : description;
        inputSchema = inputSchema == null ? Map.of() : copy(inputSchema);
        title = title == null ? "" : title;
        annotations = annotations == null ? Map.of() : copy(annotations);
    }

    public ToolSpec toSpec() {
        return new ToolSpec(name, description, copy(inputSchema), null);
    }

    private static Map<String, Object> copy(Map<String, Object> value) {
        return Json.object(Json.stringify(value));
    }
}
