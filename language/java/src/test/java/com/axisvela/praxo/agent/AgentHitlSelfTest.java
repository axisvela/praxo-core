package com.axisvela.praxo.agent;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.hitl.Interrupt;
import com.axisvela.praxo.hitl.InterruptAction;
import com.axisvela.praxo.hitl.InterruptDecision;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class AgentHitlSelfTest {
    private AgentHitlSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        approveRunsTool();
        editReauthorizes();
        rejectPreventsEffects();
        respondSkipsTool();
        invalidDecisionFails();
        unhandledFails();
        emitsInterruptEvent();
        System.out.println("agent hitl ok");
    }

    private static void approveRunsTool() throws Exception {
        RecordingTool tool = new RecordingTool();
        AgentOptions options = options(tool,
                interrupt -> new InterruptDecision(
                        InterruptAction.APPROVE, null, "", ""));
        Result result = new Agent(options).run(new Session("s1"), "go");
        check(result.output.equals("final"), "output: " + result.output);
        check(tool.calls.equals(List.of(Map.of("value", "original"))),
                "calls: " + tool.calls);
    }

    private static void editReauthorizes() throws Exception {
        RecordingTool tool = new RecordingTool();
        List<String> checked = new ArrayList<>();
        AgentOptions options = options(tool,
                interrupt -> new InterruptDecision(
                        InterruptAction.EDIT, Map.of("value", "edited"), "", ""));
        options.policy = action -> {
            if (action.kind().equals("tool.invoke")) {
                checked.add(String.valueOf(action.arguments().get("value")));
            }
            return com.axisvela.praxo.policy.Decision.allow("");
        };
        Result result = new Agent(options).run(new Session("s1"), "go");
        check(result.output.equals("final"), "output: " + result.output);
        check(tool.calls.equals(List.of(Map.of("value", "edited"))),
                "calls: " + tool.calls);
        check(checked.equals(List.of("original", "edited")),
                "authorizations: " + checked);
    }

    private static void rejectPreventsEffects() throws Exception {
        RecordingTool tool = new RecordingTool();
        AgentOptions options = options(tool,
                interrupt -> new InterruptDecision(
                        InterruptAction.REJECT, null, "", "not allowed"));
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected approval denial");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_APPROVAL_DENIED"),
                    "error: " + error.code);
        }
        check(tool.calls.isEmpty(), "tool executed after rejection");
    }

    private static void respondSkipsTool() throws Exception {
        RecordingTool tool = new RecordingTool();
        AgentOptions options = options(tool,
                interrupt -> new InterruptDecision(
                        InterruptAction.RESPOND, null, "human answer", ""));
        options.model = new RespondModel();
        Result result = new Agent(options).run(new Session("s1"), "go");
        check(result.output.equals("\"human answer\""),
                "output: " + result.output);
        check(tool.calls.isEmpty(), "tool executed after respond");
    }

    private static void invalidDecisionFails() throws Exception {
        RecordingTool tool = new RecordingTool();
        AgentOptions options = options(tool,
                interrupt -> new InterruptDecision(
                        InterruptAction.EDIT, null, "", ""));
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected invalid decision");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_INTERRUPT_DECISION_INVALID"),
                    "error: " + error.code);
        }
        check(tool.calls.isEmpty(), "tool executed after invalid decision");
    }

    private static void unhandledFails() throws Exception {
        RecordingTool tool = new RecordingTool();
        AgentOptions options = options(tool, null);
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected unhandled interrupt");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_INTERRUPT_UNHANDLED"),
                    "error: " + error.code);
        }
        check(tool.calls.isEmpty(), "tool executed without handler");
    }

    private static void emitsInterruptEvent() throws Exception {
        RecordingTool tool = new RecordingTool();
        List<Event> events = new ArrayList<>();
        AgentOptions options = options(tool,
                interrupt -> new InterruptDecision(
                        InterruptAction.APPROVE, null, "", ""));
        options.events = events::add;
        new Agent(options).run(new Session("s1"), "go");
        long interrupts = events.stream()
                .filter(event -> event.type().equals("tool.interrupt"))
                .count();
        check(interrupts == 1, "tool.interrupt events: " + interrupts);
    }

    private static AgentOptions options(
            RecordingTool tool,
            com.axisvela.praxo.hitl.InterruptHandler handler) {
        Registry tools = new Registry();
        tools.register(tool);
        AgentOptions options = new AgentOptions(new ScriptModel());
        options.tools = tools;
        options.interruptOn.add("echo");
        options.onInterruptDecision = handler;
        return options;
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }

    private static final class ScriptModel implements Model {
        private int calls;

        @Override
        public Response generate(Request request) {
            calls += 1;
            if (calls == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("call-1", "echo", Map.of("value", "original")))));
            }
            return Response.of(Message.assistant("final", List.of()));
        }
    }

    private static final class RespondModel implements Model {
        private int calls;

        @Override
        public Response generate(Request request) {
            calls += 1;
            if (calls == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("call-1", "echo", Map.of("value", "original")))));
            }
            for (int index = request.messages().size() - 1; index >= 0; index -= 1) {
                Message message = request.messages().get(index);
                if (message.role().equals(Message.TOOL)) {
                    return Response.of(Message.assistant(message.content(), List.of()));
                }
            }
            return Response.of(Message.assistant("final", List.of()));
        }
    }

    private static final class RecordingTool implements Tool {
        private final List<Map<String, Object>> calls = new ArrayList<>();

        @Override
        public String name() {
            return "echo";
        }

        @Override
        public String description() {
            return "Echo";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            calls.add(new LinkedHashMap<>(args));
            return args;
        }
    }
}
