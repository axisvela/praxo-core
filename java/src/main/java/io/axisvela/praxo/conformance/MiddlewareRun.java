package io.axisvela.praxo.conformance;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.agent.Result;
import io.axisvela.praxo.middleware.CallLimitMiddleware;
import io.axisvela.praxo.middleware.FallbackModel;
import io.axisvela.praxo.middleware.Middleware;
import io.axisvela.praxo.middleware.MiddlewareToolCall;
import io.axisvela.praxo.middleware.ModelCall;
import io.axisvela.praxo.middleware.PiiMiddleware;
import io.axisvela.praxo.middleware.PiiRedactor;
import io.axisvela.praxo.middleware.RunState;
import io.axisvela.praxo.middleware.StructuredOutput;
import io.axisvela.praxo.middleware.ToolResult;
import io.axisvela.praxo.middleware.ToolSelectionMiddleware;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.model.ToolCall;
import io.axisvela.praxo.model.ToolSpec;
import io.axisvela.praxo.model.Usage;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class MiddlewareRun {
    private MiddlewareRun() {
    }

    static void run(Map<String, Object> vector) throws Exception {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        String operation = ConformanceUtil.string(input, "operation");
        switch (operation) {
            case "pii" -> {
                String got = PiiRedactor.defaults()
                        .redact(ConformanceUtil.string(input, "text"));
                ConformanceUtil.check(
                        got.equals(ConformanceUtil.string(expect, "text")),
                        "text: got " + got);
            }
            case "pii-value" -> {
                PiiMiddleware middleware = new PiiMiddleware(PiiRedactor.defaults());
                ToolResult result = new ToolResult(input.get("value"), null);
                middleware.afterTool(toolCall("r1", "s1", "echo"), result);
                ConformanceUtil.check(
                        ConformanceUtil.deepEquals(result.value, expect.get("value")),
                        "value: got " + result.value);
            }
            case "structured" -> {
                int maxRepairs = input.get("maxRepairs") == null
                        ? 0 : ConformanceUtil.integer(input, "maxRepairs");
                String repairOutput = input.get("repairOutput") == null
                        ? null : ConformanceUtil.string(input, "repairOutput");
                StructuredOutput output = new StructuredOutput(
                        ConformanceUtil.object(input.get("schema")), "", StructuredOutput.AUTO,
                        maxRepairs, null,
                        repairOutput == null ? null
                                : (current, error) -> repairOutput);
                Result result = new Result(
                        "r1", ConformanceUtil.string(input, "output"), 0, Usage.zero());
                try {
                    output.apply(result);
                } catch (PraxoException error) {
                    if (ConformanceUtil.bool(expect, "ok", false)) {
                        throw error;
                    }
                    ConformanceUtil.check(
                            error.code.equals(ConformanceUtil.string(expect, "errorCode")),
                            "errorCode: got " + error.code);
                    return;
                }
                ConformanceUtil.check(
                        ConformanceUtil.bool(expect, "ok", false),
                        "expected a structured output error");
                ConformanceUtil.check(
                        result.output.equals(ConformanceUtil.string(expect, "output")),
                        "output: got " + result.output);
            }
            case "call-limit" -> {
                CallLimitMiddleware middleware = new CallLimitMiddleware(
                        ConformanceUtil.integer(input, "modelLimit"),
                        ConformanceUtil.integer(input, "toolLimit"));
                middleware.beforeRun(new RunState("r1", null, ""));
                List<String> outcomes = new ArrayList<>();
                for (Object item : ConformanceUtil.array(input.get("calls"))) {
                    String kind = String.valueOf(item);
                    try {
                        if (kind.equals("model")) {
                            middleware.beforeModel(new ModelCall(
                                    "r1", "s1", Request.of(List.of())));
                        } else if (kind.equals("tool")) {
                            middleware.beforeTool(toolCall("r1", "s1", "echo"));
                        } else {
                            throw new IllegalArgumentException(
                                    "unknown call kind " + kind);
                        }
                        outcomes.add("ok");
                    } catch (PraxoException error) {
                        outcomes.add(error.code);
                    }
                }
                ConformanceUtil.check(
                        ConformanceUtil.deepEquals(outcomes, expect.get("outcomes")),
                        "outcomes: got " + outcomes);
            }
            case "tool-selection" -> {
                List<String> selected = new ArrayList<>();
                for (Object item : ConformanceUtil.array(input.get("selected"))) {
                    selected.add(String.valueOf(item));
                }
                ToolSelectionMiddleware middleware = new ToolSelectionMiddleware(
                        (query, tools) -> selected);
                List<ToolSpec> tools = new ArrayList<>();
                for (Object item : ConformanceUtil.array(input.get("tools"))) {
                    String name = String.valueOf(item);
                    tools.add(new ToolSpec(name, ""));
                }
                ModelCall call = new ModelCall(
                        "r1", "s1", Request.of(List.of()).withTools(tools));
                middleware.beforeModel(call);
                List<String> advertised = new ArrayList<>();
                for (ToolSpec spec : call.request.tools()) {
                    advertised.add(spec.name());
                }
                ConformanceUtil.check(
                        ConformanceUtil.deepEquals(advertised, expect.get("advertised")),
                        "advertised: got " + advertised);
                String reject = "ok";
                try {
                    middleware.beforeTool(toolCall(
                            "r1", "s1", ConformanceUtil.string(input, "requested")));
                } catch (PraxoException error) {
                    reject = error.code;
                }
                ConformanceUtil.check(
                        reject.equals(ConformanceUtil.string(expect, "reject")),
                        "reject: got " + reject);
            }
            case "fallback" -> {
                io.axisvela.praxo.model.Model fallback = request -> Response.of(
                        Message.assistant(
                                ConformanceUtil.string(input, "fallbackContent"),
                                List.of()));
                Middleware.ModelHandler handler = FallbackModel.fallback(fallback)
                        .apply(request -> {
                            throw new PraxoException(
                                    "PRIMARY_FAILED", "primary failed");
                        });
                Response response = handler.handle(Request.of(List.of()));
                ConformanceUtil.check(
                        response.message().content()
                                .equals(ConformanceUtil.string(expect, "output")),
                        "output: got " + response.message().content());
            }
            default -> throw new IllegalArgumentException(
                    "unknown middleware operation " + operation);
        }
    }

    private static MiddlewareToolCall toolCall(
            String runId, String sessionId, String name) {
        return new MiddlewareToolCall(
                runId, sessionId, new ToolCall("c", name, new LinkedHashMap<>()));
    }
}
