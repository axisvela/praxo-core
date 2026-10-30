package io.axisvela.praxo.agent;

import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.model.StreamingModel;

import java.util.List;

public final class AgentStreamSelfTest {
    private AgentStreamSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        streamCallbackFailureAbortsRun();
        System.out.println("agent stream ok");
    }

    private static void streamCallbackFailureAbortsRun() throws Exception {
        StreamingModel model = new StreamingModel() {
            @Override
            public Response generate(Request request) {
                return Response.of(Message.assistant("done", List.of()));
            }

            @Override
            public Response generateStream(
                    Request request,
                    java.util.function.Consumer<String> onDelta) {
                onDelta.accept("he");
                return Response.of(Message.assistant("done", List.of()));
            }
        };
        AgentOptions options = new AgentOptions(model);
        options.onDelta = delta -> {
            throw new IllegalStateException("stream down");
        };
        try {
            new Agent(options).run(new Session("s1"), "go");
            throw new AssertionError("expected stream failure");
        } catch (IllegalStateException error) {
            check("stream down".equals(error.getMessage()), error.getMessage());
        }
    }

    private static void check(boolean condition, String detail) {
        if (!condition) {
            throw new AssertionError(detail);
        }
    }
}
