package com.axisvela.praxo.adapters;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class McpProtocol {
    private McpProtocol() {
    }

    static Map<String, Object> result(
            String method,
            Map<String, Object> response) {
        if (response.containsKey("error")) {
            Object raw = response.get("error");
            if (!(raw instanceof Map<?, ?> error)) {
                throw PraxoException.mcpProtocol(
                        "mcp: " + method + " returned an invalid error object");
            }
            Object code = error.get("code");
            Object text = error.get("message");
            String message = text instanceof String value && !value.isEmpty()
                    ? value : "JSON-RPC error";
            throw PraxoException.mcpRpc(
                    "mcp: " + method + " failed: " + message + " (" + code + ")");
        }
        Object result = response.get("result");
        if (result == null) {
            return new LinkedHashMap<>();
        }
        if (!(result instanceof Map<?, ?> object)) {
            throw PraxoException.mcpProtocol(
                    "mcp: " + method + " result must be an object");
        }
        return copyObject(object);
    }

    static McpTool parseTool(Object raw) {
        if (!(raw instanceof Map<?, ?> object)) {
            throw PraxoException.mcpProtocol(
                    "mcp: tool definition must be an object");
        }
        Object name = object.get("name");
        if (!(name instanceof String text) || text.isEmpty()) {
            throw PraxoException.mcpProtocol("mcp: tool name is required");
        }
        if (!(object.get("inputSchema") instanceof Map<?, ?> schema)) {
            throw PraxoException.mcpProtocol(
                    "mcp: missing input schema for " + text);
        }
        Object description = object.get("description");
        Object title = object.get("title");
        Object annotations = object.get("annotations");
        return new McpTool(
                text,
                description instanceof String value ? value : "",
                copyObject(schema),
                title instanceof String value ? value : "",
                annotations instanceof Map<?, ?> value
                        ? copyObject(value) : Map.of());
    }

    static List<String> textContents(Map<String, Object> result) {
        if (!(result.get("content") instanceof List<?> content)) {
            return List.of();
        }
        List<String> texts = new ArrayList<>();
        for (Object item : content) {
            if (!(item instanceof Map<?, ?> block)) {
                continue;
            }
            if (!"text".equals(block.get("type"))) {
                continue;
            }
            if (block.get("text") instanceof String text) {
                texts.add(text);
            }
        }
        return texts;
    }

    static Map<String, Object> copyObject(Map<?, ?> value) {
        Map<String, Object> out = new LinkedHashMap<>();
        for (Map.Entry<?, ?> entry : value.entrySet()) {
            out.put(String.valueOf(entry.getKey()), entry.getValue());
        }
        return Json.object(Json.stringify(out));
    }
}
