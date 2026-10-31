package com.axisvela.praxo.checkpoint;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.util.Json;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.Supplier;

public final class Allowlist {
    private final Map<String, Supplier<Object>> factories = new LinkedHashMap<>();

    public synchronized void register(String name, Supplier<Object> factory) {
        if (name == null || name.isEmpty()) {
            throw PraxoException.checkpoint(
                    "checkpoint: allowlist type name is required");
        }
        if (factory == null) {
            throw PraxoException.checkpoint(
                    "checkpoint: allowlist factory is required");
        }
        factories.put(name, factory);
    }

    public synchronized String marshal(String name, Object value) {
        if (!factories.containsKey(name)) {
            throw PraxoException.typeNotAllowed(
                    "checkpoint: payload type not allowed: " + name);
        }
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("type", name);
        envelope.put("data", value);
        return Json.stringify(envelope);
    }

    public synchronized Object unmarshal(String data) {
        Map<String, Object> envelope = Json.object(data);
        String type = Json.string(envelope.get("type"));
        Supplier<Object> factory = factories.get(type);
        if (factory == null) {
            throw PraxoException.typeNotAllowed(
                    "checkpoint: payload type not allowed: " + type);
        }
        Object target = factory.get();
        if (target == null) {
            throw PraxoException.checkpoint(
                    "checkpoint: factory for " + type + " returned nil");
        }
        Object payload = envelope.get("data");
        if (target instanceof Map<?, ?> map && payload instanceof Map<?, ?> values) {
            @SuppressWarnings("unchecked")
            Map<String, Object> targetMap = (Map<String, Object>) map;
            @SuppressWarnings("unchecked")
            Map<String, Object> valueMap = (Map<String, Object>) values;
            targetMap.putAll(valueMap);
            return target;
        }
        return payload;
    }
}
