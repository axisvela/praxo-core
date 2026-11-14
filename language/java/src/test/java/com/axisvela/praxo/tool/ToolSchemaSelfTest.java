package com.axisvela.praxo.tool;

import com.axisvela.praxo.model.ToolSpec;

import java.util.List;
import java.util.Map;

public final class ToolSchemaSelfTest {
    private ToolSchemaSelfTest() {
    }

    static final class SchemaTool implements Tool {
        @Override
        public String name() {
            return "record";
        }

        @Override
        public String description() {
            return "Record a target.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            return "recorded";
        }

        public ToolSpec spec() {
            return new ToolSpec(
                    "record",
                    description(),
                    Map.of(
                            "type", "object",
                            "required", List.of("target"),
                            "properties", Map.of("target", Map.of("type", "string"))),
                    "write");
        }
    }

    static final class PlainTool implements Tool {
        @Override
        public String name() {
            return "plain";
        }

        @Override
        public String description() {
            return "Plain tool.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            return "ok";
        }
    }

    public static void main(String[] args) {
        Registry registry = new Registry();
        registry.register(new SchemaTool());
        registry.register(new PlainTool());

        List<ToolSpec> specs = registry.specs();
        if (specs.size() != 2) {
            throw new AssertionError("expected two specs");
        }
        ToolSpec schema = specs.get(0);
        if (!"plain".equals(schema.name())) {
            throw new AssertionError("specs must be sorted by name");
        }
        if (schema.parameters() != null) {
            throw new AssertionError("plain tool should not expose parameters");
        }
        ToolSpec record = specs.get(1);
        if (record.parameters() == null || !"write".equals(record.risk())) {
            throw new AssertionError("record tool should expose parameters and risk");
        }
        System.out.println("tool schema self-test: ok");
    }
}
