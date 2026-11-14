package fallback;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;

import java.util.List;

public final class FallbackExample {
    private FallbackExample() {
    }

    static final class FailingModel implements Model {
        int calls;

        @Override
        public Response generate(Request request) {
            calls += 1;
            throw new PraxoException("MODEL_UNAVAILABLE", "primary unavailable");
        }
    }

    static final class StaticModel implements Model {
        private final String content;
        int calls;

        StaticModel(String content) {
            this.content = content;
        }

        @Override
        public Response generate(Request request) {
            calls += 1;
            return Response.of(Message.assistant(content, List.of()));
        }
    }

    static String run(Model primary, Model fallback) throws Exception {
        AgentOptions options = new AgentOptions(primary);
        options.fallbackModel = fallback;
        options.maxSteps = 2;
        return new Agent(options)
                .run(new Session("provider-fallback"), "Say hello.")
                .output;
    }

    public static void main(String[] args) throws Exception {
        StaticModel primary = new StaticModel("primary response");
        StaticModel fallback = new StaticModel("fallback response");
        if (!run(primary, fallback).equals("primary response") || fallback.calls != 0) {
            throw new IllegalStateException("primary success path failed");
        }

        FailingModel failing = new FailingModel();
        StaticModel used = new StaticModel("fallback response");
        if (!run(failing, used).equals("fallback response")
                || failing.calls != 1 || used.calls != 1) {
            throw new IllegalStateException("fallback path failed");
        }

        try {
            run(new FailingModel(), new FailingModel());
        } catch (PraxoException error) {
            if (!"MODEL_UNAVAILABLE".equals(error.code)) {
                throw new IllegalStateException("unexpected error code", error);
            }
            System.out.println("provider fallback test: ok");
            return;
        }
        throw new IllegalStateException("both-failure path did not reject");
    }
}
