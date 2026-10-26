package io.axisvela.praxo.conformance;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.agent.Agent;
import io.axisvela.praxo.agent.AgentOptions;
import io.axisvela.praxo.agent.Result;
import io.axisvela.praxo.agent.Session;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.model.ToolCall;
import io.axisvela.praxo.model.Usage;
import io.axisvela.praxo.tool.Registry;
import io.axisvela.praxo.tool.Tool;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class AgentRun {
    private AgentRun() {
    }

    static void run(Map<String, Object> vector) throws Exception {
        Map<String, Object> input = ConformanceUtil.object(vector.get("input"));
        Map<String, Object> expect = ConformanceUtil.object(vector.get("expect"));
        List<Map<String, Object>> script = new ArrayList<>();
        if (input.get("script") != null) {
            for (Object item : ConformanceUtil.array(input.get("script"))) {
                script.add(ConformanceUtil.object(item));
            }
        }
        int[] calls = {0};
        Registry registry = new Registry();
        if (input.get("tools") != null) {
            for (Object item : ConformanceUtil.array(input.get("tools"))) {
                Map<String, Object> tool = ConformanceUtil.object(item);
                registry.register(new EchoTool(
                        ConformanceUtil.string(tool, "name"),
                        ConformanceUtil.string(tool, "description"),
                        calls));
            }
        }
        ConformanceUtil.RecordingSink sink = new ConformanceUtil.RecordingSink();
        AgentOptions options = new AgentOptions(new ScriptedModel(script));
        options.tools = registry;
        options.events = sink;
        options.maxSteps = input.get("maxSteps") == null
                ? 0 : ConformanceUtil.integer(input, "maxSteps");
        options.maxTokens = input.get("maxTokens") == null
                ? 0 : ConformanceUtil.integer(input, "maxTokens");
        Agent agent = new Agent(options);
        Result result = null;
        PraxoException error = null;
        try {
            result = agent.run(new Session("s1"),
                    ConformanceUtil.string(input, "prompt"));
        } catch (PraxoException caught) {
            error = caught;
        }
        if (ConformanceUtil.bool(expect, "error", false)) {
            ConformanceUtil.check(error != null, "expected an error");
            if (expect.get("errorCode") != null) {
                ConformanceUtil.check(
                        error.code.equals(ConformanceUtil.string(expect, "errorCode")),
                        "errorCode: got " + error.code);
            }
        } else {
            ConformanceUtil.check(error == null,
                    "unexpected error: " + (error == null ? "" : error.getMessage()));
        }
        if (result != null) {
            ConformanceUtil.check(
                    result.output.equals(ConformanceUtil.string(expect, "output")),
                    "output: got " + result.output);
            ConformanceUtil.check(
                    result.steps == ConformanceUtil.integer(expect, "steps"),
                    "steps: got " + result.steps);
        }
        ConformanceUtil.check(
                calls[0] == ConformanceUtil.integer(expect, "toolInvocations"),
                "tool invocations: got " + calls[0]);
        ConformanceUtil.check(
                ConformanceUtil.deepEquals(
                        sink.types.isEmpty() ? null : sink.types,
                        expect.get("events")),
                "events: got " + sink.types);
    }

    private static final class ScriptedModel implements Model {
        private final List<Map<String, Object>> steps;
        private int next;

        private ScriptedModel(List<Map<String, Object>> steps) {
            this.steps = steps;
        }

        @Override
        public Response generate(Request request) {
            if (next >= steps.size()) {
                throw new IllegalStateException("script exhausted");
            }
            Map<String, Object> step = steps.get(next++);
            List<ToolCall> calls = new ArrayList<>();
            if (step.get("toolCalls") != null) {
                for (Object item : ConformanceUtil.array(step.get("toolCalls"))) {
                    calls.add(ToolCall.fromWire(item));
                }
            }
            long inputTokens = step.get("inputTokens") == null
                    ? 0 : ConformanceUtil.integer(step, "inputTokens");
            long outputTokens = step.get("outputTokens") == null
                    ? 0 : ConformanceUtil.integer(step, "outputTokens");
            return new Response(
                    Message.assistant(
                            ConformanceUtil.string(step, "content"), calls),
                    new Usage(inputTokens, outputTokens, 0),
                    null);
        }
    }

    private static final class EchoTool implements Tool {
        private final String name;
        private final String description;
        private final int[] calls;

        private EchoTool(String name, String description, int[] calls) {
            this.name = name;
            this.description = description;
            this.calls = calls;
        }

        @Override
        public String name() {
            return name;
        }

        @Override
        public String description() {
            return description;
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            calls[0] += 1;
            return new LinkedHashMap<>(args);
        }
    }
}
