package checkpoint;

import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Result;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.checkpoint.Allowlist;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class SessionCheckpointApp {
    private SessionCheckpointApp() {
    }

    static final class TurnModel implements Model {
        @Override
        public Response generate(Request request) {
            return Response.of(Message.assistant(
                    "turn " + request.messages().size(), List.of()));
        }
    }

    private static Map<String, Object> checkpoint(List<Message> messages) {
        List<Object> wire = new ArrayList<>();
        for (Message message : messages) {
            wire.add(message.toWire());
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("messages", wire);
        return payload;
    }

    @SuppressWarnings("unchecked")
    private static List<Message> restore(Object payload) {
        Map<String, Object> map = (Map<String, Object>) payload;
        List<Message> messages = new ArrayList<>();
        for (Object item : (List<Object>) map.get("messages")) {
            messages.add(Message.fromWire(item));
        }
        return messages;
    }

    public static void main(String[] args) throws Exception {
        Allowlist allow = new Allowlist();
        allow.register("session.messages", LinkedHashMap::new);

        Session session = new Session("session-1");
        session.messages.add(Message.of(Message.USER, "first"));
        session.messages.add(Message.of(Message.ASSISTANT, "ack"));

        String saved = allow.marshal("session.messages", checkpoint(session.messages));
        session.messages = restore(allow.unmarshal(saved));

        Agent agent = new Agent(new AgentOptions(new TurnModel()));
        Session restored = new Session("session-1");
        restored.messages = session.messages;
        Result result = agent.run(restored, "second");
        if (!"turn 3".equals(result.output)) {
            throw new IllegalStateException("unexpected second turn: " + result.output);
        }

        session.messages.add(Message.of(Message.USER, "second"));
        session.messages.add(Message.of(Message.ASSISTANT, result.output));
        saved = allow.marshal("session.messages", checkpoint(session.messages));
        session.messages = restore(allow.unmarshal(saved));

        restored = new Session("session-1");
        restored.messages = session.messages;
        result = agent.run(restored, "third");
        if (!"turn 5".equals(result.output)) {
            throw new IllegalStateException("unexpected third turn: " + result.output);
        }

        System.out.println("restored messages: " + session.messages.size());
        System.out.println("output: " + result.output);
    }
}
