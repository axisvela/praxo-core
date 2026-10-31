package com.axisvela.praxo.checkpoint;

import java.util.LinkedHashMap;
import java.util.Map;

public final class CheckpointSelfTest {
    private CheckpointSelfTest() {
    }

    public static void main(String[] args) {
        Allowlist allow = new Allowlist();
        allow.register("spec.payload", LinkedHashMap::new);
        Map<String, Object> nested = new LinkedHashMap<>();
        nested.put("value", "nested-value");
        Map<String, Object> original = new LinkedHashMap<>();
        original.put("text", "你好");
        original.put("nested", nested);
        String encoded = allow.marshal("spec.payload", original);
        @SuppressWarnings("unchecked")
        Map<String, Object> restored =
                (Map<String, Object>) allow.unmarshal(encoded);
        check("你好".equals(restored.get("text")), "text content changed");
        @SuppressWarnings("unchecked")
        Map<String, Object> restoredNested =
                (Map<String, Object>) restored.get("nested");
        check("nested-value".equals(restoredNested.get("value")),
                "nested content changed");
        System.out.println("checkpoint ok");
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
