package com.axisvela.praxo.model;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public record ToolCall(String id, String name, Map<String, Object> arguments) {
    public ToolCall {
        arguments = arguments == null ? new LinkedHashMap<>() : arguments;
    }

    public static ToolCall fromWire(Object raw) {
        Map<String, Object> map = com.axisvela.praxo.util.Json.asObject(raw);
        return new ToolCall(
                com.axisvela.praxo.util.Json.string(map.get("id")),
                com.axisvela.praxo.util.Json.string(map.get("name")),
                map.get("arguments") == null
                        ? new LinkedHashMap<>()
                        : com.axisvela.praxo.util.Json.asObject(map.get("arguments")));
    }

    public static List<ToolCall> listFromWire(Object raw) {
        List<ToolCall> out = new ArrayList<>();
        if (raw == null) {
            return out;
        }
        for (Object item : com.axisvela.praxo.util.Json.asArray(raw)) {
            out.add(fromWire(item));
        }
        return out;
    }

    public Map<String, Object> toWire() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("id", id);
        out.put("name", name);
        out.put("arguments", arguments);
        return out;
    }
}
