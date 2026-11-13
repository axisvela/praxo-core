package events;

import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.event.Event;
import com.axisvela.praxo.event.Sink;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.tool.FuncTool;
import com.axisvela.praxo.tool.Registry;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class EventSinkExample {
    private EventSinkExample() {
    }

    static final class RecordingSink implements Sink {
        final List<Event> events = new ArrayList<>();

        @Override
        public void emit(Event event) {
            events.add(event);
        }

        List<String> types() {
            return events.stream().map(Event::type).toList();
        }
    }

    static Agent createAgent(Model model, Sink allSink, Sink toolSink) {
        Registry tools = new Registry();
        tools.register(new FuncTool("lookup", "Look up a status value.",
                args -> Map.of("key", args.getOrDefault("key", ""), "value", "green")));
        AgentOptions options = new AgentOptions(model);
        options.tools = tools;
        options.events = Sink.multi(List.of(
                allSink,
                Sink.filter(toolSink, event -> event.type().equals("tool.call"))));
        options.systemPrompt = "Use tools when asked for status.";
        options.maxSteps = 3;
        return new Agent(options);
    }

    static final class ToolThenAnswerModel implements Model {
        private int calls;

        @Override
        public Response generate(Request request) {
            calls += 1;
            if (calls == 1) {
                return Response.of(Message.assistant("", List.of(new ToolCall(
                        "call-1", "lookup", Map.of("key", "status")))));
            }
            return Response.of(Message.assistant("status: green", List.of()));
        }
    }

    public static void main(String[] args) throws Exception {
        RecordingSink all = new RecordingSink();
        RecordingSink tool = new RecordingSink();
        String output = createAgent(new ToolThenAnswerModel(), all, tool)
                .run(new Session("event-sink"), "Check the status.")
                .output;
        if (!output.equals("status: green")) {
            throw new IllegalStateException("unexpected output: " + output);
        }
        if (!all.types().equals(List.of("run.started", "tool.call", "run.completed"))) {
            throw new IllegalStateException("unexpected events: " + all.types());
        }
        if (!tool.types().equals(List.of("tool.call"))) {
            throw new IllegalStateException("unexpected filtered events: " + tool.types());
        }
        if (!"lookup".equals(tool.events.get(0).data().get("name"))) {
            throw new IllegalStateException("tool.call did not include the tool name");
        }
        System.out.println("event sink test: ok");
    }
}
