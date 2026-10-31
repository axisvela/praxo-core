package com.axisvela.praxo.middleware;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.jsonschema.JsonSchema;
import com.axisvela.praxo.jsonschema.ValidationError;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.ResponseFormat;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.util.Json;

import java.util.List;
import java.util.Map;

public final class StructuredOutput implements Middleware {
    public static final String AUTO = "auto";
    public static final String PROVIDER = "provider";
    public static final String TOOL = "tool";

    @FunctionalInterface
    public interface Validator {
        void validate(String output) throws Exception;
    }

    @FunctionalInterface
    public interface Repairer {
        String repair(String output, Throwable error) throws Exception;
    }

    private final Map<String, Object> schema;
    private final String configuredName;
    private final String strategy;
    private final int maxRepairs;
    private final Validator validator;
    private final Repairer repairer;

    public StructuredOutput(
            Map<String, Object> schema,
            String name,
            String strategy,
            int maxRepairs,
            Validator validator,
            Repairer repairer) {
        this.schema = schema == null ? Map.of() : schema;
        this.configuredName = name == null ? "" : name;
        this.strategy = strategy == null ? AUTO : strategy;
        this.maxRepairs = maxRepairs;
        this.validator = validator;
        this.repairer = repairer;
    }

    public StructuredOutput(Map<String, Object> schema) {
        this(schema, "", AUTO, 0, null, null);
    }

    public String outputName() {
        return configuredName.trim().isEmpty()
                ? "structured_output" : configuredName.trim();
    }

    public ResponseFormat responseFormat() {
        if (strategy.equals(TOOL) || schema.isEmpty()) {
            return null;
        }
        return new ResponseFormat(outputName(), schema);
    }

    public ToolSpec toolSpec() {
        return new ToolSpec(
                outputName(),
                "Return the final answer as structured JSON matching the "
                        + "response schema.",
                schema,
                "low");
    }

    @Override
    public String name() {
        return "structured-output";
    }

    @Override
    public void beforeModel(ModelCall call) {
        if (call.request == null) {
            return;
        }
        if (call.request.responseFormat() == null
                && responseFormat() != null) {
            call.request = new Request(
                    call.request.model(), call.request.messages(),
                    call.request.tools(), call.request.toolChoice(),
                    responseFormat(), call.request.cacheHint(),
                    call.request.temperature());
        }
        if (strategy.equals(TOOL)) {
            boolean present = call.request.tools().stream()
                    .anyMatch(spec -> spec.name().equals(outputName()));
            if (present) {
                call.request = new Request(
                        call.request.model(), call.request.messages(),
                        call.request.tools(), "required",
                        call.request.responseFormat(), call.request.cacheHint(),
                        call.request.temperature());
            }
        }
    }

    @Override
    public void afterRun(Object result, Throwable error) throws Exception {
        if (error != null || !(result instanceof com.axisvela.praxo.agent.Result value)) {
            return;
        }
        apply(value);
    }

    public void apply(com.axisvela.praxo.agent.Result result) throws Exception {
        String output = result.output;
        Throwable lastError = null;
        for (int attempt = 0; attempt <= maxRepairs; attempt++) {
            try {
                validate(output);
                result.output = output;
                return;
            } catch (Exception error) {
                lastError = error;
            }
            if (attempt == maxRepairs || repairer == null) {
                break;
            }
            String repaired = repairer.repair(output, lastError);
            if (repaired == null || repaired.trim().isEmpty()) {
                throw PraxoException.structuredOutput(
                        "agent: structured output validation failed: "
                                + "repair returned empty output");
            }
            output = repaired;
        }
        throw PraxoException.structuredOutput(
                "agent: structured output validation failed: " + lastError);
    }

    public void validateArguments(Map<String, Object> arguments) throws Exception {
        if (validator != null) {
            validator.validate(Json.stringify(arguments));
            return;
        }
        List<ValidationError> errors = JsonSchema.validate(schema, arguments);
        if (!errors.isEmpty()) {
            throw PraxoException.structuredOutput("schema: " + errors);
        }
    }

    private void validate(String output) throws Exception {
        if (validator != null) {
            validator.validate(output);
            return;
        }
        Object data = extractJson(output);
        List<ValidationError> errors = JsonSchema.validate(schema, data);
        if (!errors.isEmpty()) {
            throw PraxoException.structuredOutput("schema: " + errors);
        }
    }

    public static Object extractJson(String output) {
        String text = output == null ? "" : output.trim();
        if (text.isEmpty()) {
            throw new IllegalArgumentException("empty output");
        }
        if (text.startsWith("```")) {
            int newline = text.indexOf('\n');
            if (newline >= 0) {
                text = text.substring(newline + 1);
            }
            text = text.replaceAll("```\\s*$", "").trim();
        }
        int start = firstIndex(text, '{', '[');
        if (start < 0) {
            throw new IllegalArgumentException("output does not contain JSON");
        }
        text = text.substring(start);
        try {
            return Json.parse(text);
        } catch (RuntimeException error) {
            throw new IllegalArgumentException(
                    "decode JSON: " + error.getMessage(), error);
        }
    }

    private static int firstIndex(String text, char... needles) {
        int found = -1;
        for (char needle : needles) {
            int index = text.indexOf(needle);
            if (index >= 0 && (found < 0 || index < found)) {
                found = index;
            }
        }
        return found;
    }
}
