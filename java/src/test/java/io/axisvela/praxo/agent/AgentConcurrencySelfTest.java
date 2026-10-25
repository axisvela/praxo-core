package io.axisvela.praxo.agent;

import io.axisvela.praxo.PraxoException;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Response;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

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

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
