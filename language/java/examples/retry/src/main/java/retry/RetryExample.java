package retry;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.middleware.Middleware;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;

import java.util.List;

public final class RetryExample {
    private RetryExample() {
    }

    static Middleware.ModelMiddleware retry(int maxAttempts) {
        return next -> request -> {
            PraxoException last = null;
            for (int attempt = 1; attempt <= maxAttempts; attempt++) {
                try {
                    return next.handle(request);
                } catch (PraxoException error) {
                    if (!"MODEL_UNAVAILABLE".equals(error.code)) {
                        throw error;
                    }
                    last = error;
                    if (attempt == maxAttempts) {
                        throw error;
                    }
                }
            }
            throw last == null
                    ? new PraxoException("MODEL_UNAVAILABLE", "model unavailable")
                    : last;
        };
    }

    static final class FlakyModel implements Model {
        private final int failures;
        int calls;

        FlakyModel(int failures) {
            this.failures = failures;
        }

        @Override
        public Response generate(Request request) throws Exception {
            calls += 1;
            if (calls <= failures) {
                throw new PraxoException("MODEL_UNAVAILABLE", "temporary outage");
            }
            return Response.of(Message.assistant("status: green", List.of()));
        }
    }

    static String run(Model model) throws Exception {
        AgentOptions options = new AgentOptions(model);
        options.modelMiddleware.add(retry(3));
        options.maxSteps = 2;
        return new Agent(options)
                .run(new Session("retry"), "Check the status.")
                .output;
    }

    public static void main(String[] args) throws Exception {
        FlakyModel recovered = new FlakyModel(2);
        if (!run(recovered).equals("status: green") || recovered.calls != 3) {
            throw new IllegalStateException("transient retry path failed");
        }

        FlakyModel exhausted = new FlakyModel(3);
        try {
            run(exhausted);
        } catch (PraxoException error) {
            if (!"MODEL_UNAVAILABLE".equals(error.code) || exhausted.calls != 3) {
                throw new IllegalStateException("exhausted retry path failed");
            }
            System.out.println("retry test: ok");
            return;
        }
        throw new IllegalStateException("exhausted retry path did not preserve the error");
    }
}
