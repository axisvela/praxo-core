package io.axisvela.praxo.agent;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.middleware.Middleware;
import io.axisvela.praxo.middleware.ToolResult;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.model.ToolCall;
import io.axisvela.praxo.tool.Registry;
import io.axisvela.praxo.tool.Tool;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

public final class AgentConcurrencySelfTest {
    private AgentConcurrencySelfTest() {
    }

    public static void main(String[] args) throws Exception {
        AtomicBoolean virtual = new AtomicBoolean();
        Model model = request -> {
            virtual.set(Thread.currentThread().isVirtual());
            return Response.of(Message.assistant("ok", List.of()));
        };
        Result result = new Agent(new AgentOptions(model))
                .run(new Session("s1"), "hi");
        check(result.output.equals("ok"), "output");
        check(virtual.get(), "model did not run on a virtual thread");
        parallelToolsStartTogether();

        Model slow = request -> {
            Thread.sleep(5000);
            return Response.of(Message.assistant("late", List.of()));
        };
        CancellationToken token = new CancellationToken();
        AgentOptions options = new AgentOptions(slow);
        options.cancellation = token;
        Thread canceller = Thread.ofVirtual().start(() -> {
            try {
                Thread.sleep(100);
            } catch (InterruptedException ignored) {
                return;
            }
            token.cancel();
        });
        long start = System.nanoTime();
        try {
            new Agent(options).run(new Session("s1"), "hi");
            throw new AssertionError("expected abort");
        } catch (PraxoException error) {
            check(error.code.equals("AGENT_ABORTED"),
                    "errorCode: " + error.code);
        }
        long elapsedMs = (System.nanoTime() - start) / 1_000_000;
        check(elapsedMs < 3000, "abort took too long: " + elapsedMs + "ms");
        canceller.join();
        System.out.println("agent concurrency ok");
    }

    private static void parallelToolsStartTogether() throws Exception {
        AtomicInteger started = new AtomicInteger();
        CyclicBarrier barrier = new CyclicBarrier(2);
        Tool tool = new Tool() {
            @Override
            public String name() {
                return "barrier";
            }

            @Override
            public String description() {
                return "waits for both calls";
            }

            @Override
            public Object invoke(Map<String, Object> args) throws Exception {
                started.incrementAndGet();
                barrier.await(2, TimeUnit.SECONDS);
                return args;
            }
        };
        Registry tools = new Registry();
        tools.register(tool);
        AtomicInteger step = new AtomicInteger();
        Model model = request -> {
            if (step.incrementAndGet() == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("c1", "barrier", Map.of("value", 1)),
                        new ToolCall("c2", "barrier", Map.of("value", 2)))));
            }
            return Response.of(Message.assistant("done", List.of()));
        };
        List<String> order = new ArrayList<>();
        AgentOptions options = new AgentOptions(model);
        options.tools = tools;
        options.maxParallelTools = 2;
        options.middleware.add(new Middleware() {
            @Override
            public void afterTool(
                    io.axisvela.praxo.middleware.MiddlewareToolCall call,
                    ToolResult result) {
                order.add(call.call.id());
            }
        });
        Result result = new Agent(options).run(new Session("s1"), "go");
        check(result.output.equals("done"), "parallel output");
        check(started.get() == 2, "tools started: " + started.get());
        check(order.equals(List.of("c1", "c2")), "result order: " + order);
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
