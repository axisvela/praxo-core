package com.axisvela.praxo.agent;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.middleware.Middleware;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

public final class AgentAuthorizationSelfTest {
    private AgentAuthorizationSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        argumentChangesAreReauthorized();
        nameChangesUseFinalTool();
        unchangedToolAuthorizedOnce();
        initialDenialPreventsMiddleware();
        finalNameMustRemainAllowed();
        System.out.println("agent authorization ok");
    }

    private static void argumentChangesAreReauthorized() throws Exception {
        RecordingTool tool = new RecordingTool("echo");
        Registry tools = new Registry();
        tools.register(tool);
        List<Action> actions = new ArrayList<>();
        Hook hook = action -> {
            actions.add(action);
            return decision(action);
        };
        AgentOptions options = new AgentOptions(scriptModel("echo"));
        options.tools = tools;
        options.policy = hook;
        options.middleware.add(new Middleware() {
            @Override
            public void beforeTool(com.axisvela.praxo.middleware.MiddlewareToolCall call) {
                call.call = new ToolCall("c-echo", "echo", Map.of("text", "denied"));
            }
        });
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected policy denial");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_POLICY_DENIED"), "policy error: " + error.code);
        }
        check(tool.calls.isEmpty(), "tool executed after final denial");
        List<String> names = new ArrayList<>();
        for (Action action : actions) {
            if (action.kind().equals("tool.invoke")) {
                names.add(action.toolName());
            }
        }
        check(names.equals(List.of("echo", "echo")), "tool authorizations: " + names);
    }

    private static void nameChangesUseFinalTool() throws Exception {
        RecordingTool original = new RecordingTool("echo");
        RecordingTool replacement = new RecordingTool("admin");
        Registry tools = new Registry();
        tools.register(original);
        tools.register(replacement);
        List<Action> actions = new ArrayList<>();
        AgentOptions options = new AgentOptions(scriptModel("echo"));
        options.tools = tools;
        options.policy = action -> {
            actions.add(action);
            return decision(action);
        };
        options.middleware.add(new Middleware() {
            @Override
            public void beforeTool(com.axisvela.praxo.middleware.MiddlewareToolCall call) {
                call.call = new ToolCall("c-echo", "admin", Map.of());
            }
        });
        Result result = new Agent(options).run(new Session("s1"), "go");
        check(result.output.equals("done"), "output: " + result.output);
        check(original.calls.isEmpty(), "original tool executed");
        check(replacement.calls.size() == 1, "replacement calls: " + replacement.calls.size());
        List<String> names = new ArrayList<>();
        for (Action action : actions) {
            if (action.kind().equals("tool.invoke")) {
                names.add(action.toolName());
            }
        }
        check(names.equals(List.of("echo", "admin")), "tool authorizations: " + names);
    }

    private static void unchangedToolAuthorizedOnce() throws Exception {
        RecordingTool tool = new RecordingTool("echo");
        Registry tools = new Registry();
        tools.register(tool);
        List<Action> actions = new ArrayList<>();
        AgentOptions options = new AgentOptions(scriptModel("echo"));
        options.tools = tools;
        options.policy = action -> {
            actions.add(action);
            return decision(action);
        };
        new Agent(options).run(new Session("s1"), "go");
        long count = actions.stream().filter(a -> a.kind().equals("tool.invoke")).count();
        check(count == 1, "tool authorizations: " + count);
        check(tool.calls.size() == 1, "tool calls: " + tool.calls.size());
    }

    private static void initialDenialPreventsMiddleware() throws Exception {
        RecordingTool tool = new RecordingTool("echo");
        Registry tools = new Registry();
        tools.register(tool);
        AtomicBoolean middleware = new AtomicBoolean();
        AgentOptions options = new AgentOptions(scriptModel("echo"));
        options.tools = tools;
        options.policy = action -> Decision.deny("fixture");
        options.middleware.add(new Middleware() {
            @Override
            public void beforeTool(com.axisvela.praxo.middleware.MiddlewareToolCall call) {
                middleware.set(true);
            }
        });
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected policy denial");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_POLICY_DENIED"), "policy error: " + error.code);
        }
        check(!middleware.get(), "middleware ran after initial denial");
        check(tool.calls.isEmpty(), "tool executed after initial denial");
    }

    private static void finalNameMustRemainAllowed() throws Exception {
        RecordingTool replacement = new RecordingTool("admin");
        Registry tools = new Registry();
        tools.register(new RecordingTool("echo"));
        tools.register(replacement);
        AgentOptions options = new AgentOptions(scriptModel("echo"));
        options.tools = tools;
        options.allowedTools = List.of("echo");
        options.middleware.add(new Middleware() {
            @Override
            public void beforeTool(com.axisvela.praxo.middleware.MiddlewareToolCall call) {
                call.call = new ToolCall("c-echo", "admin", Map.of());
            }
        });
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected final name rejection");
        } catch (IllegalArgumentException expected) {
            check(expected.getMessage().contains("admin"), expected.getMessage());
        }
        check(replacement.calls.isEmpty(), "replacement executed after final name rejection");
    }

    private static Model scriptModel(String toolName) {
        AtomicInteger step = new AtomicInteger();
        return request -> {
            if (step.incrementAndGet() == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("c-" + toolName, toolName, Map.of("text", "ok")))));
            }
            return Response.of(Message.assistant("done", List.of()));
        };
    }

    private static Decision decision(Action action) {
        if (action.arguments() != null
                && "denied".equals(action.arguments().get("text"))) {
            return Decision.deny("fixture");
        }
        return Decision.allow("fixture");
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }

    private static final class RecordingTool implements Tool {
        private final String name;
        private final List<Map<String, Object>> calls = new ArrayList<>();

        private RecordingTool(String name) {
            this.name = name;
        }

        @Override
        public String name() {
            return name;
        }

        @Override
        public String description() {
            return name;
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            calls.add(args);
            return args;
        }
    }
}
