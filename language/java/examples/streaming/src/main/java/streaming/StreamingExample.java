package streaming;

import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.StreamingModel;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

public final class StreamingExample {
    private StreamingExample() {
    }

    static final class FakeStreamingModel implements StreamingModel {
        private final List<String> chunks;

        FakeStreamingModel(List<String> chunks) {
            this.chunks = chunks;
        }

        @Override
        public Response generate(Request request) {
            return Response.of(Message.assistant(String.join("", chunks), List.of()));
        }

        @Override
        public Response generateStream(Request request, Consumer<String> onDelta) {
            chunks.forEach(onDelta);
            return generate(request);
        }
    }

    public static void main(String[] args) throws Exception {
        List<String> chunks = List.of("status: ", "green");
        List<String> received = new ArrayList<>();
        AgentOptions options = new AgentOptions(new FakeStreamingModel(chunks));
        options.onDelta = received::add;
        options.systemPrompt = "Answer with the current status.";
        options.maxSteps = 2;
        String output = new Agent(options)
                .run(new Session("streaming"), "Check the status.")
                .output;
        if (!output.equals("status: green")) {
            throw new IllegalStateException("unexpected output: " + output);
        }
        if (!received.equals(chunks)) {
            throw new IllegalStateException("unexpected deltas: " + received);
        }
        if (!String.join("", received).equals(output)) {
            throw new IllegalStateException("deltas do not reconstruct the output");
        }
        System.out.println("streaming test: ok");
    }
}
