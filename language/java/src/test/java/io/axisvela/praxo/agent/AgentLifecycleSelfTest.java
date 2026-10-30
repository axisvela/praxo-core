package io.axisvela.praxo.agent;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.middleware.Middleware;
import io.axisvela.praxo.middleware.RunState;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.model.ToolCall;
import io.axisvela.praxo.event.Event;
import io.axisvela.praxo.event.Sink;
import io.axisvela.praxo.tool.Registry;
import io.axisvela.praxo.tool.Tool;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

public final class AgentLifecycleSelfTest {
    private AgentLifecycleSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        startupFailureCleansEntered();
        cleanupContinuesAndPreservesRunError();
        cleanupErrorAfterSuccessFailsClosed();
        cancellationRunsAfterRun();
        toolCancellationRunsAfterRun();
        System.out.println("agent lifecycle ok");
    }

    private static void startupFailureCleansEntered() throws Exception {
        List<String> calls = new ArrayList<>();
        List<String> events = new ArrayList<>();
        Middleware first = new Middleware() {
            @Override
            public void beforeRun(RunState state) {
                calls.add("first.before");
            }

            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("first.after:" + (error == null ? "none" : error.getClass().getSimpleName()));
            }
        };
        Middleware second = new Middleware() {
            @Override
            public void beforeRun(RunState state) {
                calls.add("second.before");
                throw new IllegalStateException("startup failed");
            }

            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("second.after");
            }
        };
        Middleware third = new Middleware() {
            @Override
            public void beforeRun(RunState state) {
                calls.add("third.before");
            }

            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("third.after");
            }
        };
        AgentOptions options = new AgentOptions(doneModel());
        options.events = event -> events.add(event.type());
        options.middleware.add(first);
        options.middleware.add(second);
        options.middleware.add(third);
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected startup failure");
        } catch (IllegalStateException expected) {
            check(expected.getMessage().equals("startup failed"), expected.getMessage());
        }
        check(calls.equals(List.of(
                "first.before", "second.before",
                "first.after:IllegalStateException", "second.after")),
                "calls: " + calls);
        check(events.isEmpty(), "events: " + events);
    }

    private static void cleanupContinuesAndPreservesRunError() throws Exception {
        List<String> calls = new ArrayList<>();
        Middleware first = new Middleware() {
            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("first.after");
                throw new IllegalStateException("cleanup failed");
            }
        };
        Middleware second = new Middleware() {
            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("second.after");
            }
        };
        AgentOptions options = new AgentOptions(request -> {
            throw new IllegalStateException("run failed");
        });
        options.middleware.add(first);
        options.middleware.add(second);
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected run failure");
        } catch (IllegalStateException expected) {
            check(expected.getMessage().equals("run failed"), expected.getMessage());
        }
        check(calls.equals(List.of("first.after", "second.after")),
                "calls: " + calls);
    }

    private static void cleanupErrorAfterSuccessFailsClosed() throws Exception {
        List<String> calls = new ArrayList<>();
        List<String> events = new ArrayList<>();
        Middleware first = new Middleware() {
            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("first.after");
                throw new IllegalStateException("cleanup failed");
            }
        };
        Middleware second = new Middleware() {
            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add("second.after");
            }
        };
        AgentOptions options = new AgentOptions(doneModel());
        options.events = event -> events.add(event.type());
        options.middleware.add(first);
        options.middleware.add(second);
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected cleanup failure");
        } catch (IllegalStateException expected) {
            check(expected.getMessage().equals("cleanup failed"), expected.getMessage());
        }
        check(calls.equals(List.of("first.after", "second.after")),
                "calls: " + calls);
        check(events.equals(List.of("run.started", "run.failed")),
                "events: " + events);
    }

    private static void cancellationRunsAfterRun() throws Exception {
        List<String> calls = new ArrayList<>();
        List<String> events = new ArrayList<>();
        AgentOptions options = new AgentOptions(request -> {
            Thread.sleep(5000);
            return Response.of(Message.assistant("late", List.of()));
        });
        CancellationToken token = new CancellationToken();
        options.cancellation = token;
        options.events = event -> events.add(event.type());
        options.middleware.add(new Middleware() {
            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add(error == null ? "none" : error.getClass().getSimpleName());
            }
        });
        Thread canceller = Thread.ofVirtual().start(() -> {
            try {
                Thread.sleep(100);
            } catch (InterruptedException ignored) {
                return;
            }
            token.cancel();
        });
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected cancellation");
        } catch (PraxoException expected) {
            check(expected.code.equals("AGENT_ABORTED"), "error: " + expected.code);
        }
        canceller.join();
        check(calls.equals(List.of("PraxoException")), "calls: " + calls);
        check(events.equals(List.of("run.started", "run.failed")),
                "events: " + events);
    }

    private static void toolCancellationRunsAfterRun() throws Exception {
        List<String> calls = new ArrayList<>();
        List<String> events = new ArrayList<>();
        Registry tools = new Registry();
        tools.register(new Tool() {
            @Override
            public String name() {
                return "wait";
            }

            @Override
            public String description() {
                return "wait";
            }

            @Override
            public Object invoke(Map<String, Object> args) throws Exception {
                Thread.sleep(5000);
                return "late";
            }
        });
        AtomicInteger step = new AtomicInteger();
        AgentOptions options = new AgentOptions(request -> {
            if (step.incrementAndGet() == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("c1", "wait", Map.of()))));
            }
            return Response.of(Message.assistant("done", List.of()));
        });
        CancellationToken token = new CancellationToken();
        options.tools = tools;
        options.cancellation = token;
        options.events = event -> events.add(event.type());
        options.middleware.add(new Middleware() {
            @Override
            public void afterRun(Object result, Throwable error) {
                calls.add(error == null ? "none" : error.getClass().getSimpleName());
            }
        });
        Thread canceller = Thread.ofVirtual().start(() -> {
            try {
                Thread.sleep(100);
            } catch (InterruptedException ignored) {
                return;
            }
            token.cancel();
        });
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected tool cancellation");
        } catch (PraxoException expected) {
            check(expected.code.equals("AGENT_ABORTED"), "error: " + expected.code);
        }
        canceller.join();
        check(calls.equals(List.of("PraxoException")), "calls: " + calls);
        check(events.equals(List.of("run.started", "tool.call", "run.failed")),
                "events: " + events);
    }

    private static Model doneModel() {
        return request -> Response.of(Message.assistant("done", List.of()));
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
