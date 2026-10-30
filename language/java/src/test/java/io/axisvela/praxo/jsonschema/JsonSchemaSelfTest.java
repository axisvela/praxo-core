package io.axisvela.praxo.jsonschema;

import java.util.Map;

public final class JsonSchemaSelfTest {
    private JsonSchemaSelfTest() {
    }

    public static void main(String[] args) {
        Map<String, Object> integer = Map.of("type", "integer");
        check(JsonSchema.validate(integer, 2).isEmpty(), "integer 2 rejected");
        check(JsonSchema.validate(integer, 2.5).size() == 1,
                "fraction accepted as integer");

        Map<String, Object> text = Map.of(
                "type", "string",
                "minLength", 2,
                "maxLength", 2);
        check(JsonSchema.validate(text, "你好").isEmpty(),
                "two Unicode code points rejected");
        check(JsonSchema.validate(text, "你").size() == 1,
                "one Unicode code point accepted");
        System.out.println("json schema ok");
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
